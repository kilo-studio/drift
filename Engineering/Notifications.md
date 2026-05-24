# Notifications

Three notifications, all using `UNUserNotificationCenter`. Identifiers stable so they cancel/replace cleanly.

## 1. Immediate (fires when a hit is logged)

Identifier: `drift-logged` (or no identifier — fires once and is forgotten)

Body shape:
- Before baseline (< 5 hits total): `Xm since last hit · N/5 baseline`
- After baseline: `⏱ Xm since last hit · avg Ym`
- Append `· 🏆 new longest drift` (all-time) or `· 🥇 new longest drift while awake` if this hit set a new record

Fired immediately. No scheduling. Title: `Drift`.

## 2. Beat your average (scheduled, only after baseline)

Identifier: `drift-beat-average`

Trigger time: `now + wakingAvgSec + beatAvgOffset`. `beatAvgOffset` is configurable in settings — picker exposes *right at / +1 min / +5 min / +10 min / +15 min*. Historically a hard-coded 60s, kept as a grace period so the notification didn't fire while still mid-action; with sessions in place that grace is less load-bearing, which is part of why the offset is now user-controlled.

Title: `👏 you're beating your average`. Body: `Don't hit it. You're past your average of Ym`.

**Not scheduled at all if the trigger lands in the sleep window** — see [Overnight suppression](#overnight-suppression). We don't fire celebrations while the user is likely asleep.

Cancelled via `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` on every new hit, then re-scheduled with the new `wakingAvgSec`.

Skipped entirely if hit count < 5 (baseline).

## 3. Beat your record (scheduled)

Identifier: `drift-beat-record`

Trigger time: `now + longestWakingGap + beatRecordOffset`. `beatRecordOffset` is the same picker as `beatAvgOffset` (right-at / +1m / +5m / +10m / +15m); historically `+1s` so the trigger landed an instant past the record. Only scheduled if that timestamp falls **before** the next 4am cutoff — sleep gaps shouldn't be celebrated as a "waking best."

This toggle covers two record notifications, both with confident wording (no overnight variant):
- **Waking record** — title `🥇 new longest drift while awake`, body `You just beat your longest drift while awake: Ym. Keep drifting.` Only scheduled if the trigger falls before the next end-of-waking-day cutoff (a sleep gap shouldn't count as a waking best).
- **All-time record** — title `🏆 new longest drift`, body `You just beat your longest drift ever: Ym. Keep drifting.`

Both are **skipped if the trigger lands in the sleep window**, and skipped if the relevant record is 0 (none set yet) or `hits.count < 2`.

## Overnight suppression

Every scheduled notification checks whether its trigger time's hour-of-day falls in the user-configured sleep window (default 23:00–05:59 local; see the bedtime/wake-up pickers in settings). **If it does, the notification simply isn't scheduled** — better to stay silent than to celebrate a gap the user spent asleep. `isOvernight` reads `driftSleepStartHour()` / `driftSleepEndHour()` and handles both wraps-midnight (start > end, the typical case) and inverted (start < end) schedules.

An earlier version *hedged* the wording instead ("If you're still awake, you just beat…") rather than suppressing. It was dropped because the conditional copy read as confusing on wake-up; not firing is cleaner and more honest. A data-driven sleep window (inferring actual sleep hours from logging patterns) is a candidate v1.1 enhancement; for v1 the configurable fixed window is honest enough.

## Reschedule loop

On every hit:

1. `removePendingNotificationRequests(withIdentifiers: ["drift-beat-average", "drift-beat-record"])`
2. Schedule the immediate `drift-logged`
3. If past baseline, build and schedule `drift-beat-average`
4. If `longestWakingGap > 0` and hit count ≥ 2, build `drift-beat-record`
5. If the record-beat trigger is before the next 4am cutoff, schedule it; otherwise skip

`removePendingNotificationRequests` only cancels notifications that haven't fired yet. Already-delivered banners stay until the user dismisses them. In practice the next log replaces them quickly.

## Permissions

Request `[.alert, .sound, .badge]` on first launch (or first time the user enables notifications in settings). Don't auto-prompt — surface a clear "tap to enable notifications" CTA the first time the user views the dashboard, with copy that explains the three notification types and that notifications stay quiet during sleep.

## Testing

Three things to manually verify:
1. Log a hit at 11:50pm with a 2h waking record. The scheduled record-beat should be skipped entirely: its trigger lands in the overnight sleep window, so it isn't scheduled at all.
2. Cancel-and-reschedule: log a hit, observe the scheduled notification, log another hit, verify the first scheduled one is gone and the new one is queued.
3. Baseline: with fewer than 5 hits total, the beat-average should not be scheduled. Body of immediate should say "N/5 baseline."

## Out of scope for v1

- Live Activities (could show the timer on the Lock Screen)
- Critical Alerts (none of these warrant breaking through DND)
- Notification action buttons (snooze, dismiss-record-celebration, etc.)
