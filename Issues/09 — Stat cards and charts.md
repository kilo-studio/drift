---
status: todo
priority: medium
tags: [dashboard]
---

# Stat cards and charts

Three stat cards plus four charts, all native using SwiftUI Charts.

## Stat cards

- [ ] `StatCard` view: title (Caveat 24, centered), big number (Quicksand 600 / 52px, color-tagged), label (13px / muted, e.g. "hits", "hits per day · 30d", "average between hits · 30d")
- [ ] `today` card: number = `todayCount`, color = coral, label = "hit" or "hits"
- [ ] `average` card: number = `avgPerDayStr`, color = sage-deep, label = "hits per day · 30d"
- [ ] `waking gap` card: number = `wakingAvgStr`, color = sage-deep, label = "average between hits · 30d"
- [ ] `today` and `average` side by side; `waking gap` full width below

## Charts

All Apple Charts framework (`import Charts`). Card wrap each.

### today's stretches (line chart)
- Title: "today's stretches"
- Subtitle (right under title): "minutes between hits today"
- Data: `todayStretches()` — one point per gap, x = clock time of the later hit, y = minutes
- Coral line + filled gradient

### the last fortnight (bar chart)
- Title: "the last fortnight"
- Subtitle: "hits per day · last 14 days"
- Data: 14 daily counts
- Today's bar = coral, others = peach
- **Rounded top, flat bottom**, 8px corner radius

### when the cravings hit (bar chart)
- Title: "when the cravings hit"
- Subtitle: "hits by hour of day"
- Data: 24 hourly counts (all-time)
- Sage gradient bars, 4px rounded top, flat bottom
- X-axis labels: 12a, 6a, noon, 6p, 12a

### stretching the gaps (line chart)
- Title: "stretching the gaps"
- Subtitle: "7-day rolling average · minutes between hits"
- Data: `rollingAvg(window: 7, lastN: 30)`
- Sage line + filled gradient

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
