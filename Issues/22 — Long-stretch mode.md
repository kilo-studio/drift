---
status: done
priority: high
tags: [dashboard, spirit, philosophy, milestones]
---

# Long-stretch mode

A third home mode (after baseline → normal) that activates automatically once
"free for" reaches ~a day, and reframes the screen for someone who's gone a long
time without a hit. Born from noticing r/quitvaping posts that count "days
free" — the normal dashboard (averages, sessions/day, gaps between sessions) is
built for multiple-times-a-day use and goes stale/zero/empty past a day, while
the one metric that stays meaningful — the **"free for X"** timer — keeps
growing. Long-stretch mode makes that timer the whole stage.

## Trigger

`HitStore.longStretchThresholdSec = 24 * 3600`. Mode is derived live, not stored:
`isLongStretch = now − lastSessionEnd ≥ 24h`. The mode switch rides
`HomeView`'s coarse 60s `TimelineView` (cheap; entering/leaving long mode within
a minute is invisible at day-scale), but the long-stretch **card content** runs
on its own 1s `TimelineView` so the donut counts down and a milestone crossing
fires in sync with the hero — not up to a minute late. Logging a hit resets
free-for to ~0 and the mode falls away; nothing is "lost" (see philosophy below).

## What it shows

- **Hero** — big "free for X" in **days + hours** ("12d 6h"), grouped past the
  thousands ("1,825d"), with a "since MMM d, yyyy" start-date subtext. Weeks/
  months survive only as milestone labels, not the running number.
- **Next-milestone donut** (full-width card) — a progress ring filling across the
  current interval (last passed → next marker), centered on the next milestone
  with a live "Nd Xh to go". Disappears once every milestone is reached.
- **Milestones reached** — a 2-column grid of "blob" badges (see below) for the
  milestones hit *this stretch*, growing as you drift further.
- Frequency cards/charts are hidden (meaningless here). The longest-drift record
  moved to History → Records (it was redundant with the live timer on home).

## Milestone badges

Markers: 1d, 3d, 1wk, 2wk, 1mo, 2mo, 3mo, 6mo, 1y. Magnitude is encoded **three
ways** so every badge stays distinct (a single growing count converges to a
circle — 8 vs 9 sides is unreadable):

- **Star points** — primary, fine-grained: `5 + index`, one more spike per
  milestone, so the longest badge has the most points.
- **Concentric tier rings** — coarse, instantly countable: days 0 / weeks 1 /
  months 2 / year 3 inset outlines.
- **Deepening green** — sage → forest across the range.

Label stacks the number over the cadence ("1" / "week"). On a real crossing the
new badge **springs in** with a sparkle burst (`onChange(of: reachedCount)`, so
it never fires on initial load). `MilestoneBadgeGrid` + `milestonesReached(upTo:)`
are shared by the home card and the History records sheet so they can't drift.

## History → Records

A "records" card above the calendar opens a sheet with the all-time **longest
drift** (with dates, current-drift-aware — reads "MMM d → now" when you're on
your best run) and the same badge grid for every milestone ever reached
(derived from `max(stored record, current drift)` — no extra persistence). The
History calendar's month nav now **skips empty months** (jumps between months
with data + the current month) so a long drift doesn't mean tapping back through
dozens of blank months.

## Spirit + sparkles

Both the spirit's eye-ratio and the sparkle reveal divide time-since-last by the
rolling waking average — which is **nil** during a long stretch (no hits in the
window), so both collapsed to a neutral 1.0: the spirit went baseline-eyed
mid-celebration and the field stayed bare. Fixed by falling back to the longest
waking gap (or 30 min) when the rolling average is unavailable, so the ratio
keeps scaling and the spirit stays maxed-happy + the field fills. The spirit
stays *monotonically* happy through the whole drift (no per-milestone reset —
deflating after an achievement would be a downbeat); the per-milestone moment is
the badge spring-in instead.

## Philosophy — why this isn't a streak/achievement system

The achievement system was deliberately removed ([[Issues/15 — Achievement system]]):
it duplicated the spirit and carried an "earn this badge" tone. Long-stretch
milestones avoid both traps:

- **Not redundant with the spirit** — the spirit maxes within a day and can't
  express "1 week" vs "1 month"; long-duration milestones add real information.
- **Split into live vs durable.** Home milestones are *live visualization* of
  the current stretch — on relapse you simply leave the mode, nothing is
  shamefully erased. The durable, never-reset record lives in History → Records.
  A streak describes *you*; this describes *time* (see [[Design/Philosophy]]).

No "quit" language, no resetting counters in your face, no badge shelf to lose.

## Files

`App/LongStretchView.swift` (new — hero, donut, badges, blob/star shapes, burst),
`App/HomeView.swift` (third mode branch), `ContentView.swift`,
`Data/HitStore.swift` (`longStretchThresholdSec`, `longestGapBounds`, debug
seeds), `App/HistoryView.swift` (records sheet + calendar skip), `App/Format.swift`
(day+hours, grouping, human duration), `App/Spirit/SpiritView.swift` +
`SparkleField.swift` (nil-avg fallback).

## Debug tooling

DEBUG-only seed scenarios (Settings → tap the title 7× to reveal; confirm before
seeding since it wipes data) and `--seed <scenario>` / `--relapse` / `--records`
launch args, including a "~30s before 1 week" seed to watch a crossing live.

## Follow-ups

- [[Issues/18 — Sparkle performance]] is now hit constantly: long-stretch keeps
  the full field revealed the whole time. The milestone burst is also subtle
  against the full field.
- Optional: a distinct one-time flourish for the *final* milestone; warming/gold
  palette for the longest badges; tap-verify the calendar month-skip on device.
