import SwiftUI

enum AppTab: Hashable {
    case home, history, settings
    /// The trailing search-role slot, repurposed as the + button. Its tap is
    /// intercepted (see `addTapInterceptor`) so the search transition never
    /// fires; this value only exists so the binding can recognize and reject a
    /// selection that slips past the interceptor.
    case addAction
}

struct ContentView: View {
    @Environment(HitStore.self) private var store

    @State private var currentTab: AppTab = .home
    @State private var homeScrolled: Bool = false
    @State private var showAddSheet: Bool = false
    /// One-time celebration when the baseline-count crosses the threshold via
    /// real logs (not via skip). Owned here rather than HomeView so it
    /// renders above the tab bar AND the spirit overlay — those are sibling
    /// layers in this ContentView's body, so the celebration overlay sits
    /// outside both.
    @State private var showBaselineCelebration: Bool = false
    /// Carries the just-ended long stretch while its acknowledgment is on
    /// screen. Driven off `store.endedLongStretch`; mirrors the baseline
    /// celebration's layering so it sits above the tab bar and spirit.
    @State private var endedStretchAck: EndedLongStretch?

    private let spiritSize: CGFloat = 96

    /// Spirit is "stuck" in the top-right corner whenever we're off home, or
    /// when home is scrolled past the threshold.
    private var spiritIsStuck: Bool {
        currentTab != .home || homeScrolled
    }

