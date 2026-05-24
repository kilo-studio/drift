import SwiftUI

struct HomeView: View, Equatable {
    @Environment(HitStore.self) private var store

    /// Reported up to ContentView only when the over-threshold bool flips —
    /// once on the way down, once on the way back up. As a callback instead
    /// of a binding so HomeView isn't marked dependent on the value.
    let onScrolledChange: (Bool) -> Void

    /// Passed in from ContentView so the placeholder size matches the spirit
    /// rendered in the global overlay.
    let spiritSize: CGFloat

    /// HomeView is wrapped with `.equatable()` at the call site so SwiftUI
    /// can short-circuit re-renders driven by the parent (which recreates
    /// our `onScrolledChange` closure every time `homeScrolled` flips).
    /// Closures aren't Equatable and the closure does the same thing each
    /// render anyway — only the actual rendering inputs need comparing.
    /// Observable changes from `@Environment(HitStore.self)` still trigger
    /// re-renders independently of this equality.
    nonisolated static func == (lhs: HomeView, rhs: HomeView) -> Bool {
        lhs.spiritSize == rhs.spiritSize
    }

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()

            AmbientLayer()

            // Sparkles only after baseline is established — during the
            // establishing period the donut is the focal element and
            // ratio-gated sparkles don't have meaningful data to fire on.
            if store.isBaselineEstablished {
                SparkleField(
                    lastSessionEnd: store.lastSessionEnd(),
                    wakingAvgSec: store.wakingAvgSec(),
                    longestWakingGapSec: store.longestWakingGapSec,
                    layer: .back
                )
            }

            if store.isBaselineEstablished {
                // A coarse 60s tick is enough to flip into long-stretch mode at
                // the 24h threshold (a minute of lag is invisible at day-scale),
                // and it keeps the per-second cost out of the normal dashboard —
                // the long hero's own 1s ticker only exists while in long mode.
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    if isLongStretch(now: ctx.date) {
                        longStretchState
                            .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                    } else {
                        dashboard
                            .transition(.opacity.animation(.easeIn(duration: 0.6)))
                    }
                }
            } else {
                baselineState
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            }

            if store.isBaselineEstablished {
                SparkleField(
                    lastSessionEnd: store.lastSessionEnd(),
                    wakingAvgSec: store.wakingAvgSec(),
                    longestWakingGapSec: store.longestWakingGapSec,
                    layer: .front
                )
            }
        }
    }

    /// True once the last session ended ≥ a day ago — the home reframes into
    /// long-stretch mode. `now` is supplied by the coarse TimelineView so this
    /// stays a pure function of the store + wall clock (no stored state, so
    /// `HomeView`'s `.equatable()` short-circuit is preserved).
    private func isLongStretch(now: Date) -> Bool {
        guard let end = store.lastSessionEnd() else { return false }
        return now.timeIntervalSince(end) >= HitStore.longStretchThresholdSec
    }

    /// Long-stretch home: the durable "free for X" timer, a progress donut
    /// toward the next time milestone, and a "longest drift" reference card. No
    /// frequency cards/charts (meaningless here). Top headroom clears the
    /// resting spirit in ContentView's overlay.
    private var longStretchState: some View {
        let end = store.lastSessionEnd()
        // Scrollable so the milestones-reached card can grow on long drifts
        // without overflowing. Top padding clears the resting spirit overlay.
        // The longest-drift record lives on History → Records, so the home
        // stretch view stays focused: timer, next milestone, badges.
        return ScrollView {
            VStack(spacing: 16) {
                LongStretchHero(lastSessionEnd: end)
                    .padding(.top, spiritSize + 24)
                    .padding(.bottom, 8)

                // Driven by a live 1s timeline (not the coarse mode tick) so the
                // donut counts down and a milestone crossing fires its flourish
                // in sync with the hero, instead of up to a minute late.
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let freeForSec = end.map { ctx.date.timeIntervalSince($0) } ?? 0
                    VStack(spacing: 16) {
                        // Once every milestone is reached there's no "next" —
                        // drop the donut card rather than show a terminal state.
                        if let last = driftMilestones.last, freeForSec < last {
                            NextMilestoneCard(freeForSec: freeForSec)
                        }
                        MilestonesReachedCard(freeForSec: freeForSec)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    /// Pre-baseline home: a single VStack flow so the donut + caption + body
    /// + skip + counts cards never overlap. Three flexible spacers above and
    /// one below balance the cluster vertically without pinning the cards on
    /// top of the text.
    private var baselineState: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()
            Spacer()

            BaselineDonut(
                count: store.baselineCount,
                target: HitStore.baselineTarget
            )
            .frame(width: 200, height: 200)

            Text.caveat("establishing baseline")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .padding(.top, 24)

            Text("Vape as you normally would and log your hits to establish your average time between hits.")
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.baselineSkipped = true
            } label: {
                Text("skip")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkFade)
                    .underline()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()

            countsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Supporting counts. Only renders in sessions mode — in hits mode the
    /// donut already shows the hit count so a separate "hits" card just
    /// duplicates the same number. With sessions on, the two metrics are
    /// distinct (donut tracks sessions; hits is the underlying total).
    @ViewBuilder
    private var countsRow: some View {
        if store.useSessions {
            HStack(spacing: 12) {
                countCard(value: store.baselineCount, label: "sessions")
                countCard(value: store.hits.count, label: "hits")
            }
        }
    }

    private func countCard(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.driftStatNum)
                .foregroundStyle(.driftInk)
            Text(label)
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
        }
        .frame(maxWidth: .infinity)
        .driftCard()
    }


    private var dashboard: some View {
        ScrollViewReader { proxy in
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

                ChartCard(title: "today's drifts", subtitle: "minutes between \(unit.plural) today") {
                    TodayStretchesChart(stretches: store.todayStretches())
                }
                .id("charts-anchor")

                ChartCard(title: "the last fortnight", subtitle: "\(unit.plural) per day · last 14 days") {
                    FortnightChart(counts: store.dailySessionCounts(lastN: 14))
                }

                ChartCard(title: "when the cravings hit", subtitle: "\(unit.plural) by hour of day") {
                    HoursChart(counts: store.sessionsByHour())
                }

                ChartCard(title: "stretching the drift", subtitle: "minutes between \(unit.plural)\n\(store.rollingWindowDays)-day rolling average") {
                    RollingAvgChart(series: store.rollingAvg(lastN: 30))
                }
                .id("charts-bottom")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .onScrollGeometryChange(for: Bool.self) { geom in
            geom.contentOffset.y > 8
        } action: { _, shouldStick in
            onScrolledChange(shouldStick)
        }
        #if DEBUG
        .onAppear {
            // `--home-scroll` jumps to the top of the charts; `--home-scroll-bottom`
            // jumps to the last chart ("stretching the drift"). For App Store
            // screenshots (simctl can't scroll). A short delay lets layout settle.
            let args = ProcessInfo.processInfo.arguments
            let target: (id: String, anchor: UnitPoint)? =
                args.contains("--home-scroll-bottom") ? ("charts-bottom", .bottom)
                : args.contains("--home-scroll") ? ("charts-anchor", .top)
                : nil
            guard let target else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                proxy.scrollTo(target.id, anchor: target.anchor)
            }
        }
        #endif
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
            // Faint ink tint at low opacity reads as a visible-but-subtle
            // track against the sky background — same-color tints (e.g.
            // driftSkyLowerMid at 0.4) blended invisibly into the bg. Bumped
            // up so the empty/low-progress ring is clearly visible rather than
            // reading as no track at all.
            Circle()
                .stroke(Color.driftInk.opacity(0.18), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.driftInk,
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


