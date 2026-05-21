import SwiftUI
import UIKit

/// First-launch carousel. Each card does real work — sets a preference, requests
/// a permission, or shows a working preview — rather than narrating at the user.
/// The cloud spirit floats at the top of every card so the character is present
/// from second one. Spec: `Issues/12 — Onboarding, settings, app icon.md`.
struct OnboardingView: View {
    @Environment(HitStore.self) private var store
    @AppStorage(driftOnboardingCompleteKey) private var complete: Bool = false

    @State private var page: Int = 0

    /// 9 slides: intro, sessions, sleep, notifications, action button, control
    /// center, shortcuts, spirit, conclusion. Page indices below assume this
    /// order — keep `spiritPreviewPage` in sync when reordering.
    private let totalPages = 9
    private let spiritPreviewPage = 7

    private let spiritSize: CGFloat = 96
    /// Synthetic average used to drive both the resting top-spirit ratio and
    /// the spirit-preview animation. One hour reads as a believable typical gap.
    private let demoAvgSec: TimeInterval = 3600

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()
            AmbientLayer()

            // Sparkles only during the meet-the-spirit card. Inputs driven by
            // TimelineView so the sparkles actually animate in / out as the
            // demo ratio cycles.
            if page == spiritPreviewPage {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    let ratio = demoRatio(at: ctx.date)
                    SparkleField(
                        lastSessionEnd: ctx.date.addingTimeInterval(-ratio * demoAvgSec),
                        wakingAvgSec: demoAvgSec,
                        layer: .back,
                        spiritPercent: CGPoint(x: 50, y: 14)
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            VStack(spacing: 0) {
                topSpirit
                    .frame(width: spiritSize, height: spiritSize)
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                TabView(selection: $page) {
                    IntroCard().tag(0)
                    SessionsCard(store: store).tag(1)
                    SleepCard(store: store).tag(2)
                    NotificationsCard(store: store).tag(3)
                    ActionButtonCard().tag(4)
                    ControlCenterCard().tag(5)
                    ShortcutsCard().tag(6)
                    SpiritPreviewCard().tag(7)
                    ConclusionCard().tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                ctaButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)

                pageDots
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeOut(duration: 0.25), value: page)
    }

    // MARK: - Top spirit

    /// Top spirit. During the spirit-preview card it animates through a cosine-
    /// eased ratio range; on other cards it sits at a moderate ratio so the
    /// character is alive but not celebrating yet.
    ///
    /// Synthetic `longestWakingGapSec` and `longestGapSec` are non-zero on the
    /// preview card so the cheek-color thresholds (waking-record → peach,
    /// overall-record → coral) actually get crossed during the cycle — without
    /// them the cheeks stay flat at the base color.
    @ViewBuilder
    private var topSpirit: some View {
        if page == spiritPreviewPage {
            TimelineView(.animation) { ctx in
                let ratio = demoRatio(at: ctx.date)
                SpiritView(
                    lastSessionEnd: ctx.date.addingTimeInterval(-ratio * demoAvgSec),
                    wakingAvgSec: demoAvgSec,
                    longestWakingGapSec: demoAvgSec * 2,
                    longestGapSec: demoAvgSec * 3.5
                )
            }
        } else {
            SpiritView(
                lastSessionEnd: Date.now.addingTimeInterval(-1.5 * demoAvgSec),
                wakingAvgSec: demoAvgSec,
                longestWakingGapSec: 0,
                longestGapSec: 0
            )
        }
    }

    /// Cosine-eased loop between ratio 0.3 and 5 over 12s. Slow enough that the
    /// viewer can register each stage of the spirit's mood; cosine boundaries
    /// avoid the snap-decay reset that linear cycling would trigger.
    private func demoRatio(at date: Date) -> Double {
        let cycleSec: Double = 12
        let cyclePos = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleSec) / cycleSec
        let t = (1 - cos(cyclePos * .pi * 2)) / 2
        return 0.3 + (5 - 0.3) * t
    }

    // MARK: - CTA + dots

    private var ctaButton: some View {
        Button(action: advance) {
            Text(ctaLabel)
                .font(.driftRowLabel)
                .foregroundStyle(.driftCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassEffect(
                    .regular.tint(.driftSkyLowerMid.opacity(0.4)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Circle()
                    .fill(Color.driftInk)
                    .opacity(i == page ? 0.75 : 0.2)
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.25), value: page)
    }

    private var ctaLabel: String {
        switch page {
        case 0: return "let's go"
        case totalPages - 1: return "start drifting"
        default: return "next"
        }
    }

    private func advance() {
        if page == totalPages - 1 {
            complete = true
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                page += 1
            }
        }
    }
}

// MARK: - Cards

private struct IntroCard: View {
    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text.caveat("drift")
                    .font(.custom("Caveat", size: 64).weight(.semibold))
                    .foregroundStyle(.driftInk)

                Text("helps you vape less, gently")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    factLine("data stays on your device")
                    factLine("no ads, no tracking")
                    factLine("completely free")
                }
                .padding(.top, 12)
            }
        }
    }

    private func factLine(_ text: String) -> some View {
        Text(text)
            .font(.driftRowLabel)
            .foregroundStyle(.driftInkSoft)
    }
}

private struct SessionsCard: View {
    @Bindable var store: HitStore

