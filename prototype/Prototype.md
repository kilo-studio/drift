# Drift — Scriptable prototype

The original implementation: two iOS Shortcuts pointing at two Scriptable scripts in `iCloud Drive/Scriptable/`. This is the version that taught us what Drift wants to be — the native rebuild grew from here.

## What it does

- **One-tap logging** — Action Button triggers a Shortcut that runs a Scriptable script. Each tap appends a `{t, tz}` object to a JSON file in iCloud, computes time since last hit, updates the personal-best gap, and shows a notification.
- **Smart scheduled notifications** — On every log, the script schedules two future notifications: one for when you cross your average gap (encouraging you to wait), and one for when you cross your all-time longest stretch (celebration). Both get cancelled and rescheduled on the next log, so they only fire if you actually beat the threshold.
- **Stats dashboard** — A second Scriptable script renders an HTML dashboard inside a WebView with: live "free for X" counter, today's count, average per day, waking-hours average gap, 14-day daily bar chart, hour-of-day craving distribution, 7-day rolling-average line chart, and a continuously-animated cloud spirit character.

## Architecture

```
iCloud Drive/Scriptable/
├── vape-log.json     ← data store, single source of truth
├── vape-log.js       ← logger script (silent, fast)
└── vape-stats.js     ← dashboard script (opens WebView)
```

Two iOS Shortcuts, each containing a single **Run Script** action:

- **Vape Log** — runs `vape-log`. "Run In App" toggle: **OFF** (silent background execution). Bound to the Action Button.
- **Vape Stats** — runs `vape-stats`. "Run In App" toggle: **ON** (required because `WebView.present()` only works inside the Scriptable app). Lives on home screen.

## Data format

`vape-log.json`:

```json
{
  "hits": [
    { "t": "2026-04-26T15:30:00Z", "tz": -420 },
    { "t": "2026-04-26T16:12:44Z", "tz": -420 }
  ],
  "longestGap": 2564,
  "longestWakingGap": 1842
}
```

- `hits[].t` — ISO 8601 UTC timestamp
- `hits[].tz` — minutes east of UTC at log time, so we can recover the wall-clock the user saw regardless of the device's current zone
- `longestGap` — longest interval ever achieved between two consecutive hits, in seconds (sleep gaps included; display only)
- `longestWakingGap` — longest interval between two consecutive hits *within a single waking day* (4am-to-4am bucket), in seconds. Excludes overnight sleep gaps. Backfilled from existing hits on first run after upgrade.

The file initializes itself if missing. Manual editing is fine if you want to seed data or remove polluted entries. Old `string[]` hit format is migrated to `{t, tz}` automatically.

## Key design decisions (carried into native build)

### Waking-hours average

The "average gap" used in scheduled notifications and on the dashboard groups hits into 4am-to-4am buckets, then averages only intervals *within* each bucket. This excludes overnight sleep gaps from the math, which would otherwise inflate the average dramatically.

A hit at 2am Wednesday belongs to Tuesday's bucket. Days with only 1 hit get skipped (no interval to compute). If no day has 2+ hits yet, falls back to all-time average.

### Longest waking stretch

The "beat your record" scheduled notification triggers off `longestWakingGap`, not `longestGap`. The all-time longest is almost always an overnight sleep gap — celebrating it the moment you wake up is misleading. The waking version measures the longest gap *within a single waking day*, which is the metric you can actually influence.

### Rolling 30-day window

Both averages (per-day count + waking-gap interval) use a rolling 30-day window so they react to recent behavior rather than being dragged toward all-time history. Two slightly different windows:

- **Per-day average excludes today** — partial day would deflate the count mean
- **Waking-gap average includes today** — intervals are real intervals regardless of day completeness

### Overnight notification hedge

Scheduled "beat" notifications can fire while the user is asleep (e.g. last hit at 11:30pm, record is 2h33m → notification fires at 2:03am). The scheduler can't tell whether the user is actually awake at the trigger time. If the trigger lands in the typical sleep window (23:00–06:00 local), the notification body is hedged: "If you're still awake, you just beat your longest waking stretch of Xm." Otherwise the wording is confident.

