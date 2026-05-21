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
- [x] `avg / day` card — number = `avgSessionsPerDay`, sage-deep, label = "X hits"
- [x] `today's avg` card — number = `formatGap(todayWakingAvgSec)`, sage-deep, label = "between sessions"
- [x] `7-day avg` card — number = `formatGap(wakingAvgSec)`, sage-deep, label = "between sessions"
- [x] Cards laid out as two HStacks: `sessions today | avg / day`, then `today's avg | 7-day avg`
- [x] Window length is configurable in settings (default 7) — the "7-day avg" title will read from the same source when the picker lands; for now the title hard-codes "7-day"
- [x] `ChartEmptyState` for charts with no data (Charts framework crashes computing axes over empty domains)

## Charts

All four built with `import Charts`, wrapped in a shared `ChartCard` (centered Caveat title, smaller subtitle, then plot). Y-axis on the leading edge, soft grid lines, `driftSub`/`driftInkSoft` for axis labels.

- [x] **today's stretches** — line + filled coral gradient over `todayStretches()`
- [x] **the last fortnight** — `dailySessionCounts(lastN: 14)`. Today coral, past peach. Two-color gradient (top → opacity 0.7 at bottom) avoids the default elevation drop-shadow that Charts on iOS 26 paints behind solid-Color bars.
- [x] **when the cravings hit** — `sessionsByHour()`, sage→sage-deep gradient bars, custom hour labels (12a, 6a, noon, 6p)
- [x] **stretching the gaps** — line + filled sage gradient over `rollingAvg(window: 7, lastN: 30)`

## Visual iteration

- Outer background simplified to solid `driftSkyLowerMid` (decorative sky/sun-haze gradients explored and removed — see commit history)
- Card chrome moved to iOS 26 Liquid Glass: `.glassEffect(.regular.tint(.driftSkyLowerMid.opacity(0.4)), in: RoundedRectangle(...))`. One render pass per card; tint pulls cards toward the sky color so they feel like a lifted region of the bg. Earlier `.ultraThinMaterial` stack (material + tint fill + stroke + 2 shadows = 5 passes per card) was stripped after Instruments measured 170–370 offscreen passes per frame on Home and made scrolling hitchy. See [Card render budget](#card-render-budget) below.
- Bests row labels + timer unit suffix bumped from `driftInkFade` → `driftInkSoft` for readability

## Card render budget

The dashboard runs continuous `TimelineView(.animation)` for the spirit, sparkle field, and ambient cloud/star layer. Anything that adds an offscreen pass to a card multiplies across ~10 cards × 120Hz refresh, fast.

Rules:

- **One `.glassEffect(...)` per card. No layered fills, materials, or shadows on top.** Liquid Glass composes blur + tint in a single render pass; stacking `.background(...)` or `.shadow(...)` on top adds offscreen passes that compound across the dashboard.
- **No `.shadow()` on cards.** Even at near-zero alpha, shadow is a gaussian-blurred offscreen pass.
- **Tint by passing `.tint(...)` to the Glass type, not by stacking a fill above it.** That's the whole reason Liquid Glass is structurally cheaper than `.ultraThinMaterial + custom tint`.
- If a card needs more visual depth, get it from the bg gradient, the tint color/opacity, or the Glass variant (`.regular` vs `.clear`) — not from an additional modifier.

`Instruments → Animation Hitches` is the canonical way to verify. The "Potentially expensive render, N offscreen passes" hint in the Hitches detail tells you exactly when this rule has been broken.

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