    private static let thresholdOptions: [TimeInterval] = [60, 180, 300, 600, 900, 1800]

    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("how should drift count?")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        label: "use sessions",
                        description: "Group rapid hits into one session. When off, every tap counts on its own.",
                        isOn: $store.useSessions
                    )
                    if store.useSessions {
                        SettingsDivider()
                        SettingsPickerRow(
                            label: "session threshold",
                            description: "Rapid hits within this gap collapse into one session.",
                            selection: $store.sessionThresholdSec,
                            options: Self.thresholdOptions,
                            formatted: { formatThreshold($0) }
                        )
                    }
                }
                .driftCard()
            }
        }
    }

    private func formatThreshold(_ sec: TimeInterval) -> String {
        let m = Int(sec / 60)
        return m == 1 ? "1 min" : "\(m) min"
    }
}

private struct SleepCard: View {
    @Bindable var store: HitStore

    private static let hourOptions: [Int] = Array(0...23)

    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("when do you sleep?")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Hits before your wake hour roll into the previous day's stats. Drift also won't send notifications during your sleep window.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    SettingsPickerRow(
                        label: "bedtime",
                        description: "Notifications pause after this hour.",
                        selection: $store.sleepStartHour,
                        options: Self.hourOptions,
                        formatted: { formatHour($0) }
                    )
                    SettingsDivider()
                    SettingsPickerRow(
                        label: "wake up",
                        description: "Hits before this hour roll into the previous day.",
                        selection: $store.sleepEndHour,
                        options: Self.hourOptions,
                        formatted: { formatHour($0) }
                    )
                }
                .driftCard()
            }
        }
    }

    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "midnight" }
        if h == 12 { return "noon" }
        if h < 12 { return "\(h) am" }
        return "\(h - 12) pm"
    }
}

private struct NotificationsCard: View {
    @Bindable var store: HitStore

    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("notifications")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        label: "notifications",
                        description: "Master switch. Drift will ask permission the first time you turn this on.",
                        isOn: $store.notifsEnabled
                    )
                    if store.notifsEnabled {
                        SettingsDivider()
                        SettingsToggleRow(
                            label: "on log",
                            description: "Quick confirmation when a hit is logged.",
                            isOn: $store.notifsImmediateEnabled
                        )
                        SettingsDivider()
                        SettingsToggleRow(
                            label: "beat your average",
                            description: "Nudge when you pass your rolling-average gap.",
                            isOn: $store.notifsBeatAverageEnabled
                        )
                        SettingsDivider()
                        SettingsToggleRow(
                            label: "beat your record",
                            description: "Celebration when you set a new longest gap.",
                            isOn: $store.notifsBeatRecordEnabled
                        )
                    }
                }
                .driftCard()
            }
        }
        .onChange(of: store.notifsEnabled) { _, newValue in
            if newValue {
                Task { await requestNotificationPermission() }
            }
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}

private struct ActionButtonCard: View {
    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("the action button")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Bind \"Log a hit in Drift\" to your iPhone's side button for instant logging — even from the lock screen.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                OnboardingActionButton(label: "open iOS settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

private struct ControlCenterCard: View {
    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("control center")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Add Drift to Control Center as an Open-App tile so logging is one swipe away. Settings → Control Center → +.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                OnboardingActionButton(label: "open iOS settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

private struct ShortcutsCard: View {
    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("shortcuts")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Drift is already in the Shortcuts app — search \"Log a hit in Drift\" to use it from Siri, the lock screen, or a home screen widget.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                OnboardingActionButton(label: "open shortcuts") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

private struct SpiritPreviewCard: View {
    var body: some View {
        OnboardingCardChrome {
            Text("the longer past your average gap between hits or sessions, the happier your spirit gets")
                .font(.onboardingTitle)
                .foregroundStyle(.driftInk)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ConclusionCard: View {
    /// Tip-jar destination. Swap to the real Buy Me a Coffee URL once the page
    /// is live; this placeholder reads OK in the meantime.
    private let tipJarURL = URL(string: "https://buymeacoffee.com/griffinmullins")!

    var body: some View {
        OnboardingCardChrome {
            VStack(spacing: 24) {
                Text("you're all set")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Change any of these in Settings anytime.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                OnboardingActionButton(label: "buy me a coffee") {
                    UIApplication.shared.open(tipJarURL)
                }
            }
        }
    }
}

// MARK: - Shared chrome

/// Shared layout for every onboarding card: content centered in a scroll
/// container so long settings stacks remain reachable on small devices, with
/// uniform horizontal padding to keep titles centered without clipping.
private struct OnboardingCardChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

/// Secondary action button inside an onboarding card. Visually quieter than
/// the bottom CTA — soft material capsule, ink-colored label — so the bottom
/// "next" / "start drifting" stays the primary path.
private struct OnboardingActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.driftRowLabel)
                .foregroundStyle(.driftInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Typography

extension Font {
    /// Large onboarding header. Quicksand SemiBold so it's clearly readable
    /// and doesn't compete with the "drift" wordmark for "handwritten" energy
    /// — that face is reserved for the brand mark itself in this flow.
    static let onboardingTitle = Font.custom("Quicksand-SemiBold", size: 28)
}

// MARK: - UserDefaults key

/// Shared so `HitStore.resetEverything` can clear it and `RootView` can gate on it.
let driftOnboardingCompleteKey = "drift.onboarding.complete"
