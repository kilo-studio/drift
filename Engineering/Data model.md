# Data model

## Hit entity

```swift
@Model
final class Hit {
    var t: Date            // UTC instant
    var tzOffsetMinutes: Int   // minutes east of UTC at log time
    init(t: Date = .now, tzOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60) {
        self.t = t
        self.tzOffsetMinutes = tzOffsetMinutes
    }
}
```

The timezone offset is stored at log time so we can recover the wall-clock the user saw, regardless of where they are now. A hit logged at 2pm in Tokyo, viewed from California, still belongs to the Tokyo afternoon for grouping/display purposes.

## Derived: localOf(hit)

```swift
func localOf(_ hit: Hit) -> Date {
    hit.t.addingTimeInterval(TimeInterval(hit.tzOffsetMinutes * 60))
}
```

Returns a `Date` whose UTC components yield the wall-clock the user saw. Use for all date-keying.

## Waking-day grouping (4am cutoff)

Hits between midnight and 4am roll back to the previous "waking day." A hit at 2am Wednesday belongs to Tuesday's bucket. This excludes overnight sleep gaps from gap calculations.

```swift
func wakingDayKey(_ hit: Hit) -> String {
    var local = localOf(hit)
    let cal = Calendar(identifier: .gregorian).withUTC
    let hour = cal.component(.hour, from: local)
    if hour < 4 {
        local = cal.date(byAdding: .day, value: -1, to: local)!
    }
    return ISO8601DateFormatter.ymd.string(from: local)
}
```

## Rolling 30-day window

The two displayed averages (per-day count + waking-gap interval) use a 30-day window, but with **different inclusion rules for today**:

| Metric | Today included? | Why |
|---|---|---|
| `avgPerDay` | **No** | Partial day would deflate the count mean |
| `wakingAvgSec` | **Yes** | Intervals between hits are real intervals regardless of day completeness |

```swift
let windowDays = 30
let endDay   = todayDeviceLocal           // today's date in device-local time
let startDay = endDay.adding(days: -windowDays)

let hitsForCount = hits.filter { hit in
    let k = logLocalDateKey(hit)
    return k >= startDay && k < endDay         // strictly less than today
}

let hitsForGap = hits.filter { hit in
    let k = logLocalDateKey(hit)
    return k >= startDay                       // includes today
}
```

## Computed metrics

### `avgPerDay`

Mean of per-day counts across the rolling window, **excluding today**. If the user has only logged for 12 days, average over 12 (not 30 with 18 zero-padded days).

```swift
var avgPerDay: Double {
    let counts = hitsForCount.grouped(by: logLocalDateKey).mapValues(\.count)
    let firstHit = hits.first.map(logLocalDateKey)
    let start = max(firstHit ?? startDay, startDay)
    var values: [Int] = []
    var cur = start
    while cur < endDay {
        values.append(counts[cur, default: 0])
        cur = cur.addingDays(1)
    }
    return values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
}
```

### `wakingAvgSec`

Total span / total intervals across waking-day buckets, **including today's bucket**. Returns `nil` if no day has 2+ hits.

```swift
var wakingAvgSec: TimeInterval? {
    let buckets = Dictionary(grouping: hitsForGap, by: wakingDayKey)
    var totalSpan: TimeInterval = 0
    var totalIntervals = 0
    for (_, dayHits) in buckets where dayHits.count >= 2 {
        let sorted = dayHits.sorted { $0.t < $1.t }
        totalSpan += sorted.last!.t.timeIntervalSince(sorted.first!.t)
        totalIntervals += dayHits.count - 1
    }
    guard totalIntervals > 0 else { return nil }
    return totalSpan / Double(totalIntervals)
}
```

### `longestWakingGap` / `longestGap`

`longestGap` = max interval between any two consecutive hits, ever. (Sleep gaps are usually the largest — used only for display, not for celebration logic.)

`longestWakingGap` = max interval between two consecutive hits *within a single waking-day bucket*. This is the metric the spirit and notifications celebrate.

Both are persisted (not just computed on the fly) — when a new hit comes in, we check whether it sets a new record:

```swift
func append(_ hit: Hit) {
    if let last = hits.last {
        let delta = hit.t.timeIntervalSince(last.t)
        if delta > longestGap { longestGap = delta }
        if wakingDayKey(last) == wakingDayKey(hit), delta > longestWakingGap {
            longestWakingGap = delta
        }
    }
    hits.append(hit)
}
```

The waking-day check is critical — without it, an overnight gap would set the "waking" record, defeating the purpose.

## Spirit ratio

The spirit's appearance is driven by:

```swift
let ratio = max(0.001, lastHitMs / wakingAvgMs)
```

Where `lastHitMs = now - lastHit.t` and `wakingAvgMs = wakingAvgSec * 1000` (or 0 if not enough data — in which case the spirit defaults to ratio 1).

See [[Spirit]] for what the ratio drives.

## Migration from prototype

The prototype's `vape-log.json` already uses the `{t, tz}` format (was migrated from string-only earlier). On first run of the native app:

1. Read `vape-log.json` from iCloud Drive (if present)
2. Import each hit into SwiftData
3. Mark the import as complete in UserDefaults
4. Don't touch `vape-log.json` again — let users keep using Scriptable in parallel if they want, or stop logging there

No format conversion needed — same shape on both sides.

## Hit count expectations

For a heavy user logging every 30 seconds over months: ~2,880/day × 365 = ~1M hits/year. That's a non-trivial dataset but well within SwiftData's comfort. For lighter users (every 30 min) it's ~17,500/year. Any aggregation that touches all hits should be cached and invalidated on append.

In practice, the rolling-30-day window means most queries only touch ~30 days of hits, which caps the working set even for heavy users.
