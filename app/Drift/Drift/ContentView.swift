import SwiftUI

enum AppTab: Hashable {
    case home, history, settings
    /// Pseudo-tab — selected briefly when the user taps the trailing + slot,
    /// intercepted to present the add-hit sheet without actually navigating.
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

    private let spiritSize: CGFloat = 96

    /// Spirit is "stuck" in the top-right corner whenever we're off home, or
    /// when home is scrolled past the threshold.
    private var spiritIsStuck: Bool {
        currentTab != .home || homeScrolled
    }

    var body: some View {
        // Native TabView. iOS 26's Tab(role: .search) auto-places a tab on the
        // trailing edge — that's the layout pattern from Apple Music. We
        // repurpose that slot for the + Menu by intercepting the tab selection
        // before it actually navigates.
        TabView(selection: tabSelectionBinding) {
            Tab("home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(homeScrolled: $homeScrolled, spiritSize: spiritSize)
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
                // Never actually navigated to — we revert in the binding setter
                // below before the user sees this view.
                Color.clear
            }
        }
        .tint(.primary)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay { spiritOverlay }
        .overlay { baselineCelebrationOverlay }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
                .presentationBackground(.driftSkyLowerMid)
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

    /// Intercept the .addAction "tab" selection: snap back to the prior tab
    /// and present the add-hit menu. The user sees the trailing tab slot styled
    /// like Apple Music's search button without ever actually navigating into it.
    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { currentTab },
            set: { newValue in
                if newValue == .addAction {
                    // Don't update currentTab; just trigger the menu/sheet instead.
                    // For now use the sheet directly — Menu can't be triggered
                    // programmatically without a label tap.
                    showAddSheet = true
                } else {
                    currentTab = newValue
                }
            }
        )
    }

    private var plusMenu: some View {
        Menu {
            Button {
                try? store.append()
            } label: {
                Label("Log hit now", systemImage: "plus.circle.fill")
            }
            Button {
                showAddSheet = true
            } label: {
                Label("Choose time", systemImage: "clock")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.driftCoral)
                .frame(width: 36, height: 36)
        }
    }

    /// Spirit lives in an overlay so it persists across tab switches.
    private var spiritOverlay: some View {
        GeometryReader { geo in
            let rest = restCenter(in: geo.size)
            let sticky = stickyCenter(in: geo.size)
            let target = spiritIsStuck ? sticky : rest

            // During the establishing period the spirit's mood shouldn't
            // shift around — there isn't enough data for the ratio to mean
            // anything yet, and the donut is the focal element. Pass nil
            // inputs so SpiritFrame falls through to ratio = 1.0 (neutral
            // baseline) and no record thresholds get crossed.
            SpiritView(
                lastSessionEnd: store.isBaselineEstablished ? store.lastSessionEnd() : nil,
                wakingAvgSec: store.isBaselineEstablished ? store.wakingAvgSec() : nil,
                longestWakingGapSec: store.isBaselineEstablished ? store.longestWakingGapSec : 0,
                longestGapSec: store.isBaselineEstablished ? store.longestGapSec : 0
            )
            .frame(width: spiritSize, height: spiritSize)
            .scaleEffect(spiritIsStuck ? 0.7 : 1.0, anchor: .topTrailing)
            .position(x: target.x, y: target.y)
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: spiritIsStuck)
        }
        .allowsHitTesting(false)
    }

    private func restCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - 16 - spiritSize / 2 - 16,
            y: 36 + 24 + spiritSize / 2
        )
    }

    private func stickyCenter(in size: CGSize) -> CGPoint {
        let xinset: CGFloat = 8
        let yinset: CGFloat = 0
        return CGPoint(
            x: size.width - xinset - spiritSize / 2,
            y: yinset + spiritSize / 2
        )
    }
}
