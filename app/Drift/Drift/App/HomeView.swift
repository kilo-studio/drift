import SwiftUI

struct HomeView: View {
    @Environment(HitStore.self) private var store

    /// Trigger flips when the user starts scrolling and back when they return
    /// near the top — drives a keyframe-based swoop animation that interpolates
    /// the spirit's screen-space position over a curved path.
    @State private var isStuck: Bool = false

    private let spiritSize: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
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
                            // Placeholder where the spirit normally sits, so the
                            // hero layout doesn't reflow when the spirit is rendered
                            // separately as a screen-space overlay.
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
                    .padding(.bottom, 96)
                }
                .onScrollGeometryChange(for: Bool.self) { geom in
                    // 8pt of slack so the spirit doesn't twitch on tiny rubber-band
                    // overscrolls; comes back when scroll returns near the top.
                    geom.contentOffset.y > 8
                } action: { _, shouldStick in
                    if shouldStick != isStuck {
                        isStuck = shouldStick
                    }
                }

                // Spirit lives outside the ScrollView so it can stick to a
                // screen-space position. Keyframe animator drives a swoop curve
                // when isStuck flips: vertical rises first, then horizontal
                // slides over to the corner. Reverse on return.
                spiritFlight(in: geo.size)

                // Front sparkle layer — rare and big, same ratio-gated reveal as
                // the back. Reads as "closer to the camera" sparkles drifting in
                // front of the cards as you stretch further past your average.
                SparkleField(
                    lastSessionEnd: store.lastSessionEnd(),
                    wakingAvgSec: store.wakingAvgSec(),
                    layer: .front
                )

                #if DEBUG
                debugHitButton
                #endif
            }
        }
    }

    /// Animatable spirit, swooping between rest and sticky.
    @ViewBuilder
    private func spiritFlight(in size: CGSize) -> some View {
        let rest = restCenter(in: size)
        let sticky = stickyCenter(in: size)
        let target = isStuck ? sticky : rest

        SpiritView(
            lastSessionEnd: store.lastSessionEnd(),
            wakingAvgSec: store.wakingAvgSec(),
            longestWakingGapSec: store.longestWakingGapSec,
            longestGapSec: store.longestGapSec
        )
        .frame(width: spiritSize, height: spiritSize)
        .scaleEffect(isStuck ? 0.7 : 1.0, anchor: .topTrailing)
        .position(x: target.x, y: target.y)
        // Bouncy spring gives a natural swoop feel — overshoots slightly past
        // the destination on its way in, settles back. Both directions.
        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: isStuck)
    }

    /// Spirit center at rest — matches the placeholder position in the hero row.
    /// scaleEffect anchor is .topTrailing, so when scale=1 the bbox center is
    /// the unscaled center; nothing exotic on the rest side.
    private func restCenter(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - 16 - spiritSize / 2 - 16,
            y: 36 + 24 + spiritSize / 2
        )
    }

    /// Spirit center when stuck — top-right corner of safe area, scaled down so
    /// the visible top-right pixel sits ~4pt from the actual screen corner.
    /// With anchor .topTrailing, the unscaled bbox's top-right corner stays at
    /// the position we compute, and the rest of the body shrinks toward it.
    private func stickyCenter(in size: CGSize) -> CGPoint {
        let xinset: CGFloat = 16
        let yinset: CGFloat = 0
        return CGPoint(
            x: size.width - xinset - spiritSize / 2,
            y: yinset + spiritSize / 2
        )
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
