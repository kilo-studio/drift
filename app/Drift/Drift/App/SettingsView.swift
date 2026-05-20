import SwiftUI

/// Settings tab. Detail surfaces (currently just notifications) come up as
/// sheets from the bottom — push navigation felt heavy for what's essentially
/// "drill into one group of toggles." Sheets keep the page in context, the
/// drag-down dismiss is intuitive, and the swipe-to-dismiss matches the rest
/// of the app's sheet vocabulary (AddHitSheet, EditHitSheet).
struct SettingsView: View {
    @Environment(HitStore.self) private var store
    @State private var showResetConfirm: Bool = false
    @State private var showNotifications: Bool = false

    private static let thresholdOptions: [TimeInterval] = [60, 180, 300, 600, 900, 1800]
    private static let windowOptions: [Int] = [7, 14, 30, 60]
    private static let hourOptions: [Int] = Array(0...23)

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()
            AmbientLayer()

            ScrollView {
                VStack(spacing: 16) {
                    Text.caveat("settings")
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 36)

                    sessionsCard(store: $store)
                    rollingWindowCard(store: $store)
                    sleepWindowCard(store: $store)
                    notificationsCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                // Drift the sheet's chrome to match the rest of the app — same
                // sky color the parent uses, so the sheet reads as a continuation
                // of the surface rather than a system-default white panel. The
                // sheet's grabber + rounded corners + shadow still signal "modal"
                // even with matching color.
                .presentationBackground(.driftSkyLowerMid)
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                try? store.resetEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every logged hit will be deleted and your records reset to zero. This can't be undone.")
        }
    }

    // MARK: - Cards

    private func sessionsCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    label: "use sessions",
                    description: "Group rapid hits into one session. When off, every tap counts on its own.",
                    isOn: store.useSessions
                )
                if store.wrappedValue.useSessions {
                    SettingsDivider()
                    SettingsPickerRow(
                        label: "session threshold",
                        description: "Rapid hits within this gap collapse into a single session.",
                        selection: store.sessionThresholdSec,
                        options: Self.thresholdOptions,
                        formatted: { formatThreshold($0) }
                    )
                }
            }
        }
    }

    private func rollingWindowCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            SettingsPickerRow(
                label: "rolling window",
                description: "How many days of history feed your average stats.",
                selection: store.rollingWindowDays,
                options: Self.windowOptions,
                formatted: { "\($0) days" }
            )
        }
    }

    private func sleepWindowCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsPickerRow(
                    label: "bedtime",
                    description: "Notifications soften their tone after this hour.",
                    selection: store.sleepStartHour,
                    options: Self.hourOptions,
                    formatted: { formatHour($0) }
                )
                SettingsDivider()
                SettingsPickerRow(
                    label: "wake up",
                    description: "Hits before this roll into the previous day's stats.",
                    selection: store.sleepEndHour,
                    options: Self.hourOptions,
                    formatted: { formatHour($0) }
                )
            }
        }
    }

    /// Whole-card button — tapping anywhere on the row brings up the
    /// notifications sheet from the bottom. `.buttonStyle(.plain)` strips the
    /// default tap highlight so the row reads as a normal settings row.
    private var notificationsCard: some View {
        Button {
            showNotifications = true
        } label: {
            SettingsCard {
                SettingsNavRow(
                    label: "notifications",
                    description: "Master switch, per-type toggles, timing offsets."
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var dataCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                Text("iCloud sync — coming soon")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SettingsDivider()
                Button {
                    showResetConfirm = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("reset all data")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftCoral)
                        Text("Delete every logged hit and clear records. Cannot be undone.")
                            .font(.driftRowDescription)
                            .foregroundStyle(.driftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsInfoRow(label: "version", value: appVersion)
                SettingsDivider()
                SettingsLinkRow(label: "privacy policy", url: URL(string: "https://drift.app/privacy")!)
                SettingsDivider()
                SettingsLinkRow(label: "github", url: URL(string: "https://github.com/grillinmuffins/drift")!)
            }
        }
    }

    // MARK: - Format helpers

    private func formatThreshold(_ sec: TimeInterval) -> String {
        let m = Int(sec / 60)
        return m == 1 ? "1 min" : "\(m) min"
    }

    /// Hour 0–23 → friendly clock label. "midnight" / "noon" for 0/12, "Xam" /
    /// "Xpm" otherwise.
    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "midnight" }
        if h == 12 { return "noon" }
        if h < 12 { return "\(h) am" }
        return "\(h - 12) pm"
    }
}
