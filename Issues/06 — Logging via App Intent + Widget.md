---
status: doing
priority: high
tags: [logging]
---

# Logging via App Intent + Widget

The most important interaction in the app: log a hit fast, from anywhere, without opening Drift.

## App Intent

- [x] `LogHitIntent: AppIntent` defined. Phase A ships with `openAppWhenRun = true` — opens Drift on run so the intent reuses the app's `ModelContainer`.
- [x] Returns `IntentResult & ProvidesDialog` with dialog: "First steps logged. X/10 baseline." for the first 10 hits, then "Logged. Xm since last hit · avg Ym."
- [x] `DriftAppShortcuts: AppShortcutsProvider` surfaces the intent to Spotlight/Siri without manual Shortcuts setup
- [x] DriftApp's `ModelContainer` promoted to a static so the intent can construct its own `HitStore` against the same store
- [ ] **Phase B:** flip to `openAppWhenRun = false` once App Group + shared SwiftData is wired through (so widget taps log silently)

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
