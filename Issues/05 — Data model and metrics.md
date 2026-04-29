---
status: todo
priority: high
tags: [foundation]
---

# Data model and metrics

Build the `Hit` SwiftData entity, the `HitStore` wrapper, and every computed metric. Mirror the prototype's logic exactly. Source of truth: [[Data model]].

## Tasks

- [ ] `Hit` SwiftData model with `t: Date` and `tzOffsetMinutes: Int`
- [ ] `HitStore` (Observable, singleton via SwiftData ModelContext)
- [ ] `localOf(_ hit: Hit) -> Date` helper
- [ ] `wakingDayKey(_ hit: Hit) -> String` (4am cutoff)
- [ ] `logLocalDateKey(_ hit: Hit) -> String`
- [ ] `deviceLocalDateKey(_ date: Date) -> String`
- [ ] Rolling 30-day window helpers: `hitsInRollingWindow(includeToday:)` 
- [ ] `avgPerDay` (excludes today)
- [ ] `wakingAvgSec` (includes today, returns optional)
- [ ] `longestWakingGap` (persisted, updated on append with same-waking-day check)
- [ ] `longestGap` (persisted, updated on append)
- [ ] `todayCount`
- [ ] `dailyCounts(lastN: 14)` for the fortnight chart
- [ ] `hitsByHour: [Int]` (24 buckets) for hour distribution
- [ ] `todayStretches() -> [(Date, TimeInterval)]` for today's stretches chart
- [ ] `rollingAvg(window: 7, lastN: 30) -> [(Date, TimeInterval)]` for the rolling-avg chart
- [ ] `lastHitDate: Date?`

## Tests

Unit tests for at least:
- `wakingDayKey` boundary cases (3:59am, 4:00am, midnight)
- `avgPerDay` excludes today even when today has hits
- `wakingAvgSec` includes today
- `longestWakingGap` only updates when both hits share a waking day
- Rolling-window edge: first hit before 30 days ago vs within 30 days

## Migration

- [ ] On first launch, check `~/Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents/vape-log.json`
- [ ] If present, parse and import each hit
- [ ] Mark migrated in UserDefaults; don't re-import
- [ ] Don't delete or modify the JSON — let the prototype keep working in parallel if the user wants
