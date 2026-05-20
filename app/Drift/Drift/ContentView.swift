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
            Tab("history", systemImage: "clock", value: AppTab.history) {
                HistoryView()
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
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
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
