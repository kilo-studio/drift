import SwiftUI

struct HomeView: View {
    @Environment(HitStore.self) private var store

    /// Reported up to ContentView so the spirit (rendered globally) can swoop
    /// to the corner. True past 8pt of scroll, false near the top.
    @Binding var homeScrolled: Bool

    /// Passed in from ContentView so the placeholder size matches the spirit
    /// rendered in the global overlay.
    let spiritSize: CGFloat

    /// One-time celebration banner when the user logs the hit/session that
    /// crosses the baseline threshold. Skipped users don't see this — they
    /// chose to bypass establishing.
    @State private var showBaselineToast = false

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()

            AmbientLayer()

            SparkleField(
                lastSessionEnd: store.lastSessionEnd(),
                wakingAvgSec: store.wakingAvgSec(),
                layer: .back
            )

            if store.isBaselineEstablished {
                dashboard
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
            } else {
                baselineState
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            }

            // Front sparkle layer — rare and big, same ratio-gated reveal as
            // the back. Reads as "closer to the camera" sparkles drifting in
            // front of the cards as you stretch further past your average.
            SparkleField(
                lastSessionEnd: store.lastSessionEnd(),
                wakingAvgSec: store.wakingAvgSec(),
                layer: .front
            )
        }
        .overlay(alignment: .top) { baselineToast }
        .onChange(of: store.baselineCount) { oldCount, newCount in
            // Only celebrate real establishings — skip should silently switch
            // to the post-baseline UI without congratulating the user for
            // bypassing the period.
            if oldCount < HitStore.baselineTarget,
               newCount >= HitStore.baselineTarget,
               !store.baselineSkipped {
                withAnimation(.easeOut(duration: 0.3)) {
                    showBaselineToast = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(.easeIn(duration: 0.4)) {
                        showBaselineToast = false
                    }
                }
            }
        }
    }

    /// Pre-baseline home: spirit lives in its top-right rest position (via
    /// ContentView's overlay), donut + caption sit roughly centered, "tap +
    /// below" hint surfaces when the user hasn't logged anything yet, and a
    /// small Skip link lives at the bottom.
    private var baselineState: some View {
        VStack(spacing: 0) {
            Spacer()

            BaselineDonut(
                count: store.baselineCount,
                target: HitStore.baselineTarget
            )
            .frame(width: 220, height: 220)

            Text.caveat("establishing baseline")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .padding(.top, 24)

            Text(baselineCopy)
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()

            Button {
                store.baselineSkipped = true
            } label: {
                Text("skip")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkFade)
                    .underline()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Body copy under the donut. Switches based on whether the user has
    /// logged anything yet — at 0 the priority is pointing them at the +
    /// tab; after that we lean into "keep logging."
    private var baselineCopy: String {
        if store.baselineCount == 0 {
            return "Tap + below to log your first hit. Vape as you normally would so Drift can learn your patterns."
        }
        return "Vape as you normally would and log them so Drift can learn your patterns."
    }

    /// Earned-moment toast that floats in from the top, dwells ~3s, fades out.
    @ViewBuilder
    private var baselineToast: some View {
        if showBaselineToast {
            Text.caveat("now let's start drifting!")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule().stroke(Color.driftCoral.opacity(0.35), lineWidth: 1)
                        )
                }
                .padding(.top, 72)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    HeroPrimaryView(lastHitDate: store.lastSessionEnd())
                    Spacer(minLength: 8)
                    // Placeholder matches the spirit's rest position; the
                    // actual spirit lives in ContentView's ZStack so it
                    // persists across tab switches.
                    Color.clear
                        .frame(width: spiritSize, height: spiritSize)
                        .offset(x: -16, y: 24)
                }
                .padding(.top, 36)

                HeroBestsView(
                    longestWakingGapSec: store.longestWakingGapSec,
                    longestGapSec: store.longestGapSec
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)

                statCardsRow

                wakingGapRow

                ChartCard(title: "today's stretches", subtitle: "minutes between \(unit.plural) today") {
                    TodayStretchesChart(stretches: store.todayStretches())
                }

                ChartCard(title: "the last fortnight", subtitle: "\(unit.plural) per day · last 14 days") {
                    FortnightChart(counts: store.dailySessionCounts(lastN: 14))
                }

                ChartCard(title: "when the cravings hit", subtitle: "\(unit.plural) by hour of day") {
                    HoursChart(counts: store.sessionsByHour())
                }

                ChartCard(title: "stretching the gaps", subtitle: "minutes between \(unit.plural)\n\(store.rollingWindowDays)-day rolling average") {
                    RollingAvgChart(series: store.rollingAvg(lastN: 30))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .onScrollGeometryChange(for: Bool.self) { geom in
            geom.contentOffset.y > 8
        } action: { _, shouldStick in
            if shouldStick != homeScrolled {
                homeScrolled = shouldStick
            }
        }
    }

    /// Whether the user is in session-mode (default) or hit-mode (Issue 16's "use
    /// sessions" toggle off). Drives the singular/plural unit nouns sprinkled
    /// across labels and chart subtitles, and toggles the secondary "Y hits"
    /// line on the today card (redundant when every event is a hit).
    private var unit: (singular: String, plural: String) {
        store.useSessions ? ("session", "sessions") : ("hit", "hits")
    }

    private var statCardsRow: some View {
        let primary = store.useSessions ? store.todaySessionCount() : store.todayHitCount()
        let hits = store.todayHitCount()
        let avg = store.avgSessionsPerDay()
        return HStack(spacing: 16) {
            StatCard(
                title: "\(unit.plural) today",
                bigNumber: "\(primary)",
                bigNumberColor: .driftCoral,
                label: store.useSessions ? "\(hits) hit\(hits == 1 ? "" : "s")" : "today"
            )
            StatCard(
                title: "avg / day",
                bigNumber: formatAvg(avg),
                bigNumberColor: .driftSageDeep,
                label: store.useSessions ? "\(Int(store.avgHitsPerDay().rounded())) hits" : "per day"
            )
        }
    }

    private var wakingGapRow: some View {
        let today = store.todayWakingAvgSec()
        let rolling = store.wakingAvgSec()
        return HStack(spacing: 16) {
            StatCard(
                title: "today's avg",
                bigNumberParts: today.map { formatGapParts($0) } ?? [.number("—")],
                bigNumberColor: .driftSageDeep,
                label: "between \(unit.plural)"
            )
            StatCard(
                title: "\(store.rollingWindowDays)-day avg",
                bigNumberParts: rolling.map { formatGapParts($0) } ?? [.number("—")],
                bigNumberColor: .driftSageDeep,
                label: "between \(unit.plural)"
            )
        }
    }
}

/// Circular progress donut for the baseline state. Thick stroke, count in
/// the center using the Caveat face — matches the rest of the app's hero
/// visual language. The track sits at low opacity; the filled arc lerps in
/// over the elapsed count.
private struct BaselineDonut: View {
    let count: Int
    let target: Int

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(count) / Double(target))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.driftInkFade.opacity(0.2), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.driftCoral,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)

            VStack(spacing: -4) {
                Text("\(count)")
                    .font(.driftDisplay)
                    .foregroundStyle(.driftInk)
                Text("of \(target)")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
        }
    }
}


