---
status: done
priority: high
tags: [foundation]
---

# Data model and metrics

Build the `Hit` SwiftData entity, the `HitStore` wrapper, and every computed metric. Mirror the prototype's logic exactly. Source of truth: [[Data model]].

## Tasks

- [x] `Hit` SwiftData model with `t: Date` and `tzOffsetMinutes: Int`
- [x] `Records` SwiftData model for persisted `longestGapSec` / `longestWakingGapSec` (now session-level — see Issue 16)
- [x] `Session` derived struct + `[Hit].sessions(threshold:)` (Issue 16)
- [x] `HitStore` — `@Observable @MainActor` wrapper over `ModelContext`, plus `sessionThresholdSec` UserDefaults-backed setting
- [x] `Hit.local` (was `localOf` in prototype) — Hit extension property
- [x] `Hit.wakingDayKey` (4am cutoff)
- [x] `Hit.logLocalDateKey`
- [x] `deviceLocalDateKey(_:)` / `currentWakingDayKey(_:)` free functions
- [x] `hitsInRollingWindow(includeToday:now:window:)` on `[Hit]`
- [x] **Session-level (frequency, drives spirit + dashboard):** `todaySessionCount`, `avgSessionsPerDay`, `wakingAvgSec`, `sessionsByHour`, `dailySessionCounts`, `todayStretches`, `rollingAvg`, `lastSessionEnd`
- [x] **Hit-level (intensity, secondary display + achievements):** `todayHitCount`, `avgHitsPerSession`
- [x] **Persisted records:** `longestGapSec` / `longestWakingGapSec` updated only when a new hit starts a new session (intra-session deltas don't pollute records)
- [x] `lastHitDate: Date?`

Pure metric functions live on `Array where Element == Hit` so they're testable without a `ModelContext`. `HitStore` exposes them as forwarders that pass the configured threshold.

## Tests

19 unit tests, all passing on iOS 26 sim:

- [x] `wakingDayKey` — 3:59am, 4:00am, midnight, tz-shifted, plus `logLocalDateKey` ignoring the cutoff
- [x] **Session derivation** — solo hit, within-threshold cluster, beyond-threshold split, exact-threshold edge, session crossing 4am inheriting first hit's bucket
- [x] `avgSessionsPerDay` excludes today; empty array yields 0
- [x] `wakingAvgSec` averages between-session gaps across waking-day buckets; nil when no bucket has 2+ sessions
- [x] `longestWakingGap` — intra-session hits don't update record; inter-session same-day does; across-4am-boundary updates only `longestGap`
- [x] Rolling-window edge: first hit older than window vs within window

## Migration

- [x] `PrototypeImport.parse(_:)` parses the prototype's `vape-log.json` shape (handles legacy string-only format)
- [x] `HitStore.importPrototype(_:)` appends parsed hits via the regular append path so records get backfilled
- [ ] **Deferred to first-launch flow:** wire UIDocumentPicker so the user can hand the iCloud Drive `vape-log.json` to Drift (Drift can't read another app's iCloud container directly), set the `drift.migration.scriptable.complete` UserDefaults flag
