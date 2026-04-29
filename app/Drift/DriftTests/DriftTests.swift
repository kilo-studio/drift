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

private let fiveMin: TimeInterval = 5 * 60

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
        #expect(hit("2025-01-15T04:00:00Z", tz: -180).wakingDayKey == "2025-01-14")
        #expect(hit("2025-01-15T06:59:00Z", tz: -180).wakingDayKey == "2025-01-14")
        #expect(hit("2025-01-15T07:00:00Z", tz: -180).wakingDayKey == "2025-01-15")
    }

    @Test("logLocalDateKey ignores the cutoff")
    func logKeyIgnoresCutoff() {
        #expect(hit("2025-01-15T02:00:00Z", tz: 0).logLocalDateKey == "2025-01-15")
        #expect(hit("2025-01-15T17:00:00Z", tz: 0).logLocalDateKey == "2025-01-15")
    }
}

// MARK: - Sessions

@Suite("Session derivation from hits")
struct SessionTests {
    @Test("single hit yields one session of count 1")
    func singleHit() {
        let h = hit("2025-01-15T12:00:00Z")
        let s = [h].sessions(threshold: fiveMin)
        #expect(s.count == 1)
        #expect(s.first?.count == 1)
        #expect(s.first?.start == h.t)
        #expect(s.first?.end == h.t)
    }

    @Test("hits within threshold cluster into one session")
    func withinThreshold() {
        let hits = [
            hit("2025-01-15T12:00:00Z"),
            hit("2025-01-15T12:02:00Z"),  // +2min
            hit("2025-01-15T12:04:30Z"),  // +2.5min
        ]
        let s = hits.sessions(threshold: fiveMin)
        #expect(s.count == 1)
        #expect(s.first?.count == 3)
    }

    @Test("hits beyond threshold split into separate sessions")
    func beyondThreshold() {
        let hits = [
            hit("2025-01-15T12:00:00Z"),
            hit("2025-01-15T12:06:00Z"),  // +6min, > 5min threshold
            hit("2025-01-15T12:08:00Z"),  // +2min, same session as previous
        ]
        let s = hits.sessions(threshold: fiveMin)
        #expect(s.count == 2)
        #expect(s[0].count == 1)
        #expect(s[1].count == 2)
    }

    @Test("gap exactly at threshold stays in same session")
    func exactThreshold() {
        let hits = [
            hit("2025-01-15T12:00:00Z"),
            hit("2025-01-15T12:05:00Z"),  // exactly +5min
        ]
        let s = hits.sessions(threshold: fiveMin)
        #expect(s.count == 1)
        #expect(s.first?.count == 2)
    }

    @Test("session crossing 4am inherits first hit's waking-day bucket")
    func crossesFourAM() {
        // 3:45am UTC and 4:15am UTC, tz=0. Three minutes apart → same session.
        let hits = [
            hit("2025-01-15T03:45:00Z"),
            hit("2025-01-15T03:48:00Z"),
            hit("2025-01-15T04:15:00Z"),
        ]
        // Wait — 3:48 to 4:15 is 27min, > 5min threshold. Use closer hits.
        let tightHits = [
            hit("2025-01-15T03:58:00Z"),
            hit("2025-01-15T04:01:00Z"),  // +3min
        ]
        let s = tightHits.sessions(threshold: fiveMin)
        #expect(s.count == 1)
        // First hit's waking day = 2025-01-14 (rolls back); session inherits that.
        #expect(s.first?.wakingDayKey == "2025-01-14")
        _ = hits  // silence unused
    }
}

// MARK: - avgSessionsPerDay

@Suite("avgSessionsPerDay excludes today")
struct AvgSessionsPerDayTests {
    @Test("today's sessions do not count toward the mean")
    func excludesToday() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        let oneDayAgo = cal.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now)!

        // 3 hits two days ago at the same instant (1 session)
        // 1 hit yesterday (1 session)
        // 3 hits today, well-separated → still excluded
        let hits = [
            Hit(t: twoDaysAgo, tzOffsetMinutes: tz),
            Hit(t: twoDaysAgo, tzOffsetMinutes: tz),
            Hit(t: twoDaysAgo, tzOffsetMinutes: tz),
            Hit(t: oneDayAgo,  tzOffsetMinutes: tz),
            Hit(t: now,        tzOffsetMinutes: tz),
            Hit(t: now,        tzOffsetMinutes: tz),
            Hit(t: now,        tzOffsetMinutes: tz),
        ]
        // 2 days iterated, 1 session each → avg = 1.0
        #expect(hits.avgSessionsPerDay(now: now, threshold: fiveMin) == 1.0)
    }

    @Test("empty array yields 0")
    func empty() {
        #expect([Hit]().avgSessionsPerDay() == 0)
    }
}

// MARK: - wakingAvgSec (between sessions)

@Suite("wakingAvgSec between sessions, includes today")
struct WakingAvgSecTests {
    @Test("inter-session gaps are averaged across waking-day buckets")
    func betweenSessions() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()

        // Yesterday: session A (10am, 10:01am — 1min apart, same session),
        //            session B (4pm, 4:02pm — same session).
        //            Inter-session gap = 4pm - 10:01am = ~5h59min.
        let yMorning = cal.date(byAdding: .day, value: -1, to: now)!
        let yMorning2 = cal.date(byAdding: .second, value: 60, to: yMorning)!
        let yAfternoon = cal.date(byAdding: .second, value: 6 * 3600, to: yMorning)!
        let yAfternoon2 = cal.date(byAdding: .second, value: 120, to: yAfternoon)!

