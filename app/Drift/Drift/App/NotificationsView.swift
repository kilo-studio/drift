import SwiftUI

/// Sheet presented from `SettingsView` when the user taps the notifications card.
/// Master toggle on top in its own card, then per-type cards below — when the
/// master is off, the rest hide so the sheet reads as one definitive switch.
///
/// Visually mirrors the parent settings page (sky background, Caveat hero label,
/// settings cards). `AmbientLayer` is intentionally omitted — the sheet is a
/// short-lived modal context, and continuous animation behind a transient surface
/// isn't worth the render cost.
struct NotificationsView: View {
    @Environment(HitStore.self) private var store

    /// Notification timing offsets per Issue 12: right at / +1 / +5 / +10 / +15 min.
    static let offsetOptions: [TimeInterval] = [0, 60, 300, 600, 900]

    var body: some View {
        @Bindable var store = store

        ZStack {
            // Same sky color as the parent. Combined with `presentationBackground`
            // on the parent's `.sheet`, the sheet reads as a continuation of the
            // settings surface — the rounded corners + grabber + shadow still
            // signal "modal" without needing a contrasting bg color.
            Color.driftSkyLowerMid.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text.caveat("notifications")
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 28) // breathing room below the sheet grabber

                    SettingsCard {
                        SettingsToggleRow(
                            label: "notifications",
                            description: "Master switch. When off, nothing schedules.",
                            isOn: $store.notifsEnabled
                        )
                    }

                    if store.notifsEnabled {
                        SettingsCard {
                            SettingsToggleRow(
                                label: "on every log",
                                description: "Confirmation banner with the time since your last hit.",
                                isOn: $store.notifsImmediateEnabled
                            )
                        }

                        SettingsCard {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    label: "beat your average",
                                    description: "Fires when you've drifted past your typical gap.",
                                    isOn: $store.notifsBeatAverageEnabled
                                )
                                if store.notifsBeatAverageEnabled {
                                    SettingsDivider()
                                    SettingsPickerRow(
                                        label: "when",
                                        description: "How long after hitting your average to wait before firing.",
                                        selection: $store.notifsBeatAverageOffsetSec,
                                        options: Self.offsetOptions,
                                        formatted: { Self.formatOffset($0) }
                                    )
                                }
                            }
                        }

                        SettingsCard {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    label: "beat your record",
                                    description: "Fires when you've passed your longest waking stretch.",
                                    isOn: $store.notifsBeatRecordEnabled
                                )
                                if store.notifsBeatRecordEnabled {
                                    SettingsDivider()
                                    SettingsPickerRow(
                                        label: "when",
                                        description: "How long after passing the record to wait before firing.",
                                        selection: $store.notifsBeatRecordOffsetSec,
                                        options: Self.offsetOptions,
                                        formatted: { Self.formatOffset($0) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
    }

    /// "right at" for 0, "+N min" otherwise.
    static func formatOffset(_ sec: TimeInterval) -> String {
        if sec <= 0 { return "right at" }
        let m = Int(sec / 60)
        return "+\(m) min"
    }
}
