---
status: todo
priority: medium
tags: [dashboard, milestones, philosophy, v1.x]
---

# First-milestone donut on home

Add a card at the **very bottom of the normal home dashboard** (after
"stretching the drift") that's a filling donut counting toward the first
milestone, **1 day free**. It's the same shape as the long-stretch
`NextMilestoneCard` (Issue 22) — just earlier in the journey. The intent is to
make the gap between "today's data" and "long-stretch mode" feel like a
continuous climb instead of a hard mode switch: you can already see the next
target while you're still in normal mode, and once you cross 24h it's the
long-stretch hero that takes over.

Pairs with [[Issues/22 — Long-stretch mode]] and shares its philosophy
guardrails — this is **visualization, not a streak**. The donut describes
right now (free-for / 24h), not "you"; it can fill, empty, and fill again
without judgement, the same way the spirit grows and shrinks.

Post-v1 (App Store v1 released 2026-05-28). Land in v1.x.

## What it shows

A `ChartCard`-style card at the bottom of the home dashboard scroll, below the
"stretching the drift" rolling-avg chart. Inside:

- A progress donut centered on the milestone label (**"1 day"**, formatted via
  `formatDurationHuman`), filling from 0 to 24h based on the current free-for.
- A small label below the donut: **"\(formatGap(remaining)) to go"** while
  under the milestone (e.g. "9h 30m to go").
- Title up top: **"next milestone"** (or **"approaching 1 day"** — decide
  during implementation; the long-stretch card already uses "next milestone"
  and the consistency is probably worth it).

Visually identical to `NextMilestoneCard` in `LongStretchView.swift` — same
ring weight, same `driftSageDeep` fill, same animation cadence. Lives inside a
`.driftCard()` like every other home card.

## Behavior

- **Live tick**: the card reads free-for from `now − store.lastSessionEnd()`,
  tied to a coarse `TimelineView(.periodic(by: 60))`. 60s is enough — the
  donut fills 1/24 per hour (≈ 0.001 per second; invisible per-second). A
  per-second ticker isn't needed here and would burn battery on a card sitting
  off-screen most of the time.
- **Visibility gate**: only render when `store.isBaselineEstablished` is true
  AND `freeForSec < 86_400`. In baseline mode there's no meaningful "free-for"
  to chart. At 24h+ the home flips to long-stretch mode and that mode's own
  (larger) donut takes over, so this card is no longer onscreen — there's no
  duplication.
- **Reset on log**: free-for resets to ~0 when a hit is logged. The donut
  empties with the existing `.animation(.easeOut(duration: 0.5))` already
  baked into `NextMilestoneCard`. No celebration or shame copy on reset; the
  spirit already carries the emotional read.
- **Post-relapse re-entry**: someone who'd previously crossed 24h and relapsed
  comes back to normal mode and sees this donut at 0. That's correct and not
  patronizing — it's *the present moment described neutrally*. Their longest
  drift record persists separately on History → Records (set in Issue 22).

## Implementation

### 1. `App/HomeView.swift` (the only meaningful change)

Append the card to the dashboard's `LazyVStack` after the "stretching the
drift" `ChartCard` (currently the last card, anchored by `.id("charts-bottom")`).
Wrap it in a `TimelineView` so it ticks against wall clock without forcing the
whole dashboard to re-render:

```swift
TimelineView(.periodic(from: .now, by: 60)) { ctx in
    if let end = store.lastSessionEnd() {
        let freeFor = ctx.date.timeIntervalSince(end)
        if freeFor < HitStore.longStretchThresholdSec {
            NextMilestoneCard(freeForSec: freeFor)
        }
    }
}
.id("first-milestone")
```

Notes:
- Use `HitStore.longStretchThresholdSec` (already exposed for the mode flip)
  as the upper bound; don't hardcode `86_400` here so any future threshold
  change ripples consistently.
- Place after `.id("charts-bottom")` and keep the existing 120pt bottom
  padding so the tab bar doesn't clip.
- The mode-flip `TimelineView(.periodic(by: 60))` wrapping the established
  branch already exists at the top of the dashboard (Issue 22); this inner
  card-level `TimelineView` is fine to stack — different time slices, both
  cheap.

### 2. `App/LongStretchView.swift`

`NextMilestoneCard` is already structured for reuse — `freeForSec` is the
only input and `driftMilestones[0]` is 1d, so a normal-mode call sites that
passes free-for under 24h gets exactly the "1 day, Xh to go" shape we want.
**No edits needed.**

If `NextMilestoneCard` ever stops being shared (e.g. the long-stretch version
grows extra chrome), lift the donut + label into a small `FirstMilestoneCard`
in `HomeView.swift` and keep the long-stretch version separate. Not needed
day one.

## Edge cases

- **No `lastSessionEnd`** (no hits yet, somehow past baseline): the
  `if let end = store.lastSessionEnd()` guards the render; nothing shows.
- **Free-for very large but still pre-baseline** (shouldn't happen, but
  defensively): the visibility gate checks `isBaselineEstablished` so the
  donut can't appear in baseline mode.
- **Just crossed 24h between ticks**: the home's own 60s mode-check
  `TimelineView` (Issue 22) re-evaluates the established branch and flips to
  long-stretch within a minute; the donut's own 60s tick is in sync.
- **`addPast` / `editHit`**: changing past data could shift `lastSessionEnd`
  forward or backward. The donut reads from the store live, so it just updates
  to match. No celebration fires (only `append` sets `endedLongStretch`; see
  Issue 22's relapse acknowledgment).
- **Sparkle perf**: this card adds one ring + one label; no particles. Fine
  against the DriftCard render budget (one `glassEffect`, no stacked fills).

## Files

- `app/Drift/Drift/App/HomeView.swift` — append the card after `charts-bottom`
- `app/Drift/Drift/App/LongStretchView.swift` — reused as-is for
  `NextMilestoneCard` (no edits unless the title copy needs to vary; see
  decision under "What it shows")

## Verification

1. Build + run with a seed that establishes baseline + leaves recent hits
   (`--seed longMonth` or live data); scroll to the bottom of home.
2. The donut card renders below "stretching the drift", reads "next milestone
   · 1 day · \(remaining) to go", and the ring fills to roughly
   `freeFor / 24h` of the circle.
3. Log a hit from the + tab. Donut empties to 0 within a beat (the existing
   `.easeOut(0.5)` on `NextMilestoneCard`); label updates to "1 day · ~24h to
   go".
4. Seed a last hit ~26h ago (via `AddHitSheet`'s `DatePicker`); within one 60s
   tick the home flips to long-stretch mode and the **bottom donut is gone**
   — replaced by the long-stretch hero + the long-stretch version of
   `NextMilestoneCard` higher on the screen.
5. Log a hit at "now" from long-stretch mode: the relapse acknowledgment fires
   (Issue 22), home returns to the normal dashboard, and the bottom donut
   reappears at 0.
6. Confirm the normal dashboard isn't re-rendering every second — only the
   inner `TimelineView(60)` ticks; `HomeView.equatable` short-circuits parent
   re-renders as before.
