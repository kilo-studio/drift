---
status: todo
priority: high
tags: [performance, spirit, sparkles]
---

# Sparkle performance

When the ratio is high enough that most of the field is revealed, the app starts chugging. The front + back sparkle pools plus `AmbientLayer` clouds/stars add up — somewhere around "fully revealed" we cross a threshold where frame pacing breaks down on real hardware.

[Issues/11 — Sparkle field](11%20%E2%80%94%20Sparkle%20field.md) already noted "If profiling shows issues, reduce frame rate" as a deferred mitigation. This is that issue, coming due.

## Two axes — do at least one, ideally both

**Cap the particle count.** Set a sensible ceiling for the on-screen total (front + back pool) so even fully revealed state doesn't push past what the device can comfortably render. Spec for the cap should be informed by profiling — pick a number that holds 60fps on the lowest-supported device and looks dense enough to still feel magical.

**Make the render cheaper per particle.** Possible directions, in rough effort order:
- Lower the `TimelineView` frame rate when the field is mostly revealed (e.g. drop to 30fps once `ratio > 8`). The eye can't track 60fps drift on 200+ tiny twinkling stars anyway.
- Replace the per-frame `currentRatio` recompute with a snapshot taken at TimelineView tick, threaded through the Canvas closure instead of read inside the per-particle loop.
- Pre-compute static per-particle values (color, base position, revealAt) at init and only animate the cheap parts (twinkle phase, drift offset).
- Try `Canvas(rendersAsynchronously: true)` to offload to a background thread.
- If we're still bound after all that, look at `MetalKit` / `CAEmitterLayer` for the heaviest scene.

## Acceptance

- Drop a hit so the field goes empty, then let it grow back. Stays smooth (no perceptible jank) end-to-end on a real device.
- Scrolling Home while the field is fully revealed stays smooth.
- The History tab (with its calendar donuts) still feels fine — sparkles aren't drowning siblings.

## Files

- `app/Drift/Drift/App/Spirit/SparkleField.swift` — main pool. 200 particles. Front + back layers wrap two instances.
- `app/Drift/Drift/App/Spirit/AmbientLayer.swift` — drifting clouds (light) / stars + dark cloud (dark). Independent of ratio.

## Profiling first

Before picking a fix, hook up Instruments → SwiftUI / Core Animation and capture a trace during the worst case. That'll tell us whether the bottleneck is Canvas redraw, view tree updates, blend mode cost, or something else. The cheapest fix that lands on the actual hot path beats guessing.

## Out of scope

- Removing sparkles entirely or making the field optional in settings — the sparkle field IS the celebration; it's not a feature to gate.
- Adding more sparkles. We're not increasing the count.
