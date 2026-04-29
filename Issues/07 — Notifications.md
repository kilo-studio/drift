---
status: todo
priority: high
tags: [logging]
---

# Notifications

Port the prototype's three-notification system to `UNUserNotificationCenter`. Source of truth: [[Notifications]].

## Tasks

- [ ] `NotificationScheduler` class
- [ ] Permission request flow with a clear explainer screen (don't auto-prompt on cold launch; trigger from settings or first hit)
- [ ] Immediate notification on hit log (`drift-logged`)
  - [ ] Body shape baseline-aware: `Xm since last hit · N/10 baseline` vs `⏱ Xm since last hit · avg Ym`
  - [ ] Append `· 🥇 new waking best` if `longestWakingGap` was just updated
- [ ] Scheduled "beat your average" (`drift-beat-average`)
  - [ ] Only after baseline (10 hits)
  - [ ] Trigger: `now + wakingAvgSec + 60`
  - [ ] Overnight hedge body
- [ ] Scheduled "beat your record" (`drift-beat-record`)
  - [ ] Trigger: `now + longestWakingGap + 1`
  - [ ] Skip if trigger is past next 4am cutoff
  - [ ] Overnight hedge body
- [ ] On every hit: `removePendingNotificationRequests` for both scheduled identifiers, then re-add

## Tests

Manual:
1. Log at 11:50pm with a 2h record. Verify the scheduled record-beat is hedged (`If you're still awake...`).
2. Log a hit. Wait 30s. Log another. Verify the first scheduled notification is gone, the new one is queued for the new time.
3. With < 10 hits, verify beat-average is not scheduled and immediate body says "N/10 baseline".

## Out of scope

- Live Activities
- Notification action buttons
- Per-notification mute (the master + per-type toggles cover this)