### Why Scriptable over native Shortcuts

The first version of this was pure Shortcuts actions (Get File → Get Dictionary → Time Between Dates → etc). It hit several walls: JSON values come out as strings and break numeric comparisons; `Time Between Dates` doesn't auto-coerce ISO strings; no `Format Duration` action so Xh Ym formatting is a 7-step chain; averages were unreliable. Scriptable handles all of this natively in JavaScript and is dramatically more debuggable.

## Notification scheduling

Both scheduled notifications use `notification.setTriggerDate(date)` (a method) — **not** `notification.deliveryDate = date` (a read-only property). This was a real bug in an earlier version: setting `deliveryDate` made notifications fire immediately because no trigger was actually configured.

On every log run, the script:
1. Cancels both pending notifications via `Notification.removePending(["vape-beat-average", "vape-beat-record"])`
2. Shows the immediate "logged" notification
3. If past baseline (10 hits), schedules a new "beat average" for `now + avgIntervalSec + 60`, with overnight hedge
4. Schedules a new "beat record" for `now + longestWakingGap + 1`, but only if that timestamp falls before the next 4am cutoff, with overnight hedge

`removePending` only cancels notifications that haven't fired yet — it can't dismiss already-delivered banners. This isn't usually a problem in practice since the next log immediately overwrites them.

## Visual design

Ghibli-inspired sky aesthetic: soft sky-blue gradient at top fading to cream at bottom, drifting cloud SVGs (clipped to viewport via `position: fixed; overflow: hidden` layer), a small floating cloud spirit character at the top, glassy cream-colored cards with soft shadows.

**Spirit character** — cloud body with soft round eyes (Totoro-style dots, not vertical pupils), gentle blink animation. Its appearance is driven by a single ratio = `ms / avgMs` (time since last hit ÷ rolling-30d waking-gap average). Eyes scale up bottom-anchored as ratio grows; a 200-sparkle viewport-fill reveals progressively from halo to full screen; soft golden drop-shadow at milestones.

**Type system**:
- **Quicksand** (rounded sans, weight 600) — for all big numbers and most UI
- **Caveat** (handwritten) — for card titles, decorative labels like "free for", and chart subtitles
- **Fraunces** (variable serif) — relegated to small functional text only (was originally the display face but read poorly at scale)

**Color palette**:
- **Coral** `#E8836B` — today / current state
- **Peach** `#F4B393` — past data points (non-aggregated)
- **Sage** `#7E9476` / `#A8BC93` — averages, aggregates, distributions
- **Sky** `#7FA7BD` → `#A8C6D5` → `#C8DDE4` → `#DCE5DA` — body gradient top-to-bottom
- **Ink** `#4A453F` — primary text
- **Cream** `#FAF3E7` / `#F5EAD8` — card surfaces

Charts via Chart.js (CDN); fonts via Google Fonts (CDN). Both require an internet connection on first load; iOS caches them after.

## Setup

1. Install **Scriptable** from the App Store (free).
2. Place `vape-log.js` and `vape-stats.js` in `iCloud Drive/Scriptable/`. Easiest method: download the .js files in Files app, long-press, Move to that folder. Don't paste the code into Scriptable's editor — iOS autocorrect turns straight quotes into smart quotes (`“`/`”`) and breaks the script.
3. Build two Shortcuts each containing a single Run Script action targeting the respective script. Set "Run In App" appropriately (off for log, on for stats).
4. Bind Vape Log to the Action Button under Settings → Action Button → Shortcut.
5. First run will request notification + iCloud permissions.

## Known limitations

- **Stats dashboard requires internet** for first load (Chart.js + Google Fonts CDN). Cached after.
- **Notifications only fire while the device is on**. Standard iOS behavior — scheduled local notifications survive reboots and sleep, but if the trigger time passes while the device is off, the notification queues until next wake.
- **No data sync between devices** beyond iCloud Drive's transparent sync. Don't run the logger on multiple devices simultaneously or you'll get write conflicts.
- **WebView dashboard is read-only.** Data manipulation has to happen in the logger script or by editing the JSON directly.
