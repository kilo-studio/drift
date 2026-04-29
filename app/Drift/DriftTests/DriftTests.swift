import Testing
import Foundation
import SwiftData
@testable import Drift

// MARK: - Helpers

private let utcFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func hit(_ iso: String, tz: Int = 0) -> Hit {
    Hit(t: utcFormatter.date(from: iso)!, tzOffsetMinutes: tz)
}

private func deviceTz() -> Int { TimeZone.current.secondsFromGMT() / 60 }

// MARK: - wakingDayKey

@Suite("wakingDayKey 4am cutoff")
struct WakingDayKeyTests {
    @Test("3:59am local rolls back to previous day")
    func threeFiftyNine() {
        #expect(hit("2025-01-15T03:59:00Z", tz: 0).wakingDayKey == "2025-01-14")
    }

    @Test("4:00am local stays on the same day")
    func fourAM() {
        #expect(hit("2025-01-15T04:00:00Z", tz: 0).wakingDayKey == "2025-01-15")
    }

    @Test("midnight rolls back to previous day")
    func midnight() {
        #expect(hit("2025-01-15T00:00:00Z", tz: 0).wakingDayKey == "2025-01-14")
    }

    @Test("tz offset shifts the cutoff")
    func tzOffset() {
        // 04:00 UTC at tz=-180 (3h west) is 01:00 local — rolls back.
        #expect(hit("2025-01-15T04:00:00Z", tz: -180).wakingDayKey == "2025-01-14")
        // 06:59 UTC at tz=-180 is 03:59 local — rolls back.
        #expect(hit("2025-01-15T06:59:00Z", tz: -180).wakingDayKey == "2025-01-14")
        // 07:00 UTC at tz=-180 is 04:00 local — stays.
        #expect(hit("2025-01-15T07:00:00Z", tz: -180).wakingDayKey == "2025-01-15")
    }

    @Test("logLocalDateKey ignores the cutoff")
    func logKeyIgnoresCutoff() {
        // Both 2am and 5pm local on the 15th map to 2025-01-15 in logLocalDateKey.
        #expect(hit("2025-01-15T02:00:00Z", tz: 0).logLocalDateKey == "2025-01-15")
        #expect(hit("2025-01-15T17:00:00Z", tz: 0).logLocalDateKey == "2025-01-15")
    }
}

// MARK: - Metrics

@Suite("avgPerDay excludes today")
struct AvgPerDayTests {
    @Test("today's hits do not count toward the mean")
    func excludesToday() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        let oneDayAgo = cal.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now)!

        let hits = [
            Hit(t: twoDaysAgo, tzOffsetMinutes: tz),  // 1 hit two days ago
            Hit(t: twoDaysAgo, tzOffsetMinutes: tz),  // (2 total)
            Hit(t: oneDayAgo,  tzOffsetMinutes: tz),  // 1 hit yesterday
            Hit(t: now,        tzOffsetMinutes: tz),  // today (excluded)
            Hit(t: now,        tzOffsetMinutes: tz),
            Hit(t: now,        tzOffsetMinutes: tz),
        ]

        // Two days iterated, totals 2 + 1 = 3 → average = 1.5
        #expect(hits.avgPerDay(now: now) == 1.5)
    }

    @Test("empty array yields 0")
    func empty() {
        #expect([Hit]().avgPerDay() == 0)
    }
}

@Suite("wakingAvgSec includes today")
struct WakingAvgSecTests {
    @Test("today's intervals are included")
    func includesTodayInterval() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()

        // Yesterday: two hits 6h apart → 1 interval of 6h, span 6h.
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterdayLater = cal.date(byAdding: .second, value: 6 * 3600, to: yesterdayMorning)!

        // Today: two hits 3h apart → 1 interval of 3h, span 3h.
        let todayEarly = cal.date(byAdding: .second, value: -3 * 3600, to: now)!
        let todayLate = now

        let hits = [
            Hit(t: yesterdayMorning, tzOffsetMinutes: tz),
            Hit(t: yesterdayLater,   tzOffsetMinutes: tz),
            Hit(t: todayEarly,       tzOffsetMinutes: tz),
            Hit(t: todayLate,        tzOffsetMinutes: tz),
        ]

        // span = 6h + 3h = 9h, intervals = 2 → avg = 4.5h = 16200s
        let avg = hits.wakingAvgSec(now: now)
        #expect(avg != nil)
        #expect(abs((avg ?? 0) - 16200) < 1)
    }

    @Test("returns nil with no day having 2+ hits")
    func nilWhenSparse() {
        let now = Date()
        let tz = deviceTz()
        let hits = [Hit(t: now, tzOffsetMinutes: tz)]
        #expect(hits.wakingAvgSec(now: now) == nil)
    }
}

