---
status: done
priority: high
tags: [dashboard, spirit]
---

# Sparkle field

200-particle viewport-fill rendered in a SwiftUI Canvas. Source of truth: [[Spirit#Sparkles — viewport-fill halo]].

## Tasks

- [x] `SparkleField` view sized to fill its parent. Wrapped in a `GeometryReader` to anchor the Canvas at the screen size; `.ignoresSafeArea()` so sparkles can drift behind the status bar / home indicator.
- [x] 200 sparkles generated in `init` (via `State(initialValue:)` — `.onAppear` was racing the first Canvas tick and leaving the array empty on first paint). Fresh per-launch via `SystemRandomNumberGenerator`.
- [x] Each sparkle:
  - viewport-pct position (`xPct`, `yPct`)
  - `revealAt = 1 + (i/199)^1.5 * 19` after sorting by distance to spirit (78%, 14%) with vertical weighted 0.85× to avoid horizontal-only fills
  - size 6–10 normally, 10–16 18% of the time
  - drift amplitude (±15pt), driftDuration 4.5–9.5s, random phase
  - twinkleDuration 2.4–4s, random phase
  - color from a warm palette weighted toward coral/peach (the prototype's mostly-yellow palette blended into light blue too readily)
- [x] `Canvas` inside `TimelineView(.animation(minimumInterval: 1/60))` reads `currentRatio` per frame from `lastSessionEnd` + `wakingAvgSec`, skips sparkles where `ratio < revealAt`, otherwise draws a 4-point star at the drift-offset position with twinkle opacity (0.35–1.0)
- [x] Reduce Motion: full opacity, zero drift — sparkles still appear / disappear with ratio
- [ ] **Deferred polish:** smooth fade-in when a sparkle's `revealAt` is crossed (currently they pop in). Could track per-sparkle `wasVisible` and lerp; minor enhancement.

## Performance

200 active sparkles each computed per frame is fine on iPhone — Canvas is GPU-backed and these are cheap operations. If profiling shows issues, reduce frame rate (`.animation(.linear, value: ...)` with longer interval, or use `TimelineView(.periodic(by: 0.05))` for 20fps).

## Why a Canvas, not 200 SwiftUI Views

Way fewer view-tree updates and zero `.animation` overhead per particle. Same reason the prototype used SVG paths in a single `<svg>` rather than 200 divs.

## Reduce Motion

If `accessibilityReduceMotion`, render sparkles statically (full opacity, no drift, no twinkle) — they still appear/disappear with ratio.

## Out of scope

- Particle systems with physics (gravity, collisions)
- Tap to spawn extra sparkles
- Sparkle trails when the spirit moves
