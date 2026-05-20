# Architecture

## Stack

- **SwiftUI** for all UI
- **SwiftData** for the on-device store (Hit entity, computed metrics)
- **CloudKit** for opt-in sync (off by default)
- **App Intents** for "Log a hit" — surfaces in Shortcuts, Action Button, Lock Screen, Control Center
- **WidgetKit** for the Home Screen widget (tap to log)
- **UserNotifications** (`UNUserNotificationCenter`) for the immediate + scheduled notifications
- **Charts** (Apple's Charts framework) for the four chart cards
- **SwiftUI Canvas + TimelineView** for the spirit character and 200-particle sparkle field

Minimum target: **iOS 26**. We get unrestricted access to the latest Charts, App Intents, Observation, SwiftData, `onScrollGeometryChange`, and the cloud/sparkle Canvas APIs without any availability gating.

## App shape

```
DriftApp (entry)
├── ContentView
│   └── DashboardView                  ← single scroll view, top to bottom
│       ├── SkySpiritView              ← background gradient + drifting clouds + spirit + sparkles
│       │   ├── HeroView               ← "free for X" timer + bests row, on top of sky
│       │   ├── SpiritView             ← Canvas-rendered cloud character
│       │   └── SparkleField           ← Canvas-rendered 200-particle field
│       ├── StatCardsView              ← today / average / waking gap
│       └── ChartsView                 ← four charts
└── LogHitIntent (App Intent)          ← logging entry point
    └── HitStore.append(now)
```

`HitStore` is the singleton SwiftData wrapper. All reads/writes go through it. Computed properties (`todayCount`, `avgPerDay`, `wakingAvgSec`, `longestWakingGap`, `longestGap`, `lastHitMs`) are derived from the live `[Hit]` array and update reactively.

## Native vs WebView for the spirit

Three options considered:

1. **Full native (SwiftUI Canvas + TimelineView)** — re-implements the SVG cloud body, eyes, sparkle field, and continuous animations in SwiftUI. Most work; best portfolio outcome; lets the system optimize rendering and respect Reduce Motion.

2. **WebView wrapper** — embed the existing HTML+CSS+JS spirit/sparkle layer in a `WKWebView` and pipe `ratio` updates in via JS bridge. Very fast to ship; reads as a hack in the case study; can't easily participate in SwiftUI animation context.

3. **Hybrid** — native dashboard shell, WebView only for the spirit/sparkle layer. Loses the "fully native" portfolio claim.

**Decision: full native.** The spirit is the visual centerpiece — implementing it properly in SwiftUI is the main portfolio-distinguishing piece of engineering. Budget time for it.

The sparkle field is straightforward in SwiftUI Canvas — 200 particles updated via TimelineView, drift via a sin/cos offset on each particle's per-particle phase. The eye scaling and `cy` anchoring is just driven by `ratio` passed down from the view model.

## Data flow

```
LogHitIntent → HitStore.append(now)
                 ↓
              SwiftData persists, [Hit] published
                 ↓
              Computed metrics recompute (avgPerDay, wakingAvgSec, etc.)
                 ↓
              Views observe and re-render
                 ↓
NotificationScheduler.rescheduleAll(metrics)  ← cancels + re-schedules
```

`HitStore` exposes:
- `lastHit: Hit?` (for `lastHitMs` in the timer)
- `todayCount: Int`
- `avgPerDay: Double` (rolling window from settings, default 7 days, excludes today)
- `wakingAvgSec: TimeInterval?` (rolling window from settings, default 7 days, includes today)
- `longestWakingGap: TimeInterval`
- `longestGap: TimeInterval`
- `hitsByHour: [Int]` (24 buckets, all-time)
- `dailyCounts(lastN: Int)`
- `todayStretches: [(Date, TimeInterval)]`
- `rollingAvg(window: 7, lastN: 30)`

All derived. See [[Data model]] for the exact computations.

## Sync (CloudKit)

Off by default. Toggle in settings. When on:
- Use SwiftData's CloudKit integration (no manual zone management)
- Conflict policy: last-writer-wins on the Hit array (extremely unlikely to conflict — single user, single set of timestamps)
- Don't sync derived metrics; recompute everywhere

## App Intent for logging

`LogHitIntent: AppIntent` with `static var openAppWhenRun = false`. Returns `.result(dialog: "Logged. \(formatted) since last hit · avg \(avgFormatted)")` so the Shortcuts UI shows the same vibe as the Scriptable notification.

Lock Screen widget: configurable `LogHitButton` widget. iOS 17+ supports interactive widgets via App Intents.

Control Center entry (iOS 18+): a control that runs the same App Intent.

## Notifications

`NotificationScheduler` reschedules on every hit. See [[Notifications]] for full logic. Same identifiers as the Scriptable version (`drift-beat-average`, `drift-beat-record`) so multiple in-flight notifications get cancelled/replaced cleanly.

## Settings (small, focused)

Implemented in `SettingsView.swift` as a fourth `TabView` tab. See [[Issues/12 — Onboarding, settings, app icon|Issue 12]] for the full per-row spec and current status.

- **Use sessions** — toggle, default on (Issue 16's master switch; routes metrics through `effectiveSessionThreshold`)
- **Session threshold** — picker, 1 / 3 / 5 / 10 / 15 / 30 min, default 5 (hidden when use-sessions is off)
- **Rolling window** — picker, 7 / 14 / 30 / 60 days, default 7
- **Sleep window** — two hour pickers (bedtime + wake up), default 23 and 6; drives waking-day cutoff and notification hedge
- **Notifications** — master toggle + per-type toggles (immediate / beat-average / beat-record) + timing offset pickers (right-at / +1 / +5 / +10 / +15 min)
- **Reset all data** — destructive, confirms via alert, calls `HitStore.resetEverything()`
- **About** — version, privacy policy link, github link
- *(Pending)* **Sync iCloud** — toggle, off by default
- **Reduce motion** — automatically respects iOS setting (no per-app toggle needed)

No accent color picker, no theme variants. The Ghibli sky is the design.
