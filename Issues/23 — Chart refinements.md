---
status: todo
priority: medium
tags: [dashboard, charts, polish, v1.x]
---

# Chart refinements

The four charts on home (`Charts/HoursChart`, `Charts/TodayStretchesChart`,
`Charts/FortnightChart`, `Charts/RollingAvgChart`) all shipped in v1 as read-only,
fixed-window summaries. Living with them on real data has surfaced a batch of
quality-of-life gaps: you can see the shape but you can't ask the chart anything,
you can't scroll back in time when a window cuts off interesting data, an axis
label sometimes truncates at the right edge, and the y-axis bounds don't always
respect the data range. None of this is broken — it's the next layer of polish
now that the underlying data is right.

Post-v1 (App Store v1 released 2026-05-28). Land in v1.x.

## Scope

### 1. Tap a point to see its details

Each chart should let you tap a data point and surface the exact value behind
it — date / hour and the metric, in a small annotation or callout. SwiftUI
Charts has `chartXSelection(value:)` (and `chartXSelection(range:)` for bars);
iOS 26 supports both cleanly. Pattern:

- `@State private var selected: Date?` (or `Int?` for hour-of-day on
  `HoursChart`).
- `.chartXSelection(value: $selected)` on each chart.
- A `RuleMark` at the selected x plus an `.annotation(position: .top)` showing
  the value(s) in `driftSub` type. Snap the annotation inside the plot bounds.
- On `FortnightChart` (per-day session counts) and `HoursChart` (per-hour
  bars), tapping a bar should highlight that bar and show the count.
- On `RollingAvgChart` and `TodayStretchesChart`, tapping should show the
  point's date + minute value.

Keep it light — no haptic, no modal. Tap again or tap empty space to clear.
A small line of `driftSub` text near the value is enough.

### 2. Swipe through time on the time-series charts

Only the time-axis charts — `FortnightChart` and `RollingAvgChart` — need this.
Hour-of-day and today's stretches are bounded to the current day and don't have
"earlier" to scroll to.

The fortnight is the primary case: **default-visible window is the last 14 days
(today on the right edge); you can swipe backward through history a fortnight
at a time.** Same shape applies to the rolling-avg chart with its own window.
Pass `series:` from `HitStore` with enough history to scroll into (not just the
current visible window) — the existing call sites pull `dailySessionCounts(lastN:
14)` / `rollingAvg(lastN: 30)`, which need to widen to cover the data we want
scrollable.

- `.chartScrollableAxes(.horizontal)` on both charts.
- `.chartXVisibleDomain(length: <14 days | 28 days>)` so the default-visible
  window is exactly one fortnight / one rolling window.
- `.chartScrollPosition(initialX: <today's date>)` so each chart opens with
  the most recent window in view (right edge = today).
- `.chartScrollTargetBehavior(.valueAligned(matching: DateComponents(hour: 0)))`
  so flicks snap to day boundaries.
- Widen the data source: pass the full available `dailySessionCounts` / rolling
  avg, not just the last 14 / 30 days, so swipes have somewhere to go.

History view's per-day chart context (the existing month nav) stays the
authoritative way to jump to a specific past day. Scroll on home is for
glancing back, not navigation.

### 3. Truncated axis labels

Visible today on `RollingAvgChart`: the rightmost tick reads "May…" because
the "May 24" label gets clipped at the plot's right edge (see the user
screenshot on 2026-05-28). Same risk on `FortnightChart`. The root cause is
`AxisMarks(values: .automatic(desiredCount: 4))` letting the last tick land
flush with the plot edge while the label extends past it.

Fix options, in order of preference:

- **Explicit stride** — replace `.automatic(desiredCount: 4)` with
  `AxisMarks(values: .stride(by: .day, count: 7))` on the rolling-avg chart
  (4 ticks across 28 days), and a similar stride on `FortnightChart`. Predictable
  positions, last tick lands earlier than the right edge.
- **Anchor the label** — `AxisValueLabel(anchor: .topTrailing)` for the last
  tick so it grows leftward into the plot rather than off the right.
- **Plot padding** — `.chartXScale(domain: .automatic(includesZero: false, reversed: false), range: .plotDimension(padding: 8))`
  (or a small trailing pad on the x-scale domain itself) so no tick can hug
  the right edge.

The stride approach is the most predictable; combine with trailing pad if
needed.

### 4. Smarter y-axis bounds

