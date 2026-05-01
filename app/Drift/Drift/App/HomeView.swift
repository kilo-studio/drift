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

                    wakingGapCard

                    ChartCard(title: "today's stretches", subtitle: "minutes between sessions today") {
                        TodayStretchesChart(stretches: store.todayStretches())
                    }

                    ChartCard(title: "the last fortnight", subtitle: "sessions per day · last 14 days") {
                        FortnightChart(counts: store.dailySessionCounts(lastN: 14))
                    }

                    ChartCard(title: "when the cravings hit", subtitle: "sessions by hour of day") {
                        HoursChart(counts: store.sessionsByHour())
                    }

                    ChartCard(title: "stretching the gaps", subtitle: "minutes between sessions\n7-day rolling average") {
                        RollingAvgChart(series: store.rollingAvg(window: 7, lastN: 30))
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

    private var statCardsRow: some View {
        let sessions = store.todaySessionCount()
        let hits = store.todayHitCount()
        let avg = store.avgSessionsPerDay()
        return HStack(spacing: 16) {
            StatCard(
                title: "sessions today",
                bigNumber: "\(sessions)",
                bigNumberColor: .driftCoral,
                label: "\(hits) hit\(hits == 1 ? "" : "s")"
            )
            StatCard(
                title: "avg / day",
                bigNumber: formatAvg(avg),
                bigNumberColor: .driftSageDeep,
                label: "\(Int(store.avgHitsPerDay().rounded())) hits"
            )
        }
    }

    private var wakingGapCard: some View {
        let avg = store.wakingAvgSec()
        return StatCard(
            title: "waking gap",
            bigNumberParts: avg.map { formatGapParts($0) } ?? [.number("—")],
            bigNumberColor: .driftSageDeep,
            label: "average between sessions · 30d"
        )
    }
}


