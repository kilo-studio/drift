import SwiftUI

struct HomeView: View {
    @Environment(HitStore.self) private var store

    /// Reported up to ContentView so the spirit (rendered globally) can swoop
    /// to the corner. True past 8pt of scroll, false near the top.
    @Binding var homeScrolled: Bool

    /// Passed in from ContentView so the placeholder size matches the spirit
    /// rendered in the global overlay.
    let spiritSize: CGFloat

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()

            AmbientLayer()

            SparkleField(
                lastSessionEnd: store.lastSessionEnd(),
                wakingAvgSec: store.wakingAvgSec(),
                layer: .back
            )

            if store.hits.isEmpty {
                emptyState
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            } else {
                dashboard
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
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
    }

    /// Centered welcome surface shown before the first hit is logged. The
    /// global spirit stays in its top-right rest position; the page-level
    /// invite reads underneath. After the first hit, the dashboard fades in
    /// and replaces this.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("drift")
                .font(.driftDisplay)
                .foregroundStyle(.driftInk)
            Text("Tap the + tab when you take a hit.\nDrift takes it from there.")
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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


