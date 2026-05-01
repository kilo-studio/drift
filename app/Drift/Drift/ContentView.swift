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
    /// when home is scrolled past the threshold. Otherwise it sits at rest in
    /// the home hero. Same swoop animation either way.
    private var spiritIsStuck: Bool {
        currentTab == .history || homeScrolled
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TabView(selection: $currentTab) {
                    Tab("home", systemImage: "house.fill", value: .home) {
                        HomeView(homeScrolled: $homeScrolled, spiritSize: spiritSize)
                    }
                    Tab("history", systemImage: "clock", value: .history) {
                        HistoryView()
                    }
                }

                spiritOverlay(in: geo.size)
            }
            .overlay(alignment: .bottomTrailing) {
                plusMenu
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }
            .sheet(isPresented: $showAddSheet) {
                AddHitSheet()
            }
        }
    }

    /// Spirit lives in the global ZStack so it persists across tab switches.
    /// Position interpolates between rest (home, at top) and sticky (everywhere
    /// else) with the same bouncy spring as before.
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

    /// Top-right corner of safe area, scaled-down anchor pinned at the corner.
    private func stickyCenter(in size: CGSize) -> CGPoint {
        let xinset: CGFloat = 8
        let yinset: CGFloat = 0
        return CGPoint(
            x: size.width - xinset - spiritSize / 2,
            y: yinset + spiritSize / 2
        )
    }

    /// Floating + button above the iOS 26 tab bar. Liquid-glass Menu pop-up.
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
}
