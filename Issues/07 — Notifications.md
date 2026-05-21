---
status: done
priority: high
tags: [logging]
---

# Notifications

Port the prototype's three-notification system to `UNUserNotificationCenter`. Source of truth: [Notifications](../Engineering/Notifications.md).

## Tasks

- [x] `NotificationScheduler` enum (MainActor) — `requestAuthorization`, `reschedule(after:)`
- [x] Permission request: triggered on the user's first hit (not cold launch). Idempotent.
- [x] Immediate notification on log
  - [x] Pre-baseline body: "Xm since last hit · N/10 baseline" / "First hit logged. Building your baseline."
  - [x] Post-baseline body: "⏱ Xm since last hit · avg Ym"
  - [x] Appends "· 🥇 new waking best" when `longestWakingGap` was just updated by this append
  - [x] Unique identifier per immediate notification so two quick hits both surface
- [x] Scheduled "beat your average" (`drift-beat-average`)
  - [x] Only when `totalHits >= 10` and `wakingAvgSec > 0`
  - [x] Trigger: `wakingAvgSec + notifsBeatAverageOffsetSec` from now (configurable picker; default 60s)
  - [x] Overnight hedge body when trigger lands inside the configured sleep window
- [x] Scheduled "beat your record" (`drift-beat-record`)
  - [x] Trigger: `longestWakingGapSec + notifsBeatRecordOffsetSec` from now (configurable picker; default 0s = "right at")
  - [x] Skipped if trigger lands past `endOfWakingDay(now)` (next sleep-end cutoff, default 6am)
  - [x] Overnight hedge body, same window
  - [x] Skipped when `longestWakingGapSec == 0` or `totalHits < 2`

## Settings hooks (from [Issues/12 — Onboarding, settings, app icon](12%20%E2%80%94%20Onboarding%2C%20settings%2C%20app%20icon.md))

- [x] Master notifications toggle (`notifsEnabled`) — short-circuits `reschedule(after:)` when off, cancels pending requests, and skips the permission prompt.
- [x] Per-type toggles — immediate (`notifsImmediateEnabled`) / beat-average (`notifsBeatAverageEnabled`) / beat-record (`notifsBeatRecordEnabled`). When off, that type is skipped during reschedule.
- [x] **Beat-average timing offset** picker: *right at / +1 min / +5 min / +10 min / +15 min*. Default **+1 min**. Replaces the hard-coded `+60` constant.
- [x] **Beat-record timing offset** picker: same options. Default **right at** (0). Replaces the hard-coded `+1`.
- [x] Settings flips trigger `NotificationScheduler.cancelPending()` so stale schedules don't fire under new prefs; next hit reschedules with current settings.
- [x] `isOvernight` reads `driftSleepStartHour()` / `driftSleepEndHour()` from settings (default 23 / 6) instead of hard-coded 23–6 — handles wraps-midnight (typical) and inverted (start < end) schedules.
- [x] `HitStore.append` captures `prevLast` + `prevWakingRecord`, computes `isNewWakingBest`, fires `Task { NotificationScheduler.reschedule(after:) }` after the SwiftData save

## Tests

Manual:
1. Log at 11:50pm with a 2h record. Verify the scheduled record-beat is hedged (`If you're still awake...`).
2. Log a hit. Wait 30s. Log another. Verify the first scheduled notification is gone, the new one is queued for the new time.
3. With < 10 hits, verify beat-average is not scheduled and immediate body says "N/10 baseline".

## Out of scope

- Live Activities
- Notification action buttons
- Per-notification mute (the master + per-type toggles cover this)
