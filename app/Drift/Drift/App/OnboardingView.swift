import SwiftUI
import UIKit

/// First-launch carousel. Seven cards, each doing real work — set a preference,
/// request a permission, or show a working preview — rather than narrating at
/// the user. The spirit floats at the top of every card so the character is
/// present from second one. Spec: `Issues/12 — Onboarding, settings, app icon.md`.
struct OnboardingView: View {
    @Environment(HitStore.self) private var store
    @AppStorage(driftOnboardingCompleteKey) private var complete: Bool = false

    @State private var page: Int = 0

    private let totalPages = 7
    private let spiritSize: CGFloat = 96
    /// Synthetic average used to drive both the resting top-spirit ratio and
    /// the card-6 animation. 1 hour reads as a believable typical gap.
    private let demoAvgSec: TimeInterval = 3600

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()
            AmbientLayer()

            // Sparkles only during the meet-the-spirit card. Anchored near the
            // top spirit so the halo grows out from where the user's looking.
            if page == 5 {
                SparkleField(
                    lastSessionEnd: Date.now.addingTimeInterval(-currentDemoRatio * demoAvgSec),
                    wakingAvgSec: demoAvgSec,
                    layer: .back,
                    spiritPercent: CGPoint(x: 50, y: 14)
                )
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            VStack(spacing: 0) {
                topSpirit
                    .frame(width: spiritSize, height: spiritSize)
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                TabView(selection: $page) {
                    IntroCard().tag(0)
                    SessionsCard(store: store).tag(1)
                    SleepCard(store: store).tag(2)
                    NotificationsCard(store: store).tag(3)
                    LoggingCard().tag(4)
                    SpiritPreviewCard().tag(5)
                    ConclusionCard().tag(6)
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

    /// Top spirit. Static at a moderate ratio on most cards; animated through a
    /// range during card 5 so the meet-the-spirit preview is what the user is
    /// actually looking at (not a separate inset preview).
    @ViewBuilder
    private var topSpirit: some View {
        if page == 5 {
            TimelineView(.animation) { ctx in
                let ratio = demoRatio(at: ctx.date)
                SpiritView(
                    lastSessionEnd: ctx.date.addingTimeInterval(-ratio * demoAvgSec),
                    wakingAvgSec: demoAvgSec,
                    longestWakingGapSec: 0,
                    longestGapSec: 0
                )
            }
        } else {
            // Watching-but-resting baseline — ratio ~1.5 so eyes have a small
            // amount of growth, signaling "alive and present" without celebration.
            SpiritView(
                lastSessionEnd: Date.now.addingTimeInterval(-1.5 * demoAvgSec),
                wakingAvgSec: demoAvgSec,
                longestWakingGapSec: 0,
                longestGapSec: 0
            )
        }
    }

    /// Cosine-eased loop between ratio 0.3 and 5 over 8s. Smooth at the
    /// boundaries so the spirit doesn't snap back.
    private func demoRatio(at date: Date) -> Double {
        let cyclePos = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 8) / 8
        let t = (1 - cos(cyclePos * .pi * 2)) / 2
        return 0.3 + (5 - 0.3) * t
    }

    /// Snapshot of the current demo ratio — used for the sparkle field's input
    /// outside the TimelineView. Not exact-per-frame, but the SparkleField's
    /// own TimelineView re-reads on every frame so this stays smooth enough.
    private var currentDemoRatio: Double {
        demoRatio(at: Date.now)
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
        case totalPages - 1: return "happy drifting"
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
        OnboardingCardChrome(title: "drift") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Drift helps you notice the gaps between hits and gently reduce them over time.")
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text("No streaks. No shame. No nagging. Just a quiet, present-tense view of what's actually happening — and a cloud spirit that grows brighter the longer it's been.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SessionsCard: View {
    @Bindable var store: HitStore

    private static let thresholdOptions: [TimeInterval] = [60, 180, 300, 600, 900, 1800]

    var body: some View {
        OnboardingCardChrome(title: "how should drift count?") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Most people take a few quick hits in a row, then go a while. Drift can group rapid hits into a single \"session\" so the gaps you see reflect the time *between* episodes, not between every puff.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)

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
        OnboardingCardChrome(title: "when do you sleep?") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Drift tracks two record gaps: your longest *overall* (counting overnight) and your longest *waking* gap. Most overnight gaps don't feel like progress, so the waking record is usually the more meaningful one.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)

                VStack(spacing: 0) {
                    SettingsPickerRow(
                        label: "bedtime",
                        description: "Notifications soften their tone after this hour.",
                        selection: $store.sleepStartHour,
                        options: Self.hourOptions,
                        formatted: { formatHour($0) }
                    )
                    SettingsDivider()
                    SettingsPickerRow(
                        label: "wake up",
                        description: "Hits before this hour roll into the previous day's stats.",
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
        OnboardingCardChrome(title: "notifications") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Optional, local-only. Three kinds: a confirmation when you log, a gentle nudge when you pass your average gap, and a celebration when you beat your record. Drift hedges its tone overnight, so it won't praise you for being asleep.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        label: "notifications",
                        description: "Master switch. Drift will request permission the first time you turn this on.",
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

private struct LoggingCard: View {
    var body: some View {
        OnboardingCardChrome(title: "logging a hit") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap the **+** tab on the home screen any time you take a hit. Drift records the time and updates everything.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)

                VStack(alignment: .leading, spacing: 8) {
                    Text("for instant logging")
                        .font(.driftRowLabel)
                        .foregroundStyle(.driftInk)
                    Text("Bind \"Log a hit in Drift\" to the **iOS Action Button** — that's the side button on iPhone 15 Pro and later. From iOS Settings → Action Button → Choose Shortcut → search \"Log a hit\".")
                        .font(.driftRowDescription)
                        .foregroundStyle(.driftInkSoft)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("open settings")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftCoral)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .driftCard()

                Text("You can also add \"Log a hit in Drift\" as a Control Center tile (iOS Settings → Control Center → search Drift) or run it from the Shortcuts app.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
        }
    }
}

private struct SpiritPreviewCard: View {
    var body: some View {
        OnboardingCardChrome(title: "meet the spirit") {
            VStack(alignment: .leading, spacing: 16) {
                Text("The longer it's been since your last hit, the bigger the cloud spirit's eyes get. Past your rolling-average gap, the sky starts filling with sparkles.")
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text("Watch the spirit above — it's drifting through the range right now. The sparkles arrive when you've gone longer than usual. No counters, no scoring; just a present-tense picture of where you are.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ConclusionCard: View {
    var body: some View {
        OnboardingCardChrome(title: "happy drifting") {
            VStack(alignment: .leading, spacing: 16) {
                Text("You can change any of these choices anytime in Settings.")
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Text("Everything stays on your device. Drift is free and ad-free — if you'd like to support it, there's a row in Settings → About when you're ready.")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared card chrome

/// Shared layout for every onboarding card: Caveat title at top, content
/// below, breathing room around. Horizontal padding matches the rest of the
/// app's surfaces.
private struct OnboardingCardChrome<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text.caveat(title)
                    .font(.driftHeroLabel)
                    .foregroundStyle(.driftInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - UserDefaults key

/// Shared so `HitStore.resetEverything` can clear it and `RootView` can gate on it.
let driftOnboardingCompleteKey = "drift.onboarding.complete"
