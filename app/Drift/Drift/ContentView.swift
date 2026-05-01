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
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    page
                    spiritOverlay(in: geo.size)
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    tabButton(.home, systemImage: "house.fill")
                }
                ToolbarItem(placement: .bottomBar) {
                    tabButton(.history, systemImage: "clock")
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    plusMenu
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
        }
    }

    @ViewBuilder
    private var page: some View {
        switch currentTab {
        case .home:    HomeView(homeScrolled: $homeScrolled, spiritSize: spiritSize)
        case .history: HistoryView()
        }
    }

    private func tabButton(_ tab: AppTab, systemImage: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentTab = tab
            }
        } label: {
            Image(systemName: systemImage)
                .symbolVariant(currentTab == tab ? .fill : .none)
                .foregroundStyle(currentTab == tab ? .driftInk : .driftInkSoft)
        }
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
                .foregroundStyle(.driftCoral)
        }
    }

    /// Spirit lives in the global ZStack so it persists across tab switches.
    /// Position interpolates between rest (home, at top) and sticky (everywhere
    /// else) with a bouncy spring.
    @ViewBuilder
    private func spiritOverlay(in size: CGSize) -> some View {
        let rest = restCenter(in: size)
        let sticky = stickyCenter(in: size)
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

    /// Matches the placeholder position in HomeView's hero row.
    private func restCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - 16 - spiritSize / 2 - 16,
            y: 36 + 24 + spiritSize / 2
        )
    }

    /// Top-right corner; scaled-down anchor pinned at the corner.
    private func stickyCenter(in size: CGSize) -> CGPoint {
        let xinset: CGFloat = 8
        let yinset: CGFloat = 0
        return CGPoint(
            x: size.width - xinset - spiritSize / 2,
            y: yinset + spiritSize / 2
        )
    }
}