    var body: some View {
        // iOS 26's Tab(role: .search) is the ONLY way to get a button in the
        // trailing-separated slot of the tab bar — there's no API for a regular
        // trailing button, and a free-floating overlay can't track the bar when
        // it re-centers or minimizes. So the + keeps the search role for
        // placement, and `addTapInterceptor` (a transparent button pinned over
        // the pill) swallows the tap before it reaches the tab — that's what
        // stops iOS's search-mode transition, the source of the white flash.
        // The pill's + glyph still comes from the search tab beneath it.
        TabView(selection: tabSelectionBinding) {
            Tab("home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(
                    onScrolledChange: { newValue in
                        if newValue != homeScrolled {
                            homeScrolled = newValue
                        }
                    },
                    spiritSize: spiritSize
                )
                .equatable()
            }
            // History only appears once the user has finished (or skipped) the
            // baseline period. Before that there's nothing meaningful in it.
            if store.isBaselineEstablished {
                Tab("history", systemImage: "clock", value: AppTab.history) {
                    HistoryView()
                }
            }
            Tab("settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
            Tab("add", systemImage: "plus", value: AppTab.addAction, role: .search) {
                Color.driftSkyLowerMid.ignoresSafeArea()
            }
        }
        .tint(.primary)
        .tabBarMinimizeBehavior(.onScrollDown)
        #if DEBUG
        .onAppear {
            // `--records`: start on History so the records sheet (opened by
            // HistoryView's matching hook) is reachable for testing.
            if ProcessInfo.processInfo.arguments.contains("--records") {
                currentTab = .history
            }
        }
        #endif
        .overlay { addTapInterceptor }
        .overlay { spiritOverlay }
        .overlay { baselineCelebrationOverlay }
        .overlay { relapseAckOverlay }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
                .presentationBackground(.driftSkyLowerMid)
                // Half-height by default (the native iOS way — `.medium` detent),
                // draggable up to full if the date picker needs the room.
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: store.baselineCount) { oldCount, newCount in
            // Earned moment only — skipping should silently switch to the
            // post-baseline UI without congratulating the user for bypassing.
            if oldCount < HitStore.baselineTarget,
               newCount >= HitStore.baselineTarget,
               !store.baselineSkipped {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showBaselineCelebration = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showBaselineCelebration = false
                    }
                }
            }
        }
        .onChange(of: store.endedLongStretch) { _, newValue in
            // A long stretch just ended (a hit was logged). Acknowledge it
            // gently — as a kept record, never a broken streak — then clear the
            // store signal so it doesn't re-fire on unrelated re-renders.
            guard let ended = newValue else { return }
            store.endedLongStretch = nil
            withAnimation(.easeInOut(duration: 0.6)) {
                endedStretchAck = ended
            }
            Task {
                try? await Task.sleep(for: .seconds(2.8))
                withAnimation(.easeInOut(duration: 0.8)) {
                    endedStretchAck = nil
                }
            }
        }
    }

    /// Full-screen cream wash + handwritten message. Lives at this layer so
    /// it covers both the tab bar and the spirit overlay underneath.
    @ViewBuilder
    private var baselineCelebrationOverlay: some View {
        if showBaselineCelebration {
            ZStack {
                Color.driftCream.ignoresSafeArea()
                // Extra thin-spaces around the Caveat string so the trailing
                // "!" swash doesn't clip against the Text frame at this size.
                Text("\u{2009}\u{2009}now let's start drifting!\u{2009}\u{2009}\u{2009}\u{2009}")
                    .font(.custom("Caveat", size: 44).weight(.semibold))
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
            }
            .transition(.opacity)
        }
    }

    /// Shame-free acknowledgment when a long stretch ends: the just-ended drift
    /// is framed as a kept record, never a broken streak. Same cream-wash +
    /// Caveat treatment as the baseline celebration, layered above everything.
    @ViewBuilder
    private var relapseAckOverlay: some View {
        if let ack = endedStretchAck {
            ZStack {
                Color.driftCream.ignoresSafeArea()
                Text(relapseAckMessage(ack))
                    .font(.custom("Caveat", size: 40).weight(.semibold))
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 32)
            }
            .transition(.opacity)
        }
    }

    private func relapseAckMessage(_ ack: EndedLongStretch) -> String {
        let dur = formatDurationHuman(ack.gapSec)
        // Thin-spaces guard the Caveat swashes from clipping at this size.
        if ack.wasNewRecord {
            return "\u{2009}\u{2009}\(dur) — your longest drift yet, saved.\u{2009}\u{2009}"
        }
        return "\u{2009}\u{2009}\(dur) of drifting — kept.\u{2009}\u{2009}"
    }

    /// Reject any selection of the search-role + slot: keep the current tab and
    /// open the sheet instead. This is the backstop — `addTapInterceptor`
    /// normally swallows the tap before it ever gets here, but if a tap slips
    /// past (e.g. the bar is minimized and the pill has moved), this still
    /// prevents a navigation into the empty search tab.
    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { currentTab },
            set: { newValue in
                if newValue == .addAction {
                    showAddSheet = true
                } else {
                    currentTab = newValue
                }
            }
        )
    }

    /// Transparent button pinned over the search pill. It sits above the tab bar
    /// in the overlay stack, so it wins the hit-test and the tap never reaches
    /// the search tab — which is what prevents iOS's search-mode transition (the
    /// white flash). The pill's visible + glyph is still drawn by the search tab
    /// underneath; this view is invisible. Position matches the measured pill
    /// center (≈45pt from right, ≈52pt from bottom). `ignoresSafeArea` so the
    /// bottom-relative math is against the true screen edge.
    private var addTapInterceptor: some View {
        GeometryReader { geo in
            Button {
                showAddSheet = true
            } label: {
                Color.clear
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .position(x: geo.size.width - 45, y: geo.size.height - 52)
        }
        .ignoresSafeArea()
    }

    /// Spirit lives in an overlay so it persists across tab switches.
    ///
    /// Positioning uses `.offset` (pure GPU transform, doesn't re-layout)
    /// instead of `.position` so the spring-driven transition between rest
    /// and sticky doesn't trigger a SwiftUI layout pass mid-scroll, which was
    /// the cause of the noticeable stutter at each transition moment.
    /// `compositingGroup` flattens the Canvas paths to a single layer before
    /// the scale + offset transforms, so the GPU has one texture to move
    /// instead of recomposing every path each frame. `geometryGroup` makes
    /// the scale + offset apply atomically so we don't see a momentary
    /// half-applied state on the first animation frame.
    private var spiritOverlay: some View {
        GeometryReader { geo in
            let restPos = restOffset(in: geo.size)
            let stickyPos = stickyOffset(in: geo.size)
            let target = spiritIsStuck ? stickyPos : restPos

            SpiritView(
                lastSessionEnd: store.isBaselineEstablished ? store.lastSessionEnd() : nil,
                wakingAvgSec: store.isBaselineEstablished ? store.wakingAvgSec() : nil,
                longestWakingGapSec: store.isBaselineEstablished ? store.longestWakingGapSec : 0,
                longestGapSec: store.isBaselineEstablished ? store.longestGapSec : 0
            )
            .frame(width: spiritSize, height: spiritSize)
            .compositingGroup()
            .scaleEffect(spiritIsStuck ? 0.7 : 1.0, anchor: .topTrailing)
            .offset(x: target.x, y: target.y)
            .geometryGroup()
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: spiritIsStuck)
        }
        .allowsHitTesting(false)
    }

    /// Top-left offset for the spirit at rest. Equivalent to the previous
    /// `restCenter` minus half the spirit size on each axis (since `.offset`
    /// positions the view's top-left rather than its center).
    private func restOffset(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - 16 - spiritSize - 16,
            y: 36 + 24
        )
    }

    private func stickyOffset(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - 8 - spiritSize,
            y: 0
        )
    }
}
