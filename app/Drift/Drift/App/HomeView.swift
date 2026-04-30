import SwiftUI

struct HomeView: View {
    @Environment(HitStore.self) private var store

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()

            SparkleField(
                lastSessionEnd: store.lastSessionEnd(),
                wakingAvgSec: store.wakingAvgSec()
            )

            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        HeroPrimaryView(lastHitDate: store.lastSessionEnd())
                        Spacer(minLength: 8)
                        SpiritView(
                            lastSessionEnd: store.lastSessionEnd(),
                            wakingAvgSec: store.wakingAvgSec(),
                            longestWakingGapSec: store.longestWakingGapSec,
                            longestGapSec: store.longestGapSec
                        )
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

                    ChartCard(title: "stretching the gaps", subtitle: "7-day rolling average · minutes between sessions") {
                        RollingAvgChart(series: store.rollingAvg(window: 7, lastN: 30))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }

            #if DEBUG
            debugHitButton
            #endif
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
                title: "average",
                bigNumber: formatAvg(avg),
                bigNumberColor: .driftSageDeep,
                label: "sessions per day · 30d"
            )
        }
    }

    private var wakingGapCard: some View {
        let avg = store.wakingAvgSec()
        return StatCard(
            title: "waking gap",
            bigNumber: avg.map { formatGap($0) } ?? "—",
            bigNumberColor: .driftSageDeep,
            label: "average between sessions · 30d"
        )
    }

    #if DEBUG
    private var debugHitButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    try? store.append()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.driftCoral)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                }
                .contextMenu {
                    Button("Seed 14 days") { seedDebugData() }
                    Button("Reload from prototype") { reloadFromPrototype() }
                    Button("Clear all hits", role: .destructive) { clearAllHits() }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func seedDebugData() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = TimeZone.current.secondsFromGMT() / 60
        var times: [Date] = []
        for dayOffset in 0..<14 {
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -dayOffset, to: now)!)
            let dayCount = Int.random(in: 2...8)
            for _ in 0..<dayCount {
                let minutes = Int.random(in: 360..<1380)  // 6am – 11pm
                if let t = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) {
                    times.append(t)
                }
            }
        }
        for t in times.sorted() where t < now {
            try? store.append(Hit(t: t, tzOffsetMinutes: tz))
        }
    }

    private func clearAllHits() {
        try? store.resetEverything()
    }

    private func reloadFromPrototype() {
        try? store.resetEverything()
        UserDefaults.standard.removeObject(forKey: "drift.migration.scriptable.complete")
        PrototypeMigration.runIfNeeded(store)
    }
    #endif
}
