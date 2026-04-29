---
status: todo
priority: high
tags: [dashboard, spirit]
---

# Spirit character

Native SwiftUI Canvas implementation of the cloud spirit. Source of truth: [[Spirit]].

## Tasks

- [ ] `SpiritView` — sized 96×96, sits at top of dashboard with 36px top padding inside its wrapper
- [ ] `Canvas { context, size in ... }` rendering:
  - [ ] Cloud body: filled ellipse with a radial gradient (white → cream → soft tan)
  - [ ] Soft side wisps (two smaller ellipses on either side)
  - [ ] Cheeks: two peach ellipses, opacity 0.45 baseline (0.7 at waking, 0.85 + coral fill at overall)
  - [ ] Eyes: two `eye-pupil` circles with `eye-shine` highlights inside; cy and r driven by `ratio` per [[Spirit#Eyes — bottom-anchored growth]]
  - [ ] Smile: small soft path
- [ ] Float animation: bob up/down, gentle rotation. Use `TimelineView(.animation)` driving a phase variable, then offset/rotate
- [ ] Blink: every ~6.5s, scale eye groups vertically to ~0.12 for a single frame. Synced both eyes (slight 0.04s offset on right)
- [ ] Milestone state: switch float keyframes when `wakingActive` / `overallActive` (faster + bigger amplitude on waking, wobbly+scale-pulse on overall)
- [ ] Drop-shadow halo at overall milestone (gold glow)
- [ ] Respect Reduce Motion (no float, no blink — just static eyes)

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