        // Today: session C (now -3h), session D (now). Gap = 3h.
        let tEarly = cal.date(byAdding: .second, value: -3 * 3600, to: now)!
        let tLate = now

        let hits = [
            Hit(t: yMorning,    tzOffsetMinutes: tz),
            Hit(t: yMorning2,   tzOffsetMinutes: tz),
            Hit(t: yAfternoon,  tzOffsetMinutes: tz),
            Hit(t: yAfternoon2, tzOffsetMinutes: tz),
            Hit(t: tEarly,      tzOffsetMinutes: tz),
            Hit(t: tLate,       tzOffsetMinutes: tz),
        ]

        // Yesterday gap: 4pm - 10:01am = 6h * 3600 - 60 = 21540s
        // Today gap: 3h = 10800s
        // Total = 32340s, intervals = 2 → avg = 16170s
        let avg = hits.wakingAvgSec(now: now, threshold: fiveMin)
        #expect(avg != nil)
        #expect(abs((avg ?? 0) - 16170) < 5)
    }

    @Test("returns nil if no waking-day bucket has 2+ sessions")
    func nilWhenSparse() {
        let now = Date()
        let tz = deviceTz()
        let hits = [Hit(t: now, tzOffsetMinutes: tz)]
        #expect(hits.wakingAvgSec(now: now) == nil)
    }
}

// MARK: - longestWakingGap with session threshold gating

@Suite("longestWakingGap gated by session threshold")
struct LongestWakingGapTests {
    @Test("intra-session hits do NOT update the record")
    @MainActor
    func intraSessionNoUpdate() async throws {
        let schema = Schema([Hit.self, Records.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = try HitStore(context: ModelContext(container))

        let cal = Calendar(identifier: .gregorian)
        let tz = deviceTz()
        let day = cal.startOfDay(for: Date())
        let threePM = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        let threeOhTwo = cal.date(byAdding: .second, value: 120, to: threePM)!  // +2min, same session

        try store.append(Hit(t: threePM, tzOffsetMinutes: tz))
        try store.append(Hit(t: threeOhTwo, tzOffsetMinutes: tz))

        // 2-min gap is within the 5-min default threshold → no record update.
        #expect(store.longestWakingGapSec == 0)
        #expect(store.longestGapSec == 0)
    }

    @Test("inter-session gap within a waking day updates the waking record")
    @MainActor
    func interSessionSameDay() async throws {
        let schema = Schema([Hit.self, Records.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = try HitStore(context: ModelContext(container))

        let cal = Calendar(identifier: .gregorian)
        let tz = deviceTz()
        let day = cal.startOfDay(for: Date())
        let threePM = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        let sixPM   = cal.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
        let twoAMTomorrow = cal.date(byAdding: .hour, value: 11, to: threePM)!  // 02:00 next day

        try store.append(Hit(t: threePM, tzOffsetMinutes: tz))
        try store.append(Hit(t: sixPM,   tzOffsetMinutes: tz))
        #expect(abs(store.longestWakingGapSec - 3 * 3600) < 1)

        try store.append(Hit(t: twoAMTomorrow, tzOffsetMinutes: tz))
        // 2am rolls back to today's waking day → same bucket → 8h record.
        #expect(abs(store.longestWakingGapSec - 8 * 3600) < 1)
        #expect(abs(store.longestGapSec - 8 * 3600) < 1)
    }

    @Test("inter-session gap across the 4am boundary updates only longestGap")
    @MainActor
    func acrossWakingDayBoundary() async throws {
        let schema = Schema([Hit.self, Records.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = try HitStore(context: ModelContext(container))

        let cal = Calendar(identifier: .gregorian)
        let tz = deviceTz()
        let day = cal.startOfDay(for: Date())
        let elevenPM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        let fiveAMTomorrow = cal.date(byAdding: .hour, value: 6, to: elevenPM)!

        try store.append(Hit(t: elevenPM, tzOffsetMinutes: tz))
        try store.append(Hit(t: fiveAMTomorrow, tzOffsetMinutes: tz))

        #expect(store.longestWakingGapSec == 0)
        #expect(abs(store.longestGapSec - 6 * 3600) < 1)
    }
}

// MARK: - Rolling window edge

@Suite("rolling window first-hit edge")
struct RollingWindowEdgeTests {
    @Test("first hit older than window starts iteration at window start")
    func oldFirstHit() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        let veryOld = cal.date(byAdding: .day, value: -60, to: now)!
        var hits = [Hit(t: veryOld, tzOffsetMinutes: tz)]
        for offset in 1...5 {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            hits.append(Hit(t: day, tzOffsetMinutes: tz))
        }
        // Window=30, today excluded. 5 sessions in window. avg = 5/30.
        let avg = hits.avgSessionsPerDay(now: now, window: 30, threshold: fiveMin)
        #expect(abs(avg - (5.0 / 30.0)) < 0.0001)
    }

    @Test("first hit within window starts iteration at first hit")
    func recentFirstHit() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let tz = deviceTz()
        var hits: [Hit] = []
        for offset in stride(from: 5, through: 1, by: -1) {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            hits.append(Hit(t: day, tzOffsetMinutes: tz))
        }
        #expect(hits.avgSessionsPerDay(now: now, window: 30, threshold: fiveMin) == 1.0)
    }
}
