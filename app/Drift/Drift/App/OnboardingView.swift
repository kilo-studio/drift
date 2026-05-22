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
    /// Per-page scroll state — keyed by page index so each card preserves its
    /// own scrolled flag. Swiping between pages reads the destination page's
    /// stored value, so a previously-scrolled card still shows the spirit in
    /// the corner when you come back to it.
    @State private var pageScrolled: [Int: Bool] = [:]

    /// 7 slides: intro, spirit preview, sleep, notifications, logging,
    /// sessions, conclusion. Sessions sits near the end because it's the
    /// most abstract concept and the user has built familiarity by then.
    private let totalPages = 7
    private let spiritPreviewPage = 1

    private let spiritSize: CGFloat = 96
    /// Synthetic average used to drive both the resting top-spirit ratio and
    /// the spirit-preview animation. One hour reads as a believable typical gap.
    private let demoAvgSec: TimeInterval = 3600

    /// Whether the currently-visible card is scrolled. Derived from
    /// `pageScrolled` so the spirit reflects the actual scroll state of
    /// whichever card is showing.
    private var cardScrolled: Bool {
        pageScrolled[page] ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                        spiritPercent: spiritPercentForSparkles
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            TabView(selection: $page) {
                IntroCard(scrolled: bindingFor(0)).tag(0)
                SpiritPreviewCard(scrolled: bindingFor(1)).tag(1)
                SleepCard(store: store, scrolled: bindingFor(2)).tag(2)
                NotificationsCard(store: store, scrolled: bindingFor(3)).tag(3)
                LoggingCard(scrolled: bindingFor(4)).tag(4)
                SessionsCard(store: store, scrolled: bindingFor(5)).tag(5)
                ConclusionCard(scrolled: bindingFor(6)).tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            stickyBottom

            spiritOverlay
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.25), value: page)
    }

    private func bindingFor(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { pageScrolled[index] ?? false },
            set: { pageScrolled[index] = $0 }
        )
    }

    // MARK: - Spirit overlay

    /// Global spirit overlay positioned in screen coordinates. Rest position
    /// depends on page — the spirit-preview card pulls it down toward the
    /// vertical center so the demo isn't crammed against the top.
    private var spiritOverlay: some View {
        GeometryReader { geo in
            let rest = restCenter(in: geo.size)
            let sticky = CGPoint(x: geo.size.width - 8 - spiritSize / 2, y: spiritSize / 2)
            let target = cardScrolled ? sticky : rest

            topSpirit
                .frame(width: spiritSize, height: spiritSize)
                .scaleEffect(cardScrolled ? 0.7 : 1.0, anchor: .topTrailing)
                .position(x: target.x, y: target.y)
                .animation(.spring(response: 0.55, dampingFraction: 0.7), value: cardScrolled)
                .animation(.spring(response: 0.55, dampingFraction: 0.7), value: page)
        }
    }

    /// Page-aware rest position. Default is high-and-centered; spirit-preview
    /// shifts down so the demo reads as the focal element of the slide.
    private func restCenter(in size: CGSize) -> CGPoint {
        let restY: CGFloat = page == spiritPreviewPage ? 240 : (60 + spiritSize / 2)
        return CGPoint(x: size.width / 2, y: restY)
    }

    /// Where the sparkle halo centers on the spirit-preview slide. Tied to
    /// `restCenter` so the halo follows the spirit's lowered position.
    private var spiritPercentForSparkles: CGPoint {
        // Sparkles use viewport-percentage coords; assume an ~852pt iPhone height
        // and compute. The percent doesn't need to be exact — sparkles just sort
        // by distance to this point for the reveal-order curve.
        let restYPct = 240.0 / 852.0 * 100
        return CGPoint(x: 50, y: restYPct)
    }

    /// Single `TimelineView` for the spirit on every page — only the inputs
    /// change. This avoids the view-tree change that caused a cross-fade
    /// flash when navigating between the preview card and the others.
    private var topSpirit: some View {
        TimelineView(.animation) { ctx in
            let isPreview = page == spiritPreviewPage
            let ratio: Double = isPreview ? demoRatio(at: ctx.date) : 1.5
            let lastSessionEnd = ctx.date.addingTimeInterval(-ratio * demoAvgSec)

            SpiritView(
                lastSessionEnd: lastSessionEnd,
                wakingAvgSec: demoAvgSec,
                longestWakingGapSec: isPreview ? demoAvgSec * 2 : 0,
                longestGapSec: isPreview ? demoAvgSec * 3.5 : 0,
                stableFloat: isPreview
            )
        }
    }

    /// Cosine-eased loop between ratio 0.3 and 5 over 12s.
    private func demoRatio(at date: Date) -> Double {
        let cycleSec: Double = 12
        let cyclePos = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleSec) / cycleSec
        let t = (1 - cos(cyclePos * .pi * 2)) / 2
        return 0.3 + (5 - 0.3) * t
    }

    // MARK: - Sticky bottom

    private var stickyBottom: some View {
        VStack(spacing: 18) {
            Button(action: advance) {
                Text(ctaLabel)
                    .font(.driftRowLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        Capsule().fill(Color.driftCoral)
                    }
            }
            .buttonStyle(.plain)

            pageDots
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            ArcedTop(archHeight: 22)
                .fill(Color.driftCream)
                .ignoresSafeArea(edges: .bottom)
        )
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

// MARK: - Sticky bottom shape

/// Bottom strip with an arc rising into the middle of its top edge — soft
/// separator between the scrollable carousel and the sticky CTA area beneath.
/// `archHeight` is the offset of the side endpoints below the rect's top edge;
/// the curve peaks at y = 0 in the middle.
private struct ArcedTop: Shape {
    let archHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: archHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: archHeight),
            control: CGPoint(x: rect.width / 2, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Card chrome

/// Shared layout for every onboarding card. Wraps content in a ScrollView so
/// long settings stacks remain reachable on smaller devices, reports the
/// scroll state back to OnboardingView so the global spirit can react, and
/// pads enough top/bottom space to clear the spirit and sticky bottom.
private struct OnboardingCardChrome<Content: View>: View {
    @Binding var scrolled: Bool
    /// Per-card top padding override — the spirit-preview card pushes content
    /// lower so the title sits near the vertical middle rather than crammed
    /// under a top-anchored spirit. Default 180 matches the spirit's resting
    /// position + breathing room.
    var topPadding: CGFloat = 180
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, topPadding)
            .padding(.horizontal, 20)
            .padding(.bottom, 200)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geom in
            geom.contentOffset.y > 8
        } action: { _, newValue in
            if newValue != scrolled {
                scrolled = newValue
            }
        }
    }
}

