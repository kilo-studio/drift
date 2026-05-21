---
status: done
priority: medium
tags: [dashboard]
---

# Hero and bests row

The top of the dashboard. Source of truth: [Design system](../Design/Design%20system.md).

## Tasks

- [x] `HeroView` — "free for" label, big timer, bests row
- [x] Live timer via `TimelineView(.periodic(from: .now, by: 1))`
- [x] `formatElapsed` utility (number + unit) and `formatGap` (compact string for bests)
- [x] Timer: `driftDisplay` (Quicksand 600 / 80) with `tracking(-1.5)`
- [x] Unit suffix: `driftTimerUnit` (Quicksand Light / 32) on `.driftInkFade`
- [x] Bests row: two columns, 36 spacing. `driftBestNum` (22) on top, `driftBestLabel` (Caveat 16) below
- [x] `Text.caveat(_:)` generalized from the old `driftCardTitle` helper so all Caveat-rendered text gets the swash-padding fix
- [x] HitStore wired into the app via `@Environment` — `DriftApp` constructs the `ModelContainer` and `HitStore`, exposes the store
- [x] Debug `+` floating button (`#if DEBUG` only) appends a hit so we can populate data before Issue 06 lands
- [ ] **Deferred to Issue 14:** milestone glows (peach text-shadow at waking ratio, animated gold at overall ratio) and 1.6s ease transitions — these need spirit ratio + the milestone state from Issue 10

## Animations

- Float speedup at waking milestone (5s → 3.6s) is on the spirit, not the timer
- The timer/best-num glows fade in over 1.6s, no scaling

## Out of scope

- Scrubbing the timer (slider to preview different ratios) — that's the debug-only feature, omit from production
- "Best of N hits" type stats — keep it to longest waking + longest overall
