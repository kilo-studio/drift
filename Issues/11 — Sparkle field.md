---
status: todo
priority: high
tags: [dashboard, spirit]
---

# Sparkle field

200-particle viewport-fill rendered in a SwiftUI Canvas. Source of truth: [[Spirit#Sparkles — viewport-fill halo]].

## Tasks

- [ ] `SparkleField` view: sized to fill its parent (likely the dashboard background layer)
- [ ] On first appear, generate 200 sparkles deterministically (or with a stable seed) — *but* with a fresh per-launch random rotation/jitter so the halo isn't identical every time
- [ ] Each sparkle has:
  - Position in viewport-percentage coords (`x: 0..100`, `y: 0..100`)
  - `revealAt` threshold computed from sorted-by-distance index using `1 + pow(i/199, 1.5) * 19`
  - Size (mostly 6–10pt, occasionally 10–16pt)
  - Drift offset (`dx`, `dy`, ±18pt) and drift duration (4.5–9.5s)
  - Twinkle duration (2.4–4s) and phase
  - Color from a small warm palette (`#E8B86B`, `#F0C57C`, `#FFD08C`, `#E8836B`, `#F4D88B`)
- [ ] `Canvas { context, size, currentTime in ... }` driven by `TimelineView(.animation)`:
  - For each sparkle: skip if `ratio < revealAt` (cull culling so we don't pay for hidden ones)
  - Compute drift offset from sin of `(currentTime + phase) * (2π / driftDuration)`
  - Compute opacity from sin of `(currentTime + twinklePhase) * (2π / twinkleDuration)` mapped to 0.35–1
  - Draw a 4-point star path at `(x, y) + driftOffset` filled with the sparkle's color
- [ ] Pass current `ratio` in via the view model so reveal updates as time progresses
- [ ] Smooth opacity fade-in when a sparkle's `revealAt` is crossed (track per-sparkle `wasVisible`, lerp opacity over ~1.4s)

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