`HoursChart` and `FortnightChart` show session counts and should keep their
zero baseline — a bar chart that doesn't start at zero misreads. Leave those.

`RollingAvgChart` and `TodayStretchesChart` show duration (minutes) and don't
need to start at zero. Today on `RollingAvgChart`, real data sits ~40-85 min
but the y-axis spans 0-100, so a third of the plot is empty headroom and the
trend looks flatter than it is. Fix:

- `.chartYScale(domain: .automatic(includesZero: false))` on `RollingAvgChart`
  and `TodayStretchesChart`. Charts will pick a nice rounded domain that hugs
  the data.
- Keep `AxisMarks(position: .leading, values: .automatic(desiredCount: 3))`
  as-is so the y-axis still reads with three labels.
- Sanity test against the seed scenarios in `HitStore.SeedScenario` (longMonth,
  maxedOut, nearMilestone) and the user's real data via the import-doc launch
  arg so we know the auto-domain reads well across ranges.

### 5. Chart titles + subtitles pass

Once the time-series charts become scrollable, the current chart card titles
and subtitles need a pass — they currently presume a fixed "right now" window
that's no longer true.

Today's strings (`HomeView.swift` lines ~230-239):

- Fortnight: title **"the last fortnight"** / subtitle **"\(unit.plural) per
  day · last 14 days"** — "the last fortnight" and "last 14 days" both
  hard-claim the current window. Swiping back makes them misleading.
- Cravings: title **"when the cravings hit"** / subtitle **"\(unit.plural) by
  hour of day"** — fine; hour-of-day is window-agnostic and the chart isn't
  scrollable. No change.
- Rolling avg: title **"stretching the drift"** / subtitle **"minutes between
  \(unit.plural)\n\(rollingWindowDays)-day rolling average"** — the metric
  (n-day rolling average of minutes between sessions) is window-agnostic and
  reads fine, but the title presumes a recency framing too.

Direction (decide during implementation): drop the "last 14 days" / "the last
fortnight" framing from the static title/subtitle and let the visible-window
range read from the x-axis instead, **or** make the subtitle dynamic so it
reflects the currently-visible range as you scroll (e.g. "May 14 — May 28").
Dynamic is more honest but requires the chart to publish its visible range
back up to the card. Static + window-agnostic copy is simpler. Pick the
simpler one unless the dynamic range adds enough clarity to justify the
plumbing.

Either way, the title-and-subtitle copy is the user-facing wording and
deserves a small editorial pass on its own merits, not just to match the
new behavior.

## Files

- `app/Drift/Drift/App/Charts/RollingAvgChart.swift` — items 1, 2, 3, 4
- `app/Drift/Drift/App/Charts/FortnightChart.swift` — items 1, 2, 3
- `app/Drift/Drift/App/Charts/HoursChart.swift` — item 1
- `app/Drift/Drift/App/Charts/TodayStretchesChart.swift` — items 1, 4
- `app/Drift/Drift/App/HomeView.swift` — item 5 (chart card titles/subtitles,
  the `dailySessionCounts(lastN:)` / `rollingAvg(lastN:)` window widening for
  item 2)

## Out of scope

- Cross-chart linked selection. Each chart's selection is independent.
- Long-press / drag-select ranges. Single tap is enough for v1.x.
- New chart types or new metrics. This is polish on what's there.
- Re-architecting metrics in `Data/Metrics.swift`. The existing series functions
  already return the (date, value) tuples each chart needs.

## Verification

1. Build + run with `--seed longMonth` (rich history).
2. Tap a point on each of the four charts; the value + date/hour annotation
   appears, snapped inside the plot bounds; tapping empty plot clears.
3. On `RollingAvgChart` and `FortnightChart`, the default-visible window is the
   most recent fortnight / rolling window (right edge = today); flick left to
   scroll back through history; snapping aligns to day boundaries.
3a. Chart card titles + subtitles read honestly while scrolled back — no
    "last 14 days" claim that contradicts a visible past window.
4. Rightmost x-axis label on `RollingAvgChart` and `FortnightChart` renders
   in full, no "…" truncation, on the 6.9" sim.
5. `RollingAvgChart`'s y-axis hugs the data (e.g. with real ~40-85 min data
   it reads 30 / 60 / 90 or similar, not 0 / 50 / 100).
6. Bar charts (`HoursChart`, `FortnightChart`) still baseline at 0.
