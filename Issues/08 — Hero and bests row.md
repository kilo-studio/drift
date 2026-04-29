---
status: todo
priority: medium
tags: [dashboard]
---

# Hero and bests row

The top of the dashboard. Source of truth: [[Design system]].

## Tasks

- [ ] `HeroView` — vertical stack: hero label "free for" (Caveat 26px), big timer, bests row
- [ ] Live timer driven by `TimelineView(.periodic(from: ..., by: 1.0))` — updates every second
- [ ] `formatElapsed(ms)` utility — `Xs` / `Xm` / `Xh Ym`
- [ ] Timer styling: Quicksand 600 / 80px / `letter-spacing: -1.5px`
- [ ] Unit suffix (`m`, `s`, `h`) — Quicksand 300 / 32px / muted color, smaller than the number
- [ ] Bests row: two-column flex, 36px gap. Each column = number on top (Quicksand 600 / 22px), label below (Caveat 16px / muted)
- [ ] Wire milestone glows: peach text-shadow on the timer + waking best when `ratio >= longestWakingGap_ratio`; gold animated glow when `ratio >= longestGap_ratio`. Source: [[Spirit#Milestones — not levels, but real moments]]
- [ ] Smooth transitions in/out of milestone state (1.6s ease)

## Animations

- Float speedup at waking milestone (5s → 3.6s) is on the spirit, not the timer
- The timer/best-num glows fade in over 1.6s, no scaling

## Out of scope

- Scrubbing the timer (slider to preview different ratios) — that's the debug-only feature, omit from production
- "Best of N hits" type stats — keep it to longest waking + longest overall
