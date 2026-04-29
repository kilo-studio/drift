---
status: done
priority: high
tags: [logging]
---

# Notifications

Port the prototype's three-notification system to `UNUserNotificationCenter`. Source of truth: [[Notifications]].

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
  - [x] Trigger: `wakingAvgSec + 60` from now
  - [x] Overnight hedge body when trigger lands in 23:00–05:59 local
- [x] Scheduled "beat your record" (`drift-beat-record`)
  - [x] Trigger: `longestWakingGapSec + 1` from now
  - [x] Skipped if trigger lands past `endOfWakingDay(now)` (next 4am cutoff)
  - [x] Overnight hedge body, same window
  - [x] Skipped when `longestWakingGapSec == 0` or `totalHits < 2`
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
