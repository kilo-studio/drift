---
status: doing
priority: high
tags: [polish, dashboard, notifications]
---

# Baseline + empty state

Replaces the dashboard's empty state ("—" everywhere) with a guided "establish your baseline" period. Until the user has logged enough activity for the spirit to do meaningful work, the home screen surfaces a single donut showing progress toward the threshold, plus a small skip affordance for users who don't want to wait.

## The threshold

**5** — counts in the user's chosen unit (`useSessions` toggle from onboarding).

- `useSessions = true` → 5 sessions
- `useSessions = false` → 5 hits

5 is what gives the rolling average enough samples to read as "real."

## States

### Pre-baseline (default at first launch)

- **Tab bar**: Home, Settings, **+** (History hidden — nothing meaningful to show yet).
- **Home view**: replaces the dashboard with a single baseline card:
  - Cloud spirit at top in baseline-watching pose (its usual `lastSessionEnd` is nil → ratio defaults to 1.0; eyes neutral).
  - Below: a thick-stroke donut, count in the center (Caveat). Donut fills as count grows.
  - Copy: "Vape as you normally would and log them so we can establish a baseline."
  - When `count == 0`: secondary line pointing to the + tab — "tap **+** below to log your first hit."
  - "Skip" link at the bottom — small, secondary, ghost text.
- **Notifications**:
  - Immediate notif body says "X/5 baseline" (was "X/10").
  - Beat-average / beat-record notifications gated at 5 (was 10). Below 5: no scheduled notifications fire.

### Baseline crossed (count reaches 5 via real logs)

- One-time celebration moment: toast banner reading "now let's start drifting!" fades in and out.
- History tab appears in the bar.
- Home view transitions from baseline card → full dashboard.
- Notifications behave normally going forward.

### Baseline skipped (user tapped "Skip")

- Same effect as crossing — full dashboard, History tab appears, regular notification copy (no "/5 baseline").
- **No celebration animation/toast** — the user chose to bypass; we don't congratulate them for it.
- `drift.baseline.skipped = true` persists in UserDefaults.

## Reset behavior

`Settings → Reset all data` clears:

- All hits + records (existing behavior)
- `drift.onboarding.complete` flag (already in place)
- `drift.baseline.skipped` flag (new)

So a reset truly resets — the user re-runs onboarding and re-establishes baseline.

## Implementation notes

**State on HitStore**:
- `static let baselineTarget = 5`
- `baselineSkipped: Bool` (UserDefaults-backed, `didSet` mirrors)
- `baselineCount: Int` — computed: `useSessions ? hits.sessions(threshold: effectiveSessionThreshold).count : hits.count`
- `isBaselineEstablished: Bool` — computed: `baselineSkipped || baselineCount >= baselineTarget`

**NotificationScheduler**:
- Change the `totalHits >= 10` gate to `>= 5` for beat-average.
- Change the immediate-body "X/10 baseline" to "X/5 baseline" — and *only* show the baseline framing when `!ctx.baselineSkipped`. Skipped users get the normal copy from hit 1.

**Crossing detection**:
- HomeView's `.onChange(of: store.baselineCount)` fires the celebration when going from 4 → 5 *and* `!baselineSkipped`. Avoids triggering on skip.

**Conditional History tab in ContentView**: wrap the `Tab("history", …)` declaration in `if store.isBaselineEstablished { … }`. iOS 18+ TabView handles conditional tab children.

**Toast banner**: simple overlay on HomeView, auto-dismisses after ~3 seconds. Translucent material card with Caveat copy.

## Out of scope (for now)

- Sparkle burst at baseline crossing (toast alone is enough for v1; can revisit).
- Per-hit visualizations during baseline (just the donut count — keep the moment focused).
- Spirit animation change at crossing (the toast carries the moment).
