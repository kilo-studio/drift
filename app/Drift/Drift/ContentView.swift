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
        // Native iOS 26 TabView — the selected tab gets the tinted glass pill
        // for free, no manual styling. Plus a floating + Menu above the bar
        // for global logging on either tab.
        TabView(selection: $currentTab) {
            Tab("home", systemImage: "house.fill", value: .home) {
                HomeView(homeScrolled: $homeScrolled, spiritSize: spiritSize)
            }
            Tab("history", systemImage: "clock", value: .history) {
                HistoryView()
            }
        }
        .overlay { spiritOverlay }
        .overlay(alignment: .bottomTrailing) {
            plusMenu
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
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
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.driftCoral, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
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
