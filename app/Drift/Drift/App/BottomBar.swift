import SwiftUI

enum AppTab: Hashable {
    case home, history
}

/// iOS 26-style floating bottom bar: a pill of nav buttons on the leading edge
/// and a separate + menu on the trailing edge. Spans both pages, so logging is
/// always one tap away regardless of which tab is active.
struct BottomBar: View {
    @Environment(HitStore.self) private var store
    @Binding var currentTab: AppTab
    @Binding var showAddSheet: Bool

    var body: some View {
        HStack(spacing: 12) {
            navPill
            Spacer()
            plusMenu
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Two-button pill — home / history. The selected tab gets a soft tinted
    /// background that reads as "active."
    private var navPill: some View {
        HStack(spacing: 4) {
            navButton(.home,    systemImage: "house.fill")
            navButton(.history, systemImage: "clock")
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 6)
    }

    private func navButton(_ tab: AppTab, systemImage: String) -> some View {
        let isActive = tab == currentTab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentTab = tab
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? .driftInk : .driftInkSoft)
                .frame(width: 44, height: 36)
                .background {
                    if isActive {
                        Capsule().fill(Color.white.opacity(0.55))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Menu-bearing + button. Single tap opens a liquid glass popup on iOS 26
    /// with quick log + choose-time actions.
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

            #if DEBUG
            Divider()
            Section("Debug") {
                Button("Seed 14 days") { seedDebugData() }
                Button("Reload from prototype") { reloadFromPrototype() }
                Button("Clear all hits", role: .destructive) {
                    try? store.resetEverything()
                }
            }
            #endif
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.driftCoral, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
    }

    #if DEBUG
    private func seedDebugData() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = TimeZone.current.secondsFromGMT() / 60
        var times: [Date] = []
        for dayOffset in 0..<14 {
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -dayOffset, to: now)!)
            let dayCount = Int.random(in: 2...8)
            for _ in 0..<dayCount {
                let minutes = Int.random(in: 360..<1380)
                if let t = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) {
                    times.append(t)
                }
            }
        }
        for t in times.sorted() where t < now {
            try? store.append(Hit(t: t, tzOffsetMinutes: tz))
        }
    }

    private func reloadFromPrototype() {
        try? store.resetEverything()
        UserDefaults.standard.removeObject(forKey: "drift.migration.scriptable.complete")
        PrototypeMigration.runIfNeeded(store)
    }
    #endif
}
