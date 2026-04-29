---
status: done
priority: medium
tags: [dashboard]
---

# Stat cards and charts

Three stat cards plus four charts, all native using SwiftUI Charts. Labels and data sources updated for Issue 16's session model.

## Stat cards

- [x] `StatCard` — Caveat title, big Quicksand stat number (color-tagged), small label below. `lineLimit(1) + minimumScaleFactor(0.7)` keeps long titles centered when card width is tight.
- [x] `sessions today` card — number = `todaySessionCount`, coral, label = "X hits" (today's hit count as the secondary intensity readout per Issue 16)
- [x] `average` card — number = `avgSessionsPerDay`, sage-deep, label = "sessions per day · 30d"
- [x] `waking gap` card — number = `formatGap(wakingAvgSec)`, sage-deep, label = "average between sessions · 30d"
- [x] `today` and `average` side-by-side, `waking gap` full width below
- [x] `ChartEmptyState` for charts with no data (Charts framework crashes computing axes over empty domains)

## Charts

All four built with `import Charts`, wrapped in a shared `ChartCard` (centered Caveat title, smaller subtitle, then plot). Y-axis on the leading edge, soft grid lines, `driftSub`/`driftInkSoft` for axis labels.

- [x] **today's stretches** — line + filled coral gradient over `todayStretches()`
- [x] **the last fortnight** — `dailySessionCounts(lastN: 14)`. Today coral, past peach. Two-color gradient (top → opacity 0.7 at bottom) avoids the default elevation drop-shadow that Charts on iOS 26 paints behind solid-Color bars.
- [x] **when the cravings hit** — `sessionsByHour()`, sage→sage-deep gradient bars, custom hour labels (12a, 6a, noon, 6p)
- [x] **stretching the gaps** — line + filled sage gradient over `rollingAvg(window: 7, lastN: 30)`

## Visual iteration

- Outer background simplified to solid `driftSkyLowerMid` (decorative sky/sun-haze gradients explored and removed — see commit history)
- Card surface dropped from 0.75 → 0.4 opacity on `.thinMaterial` for more glass-like translucency
- Card shadow opacity halved (0.18 → 0.08 and 0.08 → 0.04) for a softer feel
- Bests row labels + timer unit suffix bumped from `driftInkFade` → `driftInkSoft` for readability

## Card structure

```
┌────────────────────────────┐
│       (centered title)     │
│      (centered subtitle)   │
│                            │
│      [chart or content]    │
│                            │
└────────────────────────────┘
```

Subtitles always sit between title and content. No subtitle below charts.

## Out of scope

- Tap-to-zoom on charts
- Date range picker
- Export chart as image
