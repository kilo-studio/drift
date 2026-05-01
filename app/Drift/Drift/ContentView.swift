import SwiftUI

enum AppTab: Hashable {
    case home, history
}

struct ContentView: View {
    @Environment(HitStore.self) private var store

    @State private var currentTab: AppTab = .home
    @State private var homeScrolled: Bool = false
    @State private var showAddSheet: Bool = false

    private let spiritSize: CGFloat = 96

    /// Spirit is "stuck" in the top-right corner whenever we're on history or
    /// when home is scrolled past the threshold.
    private var spiritIsStuck: Bool {
        currentTab == .history || homeScrolled
    }

    var body: some View {
        ZStack {
            if currentTab == .home {
                HomeView(homeScrolled: $homeScrolled, spiritSize: spiritSize)
            } else {
                HistoryView()
            }
        }
        .overlay { spiritOverlay }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
        }
    }

    /// iOS 26 liquid glass via `glassEffect` modifiers. The nav-button group
    /// gets its own glass capsule on the leading edge; the + button gets its
    /// own glass circle on the trailing edge — same visual as Apple's
    /// canonical bottom toolbar pattern, without the
    /// "UIKitToolbar as subview of UIHostingController" warning that the
    /// .toolbar(.bottomBar) API kept producing on top of our ignoresSafeArea
    /// + overlay setup.
    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                tabButton(.home, systemImage: "house.fill")
                tabButton(.history, systemImage: "clock")
            }
            .padding(6)
            .glassEffect(.regular, in: Capsule())

            Spacer()

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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.driftCoral)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(.regular, in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: AppTab, systemImage: String) -> some View {
        let isActive = tab == currentTab
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentTab = tab
            }
        } label: {
            Image(systemName: systemImage)
                .symbolVariant(isActive ? .fill : .none)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? .driftInk : .driftInkSoft)
                .frame(width: 44, height: 36)
                .background {
                    if isActive {
                        Capsule().fill(Color.white.opacity(0.4))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Spirit overlay — same swoop animation between rest (home, at top) and
    /// sticky (history or scrolled).
    private var spiritOverlay: some View {
        GeometryReader { geo in
            let rest = restCenter(in: geo.size)
            let sticky = stickyCenter(in: geo.size)
            let target = spiritIsStuck ? sticky : rest

            SpiritView(
                lastSessionEnd: store.lastSessionEnd(),
                wakingAvgSec: store.wakingAvgSec(),
                longestWakingGapSec: store.longestWakingGapSec,
                longestGapSec: store.longestGapSec
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
