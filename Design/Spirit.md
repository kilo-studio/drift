# The spirit

The cloud character at the top of the dashboard. Its appearance is fully driven by **one input**: the ratio of time-since-last-hit to the rolling-30-day waking-gap average.

```
ratio = ms / avgMs
```

Below 1 you're under your typical gap; at 1 you've matched it; above 1 you're past it. Everything visual derives continuously from this number. No discrete levels — the joy ladder we tried in the prototype was abandoned because levels create plateaus and don't read as smooth growth. See [[Issues]] for the iteration history.

## What scales

### Eyes — bottom-anchored growth

The pupils start at radius 2.4 and grow logarithmically:

```
pupil_r  = clamp(2.4 + ln(ratio) * 2.5, 2.4, 8)
pupil_cy = 52.9 - pupil_r
```

The bottom of each pupil stays anchored at y=52.9 in the spirit's viewBox. As `r` grows, `cy` shrinks — the eye scales *upward toward the forehead*, never downward toward the smile. This was a deliberate constraint after early versions had the eyes overlapping the mouth at higher ratios.

Cap at r=8 because that's where the two pupils (cx 42 and 58) just touch. Past that they'd merge.

The shine (small bright dot inside each pupil) scales proportionally:
```
shine_r  = pupil_r * 0.27
shine_cy = 52.9 - pupil_r * 1.375
```

At ratio 4× the eyes are r≈5.9 (≈ 2.5× baseline). At ratio 10× they're at the cap. The growth is aggressive on purpose — early versions felt meh at 4× because the user had no reason to feel rewarded yet.

### Sparkles — viewport-fill halo

200 sparkles are generated once on page load, distributed across the entire viewport in randomized positions. Each is sorted by distance from the spirit's perceived top-center position and assigned a `revealAt` threshold along a power curve:

```
revealAt[i] = 1 + (i / 199)^1.5 * 19
```

So the closest sparkles unlock around ratio 1× (just past your average) and the farthest unlock around ratio 20× (extreme territory). At max, the screen is genuinely covered.

Each sparkle has its own random:
- size (mostly 6–10px, occasionally 10–16px)
- position (Vogel/halton-like distribution + jitter, with a fresh per-load rotation so the halo orientation differs every render)
- drift offset and duration (4.5–9.5s, ±18px)
- twinkle (opacity oscillation) duration and delay (negative delay seeds them mid-cycle so they don't pulse in sync)

Drift uses `transform: translate(...)` only — never `scale` — to avoid WebKit's CSS-vs-SVG-attribute transform conflict that previously caused sparkles to collapse to (0,0) of the viewBox during animation.

## Milestones — not levels, but real moments

Two thresholds get a sustained "you're here" treatment when the *current* gap exceeds them:

### Longest waking — warm

When `ms ≥ longestWakingGap`:
- Spirit's float speeds up `5s → 3.6s` and amplitude grows `-6px → -10px`
- Spirit's cheeks deepen from opacity 0.45 → 0.7
- Timer gets a soft peach text-shadow glow
- The "longest waking" record number gets a peach text-shadow glow

### Longest overall — gold (additive on top of waking)

When `ms ≥ longestGap`:
- Spirit's float swaps to a 4-keyframe wobble with subtle scale pulses (3.0s)
- Soft golden drop-shadow halo on the spirit
- Spirit's cheeks deepen further to 0.85 and shift to coral fill
- Timer gets a stronger gold text-shadow glow
- The "longest overall" record number gets an animated breathing gold glow

### Why glows, not color changes

Earlier versions changed the timer and best-record colors to peach/gold. On the cream background those colors had terrible contrast and the icons (✿/☾) effectively disappeared. The fix was leaving text colors at their normal high-contrast `--ink` and putting the warmth in `text-shadow` halos instead. The numbers stay crisp; the warmth surrounds them.

## Background

A soft sky-blue gradient (`#7FA7BD` at top fading through `#A8C6D5` to `#DCE5DA` at bottom) with a faint warm sun-haze overlay at the very top (vertical linear that fades from peach `0.45` alpha at 0% to fully transparent by 25% down). Two large drifting cloud SVGs animated with `position: fixed` so they parallax-anchor as you scroll.

## What the spirit doesn't do

Earlier iterations had: friends (cloud companions, soot sprite), rainbow arcs, confetti, party hat, multiple flower crowns, sleepy-eyes/happy-eyes alternative states, thought-bubble text, scaling sun glow behind the spirit. All removed. The spirit is more honest with less.
