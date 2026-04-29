---
status: doing
priority: high
tags: [foundation]
---

# Data model and metrics

Build the `Hit` SwiftData entity, the `HitStore` wrapper, and every computed metric. Mirror the prototype's logic exactly. Source of truth: [[Data model]].

## Tasks

- [x] `Hit` SwiftData model with `t: Date` and `tzOffsetMinutes: Int`
- [x] `Records` SwiftData model for persisted `longestGapSec` / `longestWakingGapSec`
- [x] `HitStore` — `@Observable @MainActor` wrapper over `ModelContext`
- [x] `Hit.local` (was `localOf` in prototype) — Hit extension property
- [x] `Hit.wakingDayKey` (4am cutoff)
- [x] `Hit.logLocalDateKey`
- [x] `deviceLocalDateKey(_:)` free function
- [x] `currentWakingDayKey(_:)` free function for "today" with 4am cutoff
- [x] `hitsInRollingWindow(includeToday:now:window:)` on `[Hit]`
- [x] `avgPerDay` (excludes today)
- [x] `wakingAvgSec` (includes today, returns optional)
- [x] `longestWakingGapSec` (persisted via `Records`, updated on append with same-waking-day check)
- [x] `longestGapSec` (persisted via `Records`, updated on append)
- [x] `todayCount`
- [x] `dailyCounts(lastN: 14)`
- [x] `hitsByHour: [Int]`
- [x] `todayStretches() -> [(Date, TimeInterval)]`
- [x] `rollingAvg(window: 7, lastN: 30) -> [(Date, TimeInterval)]`
- [x] `lastHitDate: Date?`

Pure metric functions live on `Array where Element == Hit` so they're testable without a `ModelContext`. `HitStore` exposes them as forwarders.

## Tests

12 unit tests, all passing on iOS 26 sim:

- [x] `wakingDayKey` — 3:59am, 4:00am, midnight, tz-shifted, plus `logLocalDateKey` ignoring the cutoff
- [x] `avgPerDay` excludes today; empty array yields 0
- [x] `wakingAvgSec` includes today's intervals; nil when no day has 2+ hits
- [x] `longestWakingGap` updates on same-waking-day pair, does NOT update across the 4am boundary
- [x] Rolling-window edge: first hit older than window vs within window

## Migration

- [x] `PrototypeImport.parse(_:)` parses the prototype's `vape-log.json` shape (handles legacy string-only format)
- [x] `HitStore.importPrototype(_:)` appends parsed hits via the regular append path so records get backfilled
- [ ] **Deferred to first-launch flow:** wire UIDocumentPicker so the user can hand the iCloud Drive `vape-log.json` to Drift (Drift can't read another app's iCloud container directly), set the `drift.migration.scriptable.complete` UserDefaults flag