// MARK: - Cards

private struct IntroCard: View {
    @Binding var scrolled: Bool

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 12) {
                // Extra trailing thin-space so the Caveat "t" swash at this
                // size doesn't get clipped by the Text frame.
                Text("\u{2009}\u{2009}drift\u{2009}\u{2009}\u{2009}")
                    .font(.custom("Caveat", size: 72).weight(.semibold))
                    .foregroundStyle(.driftInk)

                Text("wean off vaping")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    factLine("Data stays on your device.")
                    factLine("No ads, no tracking.")
                    factLine("Completely free.")
                }
                .padding(.top, 28)
            }
        }
    }

    private func factLine(_ text: String) -> some View {
        Text(text)
            .font(.onboardingSubtitle)
            .foregroundStyle(.driftInk)
    }
}

private struct SpiritPreviewCard: View {
    @Binding var scrolled: Bool

    var body: some View {
        // Push content well below the lowered spirit so the title sits near
        // the vertical middle of the visible card area.
        OnboardingCardChrome(scrolled: $scrolled, topPadding: 340) {
            VStack(spacing: 16) {
                Text("make your spirit happy")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Drift past your average gap between hits to make your spirit happy. The longer between hits, the happier your spirit.")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct SleepCard: View {
    @Bindable var store: HitStore
    @Binding var scrolled: Bool

    private static let hourOptions: [Int] = Array(0...23)

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 20) {
                Text("sleep window")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Drift won't send notifications during your sleep window. Hits before end of day count as the previous day's stats.")
                    .font(.onboardingSubtitle)
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
                        label: "end of day",
                        description: "Hits before this hour count as the previous day.",
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
    @Binding var scrolled: Bool

    /// Offset picker options for the "beat your average" timing. Stored in
    /// seconds (0, 1m, 5m, 10m, 15m). Matches `NotificationsView`'s shape.
    private static let offsetOptions: [TimeInterval] = [0, 60, 300, 600, 900]

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 20) {
                Text("notifications")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Wait at least until you're notified you're beating your average before the next hit and you'll be drifting!")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    SettingsToggleRow(
                        label: "notifications",
                        description: "Master switch.",
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
                        if store.notifsBeatAverageEnabled {
                            SettingsDivider()
                            SettingsPickerRow(
                                label: "gap after average",
                                description: "How long past your average before the nudge fires.",
                                selection: $store.notifsBeatAverageOffsetSec,
                                options: Self.offsetOptions,
                                formatted: { formatOffset($0) }
                            )
                        }
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
        .onAppear {
            // Request permission as soon as the user lands on this card —
            // the master switch defaults on, so otherwise we'd never trigger
            // the prompt. iOS only shows the dialog once per install; later
            // calls return the existing status.
            Task { await requestNotificationPermission() }
        }
    }

    private func formatOffset(_ sec: TimeInterval) -> String {
        if sec == 0 { return "right at" }
        let m = Int(sec / 60)
        return m == 1 ? "+1 min" : "+\(m) min"
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}

private struct LoggingCard: View {
    @Binding var scrolled: Bool

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 20) {
                Text("quick ways to log")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Make it easy to log hits. The easier it is, the more likely you'll stay honest.")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                LoggingMethodCard(
                    title: "Action button",
                    description: "Bind \"Log a hit in Drift\" to the side button on your iPhone. The fastest way to log, even from the lock screen.",
                    buttonLabel: "Open iOS Settings",
                    action: openIOSSettings
                )

                LoggingMethodCard(
                    title: "Control Center",
                    description: "Add Drift as a Control Center tile so logging is one swipe away.",
                    buttonLabel: "Open Control Center settings",
                    action: openIOSSettings
                )

                LoggingMethodCard(
                    title: "Shortcuts",
                    description: "\"Log a hit in Drift\" is already in the Shortcuts app — use it from Siri, the lock screen, or a home screen widget.",
                    buttonLabel: "Open Shortcuts",
                    action: openShortcuts
                )
            }
        }
    }

    private func openIOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openShortcuts() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

