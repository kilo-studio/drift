---
status: done
priority: high
tags: [dashboard, spirit]
---

# Spirit character

Native SwiftUI Canvas implementation of the cloud spirit. Source of truth: [Spirit](../Design/Spirit.md).

## Tasks

- [x] `SpiritView` — sized 96×96, lives at top of dashboard with 36pt top padding
- [x] `Canvas` rendering inside a `TimelineView(.animation)` — frame-perfect updates:
  - [x] Cloud body — radial gradient (white → cream → soft tan) on an ellipse at (50,52) rx=34 ry=30
  - [x] Soft side wisps — two smaller ellipses at x=14 and x=86 with the same gradient at 0.7 opacity
  - [x] Cheeks — peach ellipses; opacity 0.45 baseline → 0.7 at waking → 0.85 with coral fill at overall
  - [x] Eyes — pupils + cream shine; `pupilR = clamp(2.4 + ln(ratio) * 2.5, 2.4, 8)`, bottom-anchored at y=52.9 so growth is upward only
  - [x] Smile — soft quad-curve path from (47.5, 58.5) to (52.5, 58.5)
- [x] Float animation — sin-driven bob in viewBox units; default ±3 over 5s, waking ±5 over 3.6s, overall ±4 over 3.0s
- [x] Blink — every 6.5s, pupils render as a flat ellipse (`ry = pupilR * 0.12`) for ~100ms, shines hidden during the blink. Right eye offset by 0.04s
- [x] Milestone state — float keyframes + cheek opacity/color all gated on `wakingActive` / `overallActive`
- [x] Reduce Motion — no float, no blink; eyes still scale (ratio is data, not motion)
- [ ] **Deferred:** drop-shadow halo at overall milestone (gold glow). Pair with the Hero's glows in Issue 14.

## Why Canvas, not Shape composition

Could be done as composed SwiftUI Shapes but Canvas is more performant for the parallel sparkle field, and keeping the spirit on the same render path simplifies things. Plus `TimelineView(.animation)` gives a clean per-frame hook for the continuous animations.

## Eye scaling formulas

```swift
let lr = log(max(0.001, ratio))
let pupilR  = min(8, max(2.4, 2.4 + lr * 2.5))
let pupilCy = 52.9 - pupilR
let shineR  = pupilR * 0.27
let shineCy = 52.9 - pupilR * 1.375
```

ViewBox is 0..100. The Canvas draws at the same proportional coords.

## Out of scope

- Multiple spirit "outfits" or seasonal variants
- Tappable spirit (no interaction; it's display-only)
