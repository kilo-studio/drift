---
status: done
priority: high
tags: [logging]
---

# Logging via App Intent + Widget

The most important interaction in the app: log a hit fast, from anywhere, without opening Drift.

> **v1 scope done.** Phases A + B shipped (App Intent + AppShortcuts surface, App Group + WidgetBridge, display-only widget). **Phase C — silent tap-to-log from the widget — is deferred post-v1** (needs `LogHitIntent` shared with the widget target); not a v1 blocker.

## App Intent

- [x] `LogHitIntent: AppIntent` defined. Phase A ships with `openAppWhenRun = true` — opens Drift on run so the intent reuses the app's `ModelContainer`.
- [x] Returns `IntentResult & ProvidesDialog` with dialog: "First steps logged. X/10 baseline." for the first 10 hits, then "Logged. Xm since last hit · avg Ym."
- [x] `DriftAppShortcuts: AppShortcutsProvider` surfaces the intent to Spotlight/Siri without manual Shortcuts setup
- [x] DriftApp's `ModelContainer` promoted to a static so the intent can construct its own `HitStore` against the same store
- [ ] **Phase B:** flip to `openAppWhenRun = false` once App Group + shared SwiftData is wired through (so widget taps log silently)

## Home Screen widget

- [x] App Group `group.studio.kilo.drift` entitled on both `Drift` and `DriftWidgetExtension` targets
- [x] `WidgetBridge` mirrors `lastHit` / `wakingAvgSec` / `longestWakingGapSec` / `longestGapSec` into App Group UserDefaults from `HitStore.append` (and on init); widget reads the same keys (file duplicated into the widget target — synchronized groups don't share files cleanly)
- [x] `DriftProvider` returns 6 entries every 5 minutes; `getTimeline` re-reads the bridge each refresh
- [x] `DriftWidgetEntryView` shows "free for X{m,s,h}" using the same format helper as the hero, plus a "tap to log" hint. systemSmall family.
- [x] Widget tap defaults to opening the app (no Button(intent:) yet — that needs a shared `LogHitIntent` definition)
- [ ] **Phase C — silent tap-to-log:** share `LogHitIntent.swift` across both targets (Swift Package or pbxproj exception trick), then wire `Button(intent: LogHitIntent())` so the widget logs without launching the app
- [ ] **Phase C — optional tiny static spirit** alongside the timer
- [ ] `WidgetConfigurationIntent` for display modes — defer; not needed for v1

## Lock Screen / StandBy widget

- [ ] Circular and rectangular complications for Lock Screen
- [ ] Inline complication with just the timer

## Edge cases

- Logging while a previous hit's notification is queued: cancel + reschedule (see [Notifications issue](07%20%E2%80%94%20Notifications.md))
- Logging twice within 5 seconds: still log both (no debouncing — the user might genuinely take two hits in quick succession; it's their data)
- Offline: no problem, all local

## Out of scope

- Trigger tagging (log a hit + a context label like "stress" / "social") — v1.1