private struct LoggingMethodCard: View {
    let title: String
    let description: String
    let buttonLabel: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.driftRowLabel)
                .foregroundStyle(.driftInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(description)
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Secondary button — soft glass with coral text.
            Button(action: action) {
                Text(buttonLabel)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftCoral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .glassEffect(
                        .regular.tint(.driftSkyLowerMid.opacity(0.4)),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .driftCard()
    }
}

private struct SessionsCard: View {
    @Bindable var store: HitStore
    @Binding var scrolled: Bool

    private static let thresholdOptions: [TimeInterval] = [60, 180, 300, 600, 900, 1800]

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 20) {
                Text("use sessions?")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Sessions group multiple hits in rapid succession into a single session. Drift will measure time between sessions instead of time between hits.")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
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

private struct ConclusionCard: View {
    @Binding var scrolled: Bool

    /// Tip-jar destination. Swap to the real Buy Me a Coffee URL once the
    /// page is live; this placeholder reads OK in the meantime.
    private static let tipJarURL = URL(string: "https://buymeacoffee.com/griffinmullins")!

    var body: some View {
        OnboardingCardChrome(scrolled: $scrolled) {
            VStack(spacing: 20) {
                Text("you got this")
                    .font(.onboardingTitle)
                    .foregroundStyle(.driftInk)
                    .multilineTextAlignment(.center)

                Text("Change any of these anytime in Settings.")
                    .font(.onboardingSubtitle)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)

                Text(tipJarSentence)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    /// Built explicitly as `AttributedString` so the link text really gets the
    /// SemiBold weight — SwiftUI's Markdown shortcut applies link styling on
    /// top of `**bold**`, which in practice swallowed the bold weight inside
    /// the link span.
    private var tipJarSentence: AttributedString {
        var s = AttributedString("Drift is completely free forever, but if you'd like to show your support, you can buy me a coffee.")
        s.font = .onboardingSubtitle
        s.foregroundColor = .driftInkSoft

        if let range = s.range(of: "buy me a coffee") {
            s[range].link = Self.tipJarURL
            s[range].font = Font.custom("Quicksand-SemiBold", size: 17)
            s[range].foregroundColor = .driftCoral
        }
        return s
    }
}

// MARK: - Typography

extension Font {
    /// Large onboarding header. Quicksand SemiBold so it's clearly readable
    /// and doesn't compete with the "drift" wordmark for "handwritten" energy
    /// — that face is reserved for the brand mark itself in this flow.
    static let onboardingTitle = Font.custom("Quicksand-SemiBold", size: 28)

    /// Subheader / body copy in onboarding. iOS body is 17pt — matches that
    /// for readability; Medium weight keeps it subordinate to the title.
    static let onboardingSubtitle = Font.custom("Quicksand-Medium", size: 17)
}

// MARK: - UserDefaults key

/// Shared so `HitStore.resetEverything` can clear it and `RootView` can gate on it.
let driftOnboardingCompleteKey = "drift.onboarding.complete"
