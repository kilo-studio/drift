# Notifications

Three notifications, all using `UNUserNotificationCenter`. Identifiers stable so they cancel/replace cleanly.

## 1. Immediate (fires when a hit is logged)

Identifier: `drift-logged` (or no identifier — fires once and is forgotten)

Body shape:
- Before baseline (< 10 hits total): `Xm since last hit · N/10 baseline`
- After baseline: `⏱ Xm since last hit · avg Ym`
- Append `· 🥇 new waking best` if this hit set a new `longestWakingGap`

Fired immediately. No scheduling. Title: `Drift`.

## 2. Beat your average (scheduled, only after baseline)

Identifier: `drift-beat-average`

Trigger time: `now + wakingAvgSec + beatAvgOffset`. `beatAvgOffset` is configurable in settings — picker exposes *right at / +1 min / +5 min / +10 min / +15 min*. Historically a hard-coded 60s, kept as a grace period so the notification didn't fire while still mid-action; with sessions in place that grace is less load-bearing, which is part of why the offset is now user-controlled.

Body:
- Daytime (06:00–22:59): `Don't hit it — you're past your average of Ym`
- Overnight (23:00–05:59 local): `If you're still awake, you're past your average of Ym`

The hedge exists because we can't tell if the user is actually awake when the notification fires — the same logic on the [record notification](Notifications.md#overnight-hedge) applies.

Cancelled via `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` on every new hit, then re-scheduled with the new `wakingAvgSec`.

Skipped entirely if hit count < 10 (baseline).

## 3. Beat your record (scheduled)

Identifier: `drift-beat-record`

Trigger time: `now + longestWakingGap + beatRecordOffset`. `beatRecordOffset` is the same picker as `beatAvgOffset` (right-at / +1m / +5m / +10m / +15m); historically `+1s` so the trigger landed an instant past the record. Only scheduled if that timestamp falls **before** the next 4am cutoff — sleep gaps shouldn't be celebrated as a "waking best."

Body:
- Daytime: `You just beat your longest waking stretch of Ym. Keep drifting.`
- Overnight (23:00–05:59 local): `If you're still awake, you just beat your longest waking stretch of Ym. Keep drifting.`

Title: `🥇 new waking best`.

Skipped if `longestWakingGap == 0` (no record set yet) or `hits.count < 2`.

## Overnight hedge

Both scheduled notifications check whether the trigger time's hour-of-day falls in the user-configured sleep window (default 23:00–05:59 local; see the bedtime/wake-up pickers in settings). If yes, the body is hedged ("If you're still awake..."). If no, the body is confident. `isOvernight` reads `driftSleepStartHour()` / `driftSleepEndHour()` and handles both wraps-midnight (start > end, the typical case) and inverted (start < end) schedules.

This is option 4 of the alternatives we considered. Other options:
- Drop the scheduled record-beat notification entirely
- Tighten the cutoff (only schedule if trigger is before, say, 11pm)
- Use a data-driven sleep window (analyze user's logging pattern to find their actual sleep hours)

We picked hedging because it preserves real-time celebration during the day without lying overnight. The data-driven sleep window is a candidate v1.1 enhancement; for v1 the fixed 23–06 window is honest enough.

## Reschedule loop

On every hit:

1. `removePendingNotificationRequests(withIdentifiers: ["drift-beat-average", "drift-beat-record"])`
2. Schedule the immediate `drift-logged`
3. If past baseline, build and schedule `drift-beat-average`
4. If `longestWakingGap > 0` and hit count ≥ 2, build `drift-beat-record`
5. If the record-beat trigger is before the next 4am cutoff, schedule it; otherwise skip

`removePendingNotificationRequests` only cancels notifications that haven't fired yet. Already-delivered banners stay until the user dismisses them. In practice the next log replaces them quickly.

## Permissions

Request `[.alert, .sound, .badge]` on first launch (or first time the user enables notifications in settings). Don't auto-prompt — surface a clear "tap to enable notifications" CTA the first time the user views the dashboard, with copy that explains the three notification types and the hedge.

## Testing

Three things to manually verify:
1. Log a hit at 11:50pm with longest-waking record of 2h. The scheduled record-beat should be skipped (trigger time 1:50am > 4am? no, before 4am — but in the overnight window, so the body should be hedged).
2. Cancel-and-reschedule: log a hit, observe the scheduled notification, log another hit, verify the first scheduled one is gone and the new one is queued.
3. Baseline: with fewer than 10 hits total, the beat-average should not be scheduled. Body of immediate should say "N/10 baseline."

## Out of scope for v1

- Live Activities (could show the timer on the Lock Screen)
- Critical Alerts (none of these warrant breaking through DND)
- Notification action buttons (snooze, dismiss-record-celebration, etc.)
