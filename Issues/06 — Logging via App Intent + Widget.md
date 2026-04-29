---
status: todo
priority: high
tags: [logging]
---

# Logging via App Intent + Widget

The most important interaction in the app: log a hit fast, from anywhere, without opening Drift.

## App Intent

- [ ] `LogHitIntent: AppIntent` with `static var openAppWhenRun = false`
- [ ] Returns `IntentResult` with a dialog: `"Logged. Xm since last hit · avg Ym"` (or baseline message)
- [ ] Donates the intent so Siri suggests it
- [ ] Test surfaces: Shortcuts, Action Button, Lock Screen widget, Control Center (iOS 18+), Spotlight

## Home Screen widget

- [ ] Small widget with a tap target that runs `LogHitIntent`
- [ ] Display: time since last hit, optionally a tiny spirit (static, not animated — widgets can't animate)
- [ ] Configurable via `WidgetConfigurationIntent` if we want different display modes
- [ ] Refresh policy: every 5 min while in active timeline; the widget shows time since last hit so it has to refresh

## Lock Screen / StandBy widget

- [ ] Circular and rectangular complications for Lock Screen
- [ ] Inline complication with just the timer

## Edge cases

- Logging while a previous hit's notification is queued: cancel + reschedule (see [[Issues/07 — Notifications|Notifications issue]])
- Logging twice within 5 seconds: still log both (no debouncing — the user might genuinely take two hits in quick succession; it's their data)
- Offline: no problem, all local

## Out of scope

- Trigger tagging (log a hit + a context label like "stress" / "social") — v1.1