@Suite("longestWakingGap append rules")
struct LongestWakingGapTests {
    @Test("updates only when both hits share a waking day")
    @MainActor
    func sameDayOnly() async throws {
        // Use an in-memory SwiftData container so the test doesn't touch real storage.
        let schema = Schema([Hit.self, Records.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = try HitStore(context: ModelContext(container))

        let cal = Calendar(identifier: .gregorian)
        let tz = deviceTz()

        // Pick a fixed reference moment within today so the wakingDayKey is stable.
        // 3pm-ish today, then 6pm-ish today (3h gap, same waking day),
        // then 2am tomorrow (8h gap from 6pm but crosses 4am cutoff).
        let now = Date()
        let day = cal.startOfDay(for: now)
        let threePM = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        let sixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
        let twoAMTomorrow = cal.date(byAdding: .hour, value: 11, to: cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!)!
        // (15:00 + 11h = 02:00 next day)

        try store.append(Hit(t: threePM, tzOffsetMinutes: tz))
        try store.append(Hit(t: sixPM,   tzOffsetMinutes: tz))
        // After two same-day hits 3h apart, longest waking should be 3h.
        #expect(abs(store.longestWakingGapSec - 3 * 3600) < 1)

        try store.append(Hit(t: twoAMTomorrow, tzOffsetMinutes: tz))
        // 6PM → 2AM next day = 8h, but they belong to different waking-day buckets
        // (6PM is today's bucket, 2AM is also today's bucket — wait, 2AM rolls back).
        // 2AM is < 4AM so it rolls to previous-day bucket = today's waking day.
        // So they DO share a waking day. The gap (8h) should update the record.
        #expect(abs(store.longestWakingGapSec - 8 * 3600) < 1)

        // longestGap (sleep included) tracks the same: 8h.
        #expect(abs(store.longestGapSec - 8 * 3600) < 1)
    }

    @Test("hit at 5am next day does NOT update waking record")
    @MainActor
    func acrossWakingDayBoundary() async throws {
        let schema = Schema([Hit.self, Records.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = try HitStore(context: ModelContext(container))

        let cal = Calendar(identifier: .gregorian)
        let tz = deviceTz()
        let now = Date()
        let day = cal.startOfDay(for: now)
        let elevenPM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        let fiveAMTomorrow = cal.date(byAdding: .hour, value: 6, to: elevenPM)!

        try store.append(Hit(t: elevenPM, tzOffsetMinutes: tz))
        try store.append(Hit(t: fiveAMTomorrow, tzOffsetMinutes: tz))

        // 11PM is today's waking day; 5AM is tomorrow's waking day (>= 4AM).
        // The 6h gap should NOT update longestWakingGap.
        #expect(store.longestWakingGapSec == 0)
        // But longestGap (sleep included) does update.
        #expect(abs(store.longestGapSec - 6 * 3600) < 1)
    }
}

@Suite("rolling window first-hit edge")
struct RollingWindowEdgeTests {
    @Test("first hit older than window starts iteration at window start")
    func oldFirstHit() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        // First hit 60 days ago, then daily hits within the last 5 days
        let veryOld = cal.date(byAdding: .day, value: -60, to: now)!
        var hits = [Hit(t: veryOld, tzOffsetMinutes: tz)]
        for offset in 1...5 {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            hits.append(Hit(t: day, tzOffsetMinutes: tz))
        }
        // Window = 30. veryOld is excluded, the 5 recent days each have 1 hit.
        // Today is excluded. Days iterated = 30.
        // Mean = 5/30
        let avg = hits.avgPerDay(now: now, window: 30)
        #expect(abs(avg - (5.0 / 30.0)) < 0.0001)
    }

    @Test("first hit within window starts iteration at first hit")
    func recentFirstHit() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        // First hit 5 days ago, then daily hits since.
        var hits: [Hit] = []
        for offset in stride(from: 5, through: 1, by: -1) {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            hits.append(Hit(t: day, tzOffsetMinutes: tz))
        }
        // Window = 30, but first hit is only 5 days ago.
        // Days iterated = 5 (from -5 through -1, today excluded). Each has 1 hit.
        // Mean = 5/5 = 1.0
        #expect(hits.avgPerDay(now: now, window: 30) == 1.0)
    }
}
