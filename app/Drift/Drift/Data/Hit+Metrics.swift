import Foundation

struct DailyCount: Equatable {
    let date: Date
    let count: Int
    let isToday: Bool
}

extension Array where Element == Hit {
    func sortedByTime() -> [Hit] { sorted { $0.t < $1.t } }

    var lastHitDate: Date? { sortedByTime().last?.t }

    /// Hits whose logged-local date falls within the last `window` days.
    /// `includeToday: false` matches `avgSessionsPerDay`'s window;
    /// `true` matches `wakingAvgSec`'s.
    func hitsInRollingWindow(includeToday: Bool, now: Date = .now, window: Int = 30) -> [Hit] {
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -window, to: todayStart)!
        let windowStartKey = deviceLocalDateKey(windowStart)
        let endKey = deviceLocalDateKey(todayStart)
        return filter { hit in
            let k = hit.logLocalDateKey
            return k >= windowStartKey && (includeToday || k < endKey)
        }
    }

    // MARK: - Hit-level (intensity / secondary display)

    /// Hits whose logged-local date matches today's device-local date.
    /// Used as the secondary "Y hits" subtitle on the today card.
    func todayHitCount(now: Date = .now) -> Int {
        let todayKey = deviceLocalDateKey(now)
        return filter { $0.logLocalDateKey == todayKey }.count
    }

    /// Average hits per session over the rolling window (intensity axis).
    /// Returns nil if no sessions exist in the window.
    func avgHitsPerSession(now: Date = .now, window: Int = 30, threshold: TimeInterval = defaultSessionThresholdSec) -> Double? {
        let sessions = hitsInRollingWindow(includeToday: true, now: now, window: window)
            .sessions(threshold: threshold)
        guard !sessions.isEmpty else { return nil }
        let totalHits = sessions.reduce(0) { $0 + $1.count }
        return Double(totalHits) / Double(sessions.count)
    }

    /// Average hits per day over the last `window` days, excluding today.
    /// Mirrors `avgSessionsPerDay`'s windowing rules but counts hits not sessions.
    func avgHitsPerDay(now: Date = .now, window: Int = 30) -> Double {
        guard !isEmpty else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -window, to: todayStart)!
        let endKey = deviceLocalDateKey(todayStart)
        let windowStartKey = deviceLocalDateKey(windowStart)

        let countsByKey = Dictionary(grouping: self, by: \.logLocalDateKey).mapValues(\.count)
        let sortedHits = sortedByTime()
        guard let firstKey = sortedHits.first?.logLocalDateKey else { return 0 }
        let actualStartKey = Swift.max(firstKey, windowStartKey)

        var total = 0
        var dayCount = 0
        var cur = parseDeviceDateKey(actualStartKey)
        while deviceLocalDateKey(cur) < endKey {
            total += countsByKey[deviceLocalDateKey(cur), default: 0]
            dayCount += 1
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return dayCount == 0 ? 0 : Double(total) / Double(dayCount)
    }

    // MARK: - Session-level (frequency / primary)

    /// Sessions whose start falls in today's device-local date.
    func todaySessionCount(now: Date = .now, threshold: TimeInterval = defaultSessionThresholdSec) -> Int {
        let todayKey = deviceLocalDateKey(now)
        return sessions(threshold: threshold).filter { $0.logLocalDateKey == todayKey }.count
    }

    /// Mean of per-day SESSION counts over the last `window` days, excluding today.
    /// Iteration starts from the later of (first hit's day, window start).
    func avgSessionsPerDay(now: Date = .now, window: Int = 30, threshold: TimeInterval = defaultSessionThresholdSec) -> Double {
        guard !isEmpty else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -window, to: todayStart)!
        let endKey = deviceLocalDateKey(todayStart)
        let windowStartKey = deviceLocalDateKey(windowStart)

        let allSessions = sessions(threshold: threshold)
        let countsByKey = Dictionary(grouping: allSessions, by: \.logLocalDateKey).mapValues(\.count)
        let sortedHits = sortedByTime()
        guard let firstKey = sortedHits.first?.logLocalDateKey else { return 0 }
        let actualStartKey = Swift.max(firstKey, windowStartKey)

        var total = 0
        var dayCount = 0
        var cur = parseDeviceDateKey(actualStartKey)
        while deviceLocalDateKey(cur) < endKey {
            total += countsByKey[deviceLocalDateKey(cur), default: 0]
            dayCount += 1
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return dayCount == 0 ? 0 : Double(total) / Double(dayCount)
    }

    /// Average gap BETWEEN sessions within waking-day buckets, across the last `window`
    /// days INCLUDING today. nil if no waking-day bucket has 2+ sessions.
    func wakingAvgSec(now: Date = .now, window: Int = 7, threshold: TimeInterval = defaultSessionThresholdSec) -> TimeInterval? {
        let inWindow = hitsInRollingWindow(includeToday: true, now: now, window: window)
        let allSessions = inWindow.sessions(threshold: threshold)
        let buckets = Dictionary(grouping: allSessions, by: \.wakingDayKey)
        var totalGap: TimeInterval = 0
        var totalIntervals = 0
        for (_, daySessions) in buckets where daySessions.count >= 2 {
            let sorted = daySessions.sorted { $0.start < $1.start }
            for i in 1..<sorted.count {
                totalGap += sorted[i].start.timeIntervalSince(sorted[i-1].end)
            }
            totalIntervals += sorted.count - 1
        }
        guard totalIntervals > 0 else { return nil }
        return totalGap / Double(totalIntervals)
    }

    /// 24 buckets, hour-of-day distribution of session START times (logged-local hour).
    func sessionsByHour(threshold: TimeInterval = defaultSessionThresholdSec) -> [Int] {
        var counts: [Int] = .init(repeating: 0, count: 24)
        for session in sessions(threshold: threshold) {
            counts[utcCalendar.component(.hour, from: session.hits.first!.local)] += 1
        }
        return counts
    }

    /// Per-day SESSION counts for the last `lastN` days (oldest first).
    func dailySessionCounts(lastN: Int = 14, now: Date = .now, threshold: TimeInterval = defaultSessionThresholdSec) -> [DailyCount] {
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let countsByKey = Dictionary(grouping: sessions(threshold: threshold), by: \.logLocalDateKey).mapValues(\.count)
        var result: [DailyCount] = []
        for offset in stride(from: lastN - 1, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            let key = deviceLocalDateKey(day)
            result.append(DailyCount(date: day, count: countsByKey[key, default: 0], isToday: offset == 0))
        }
        return result
    }

    /// Gaps BETWEEN sessions within today's waking-day bucket.
    /// Each entry is (next session's start, gap from previous session's end).
    func todayStretches(now: Date = .now, threshold: TimeInterval = defaultSessionThresholdSec) -> [(Date, TimeInterval)] {
        stretches(forWakingDayKey: currentWakingDayKey(now), threshold: threshold)
    }

    /// Average gap BETWEEN sessions within today's waking-day bucket. nil if today
    /// has fewer than 2 sessions.
    func todayWakingAvgSec(now: Date = .now, threshold: TimeInterval = defaultSessionThresholdSec) -> TimeInterval? {
        let gaps = todayStretches(now: now, threshold: threshold)
        guard !gaps.isEmpty else { return nil }
        let total = gaps.reduce(0.0) { $0 + $1.1 }
        return total / Double(gaps.count)
    }

    /// Stretches for an arbitrary device-local day. The `dayKey` should be the
    /// "yyyy-MM-dd" of that day in device-local time (matching how
    /// `Session.wakingDayKey` is computed for hits in the same waking day).
    func stretches(forWakingDayKey dayKey: String,
                   threshold: TimeInterval = defaultSessionThresholdSec) -> [(Date, TimeInterval)] {
        let daySessions = sessions(threshold: threshold)
            .filter { $0.wakingDayKey == dayKey }
            .sorted { $0.start < $1.start }
        guard daySessions.count >= 2 else { return [] }
        var result: [(Date, TimeInterval)] = []
        for i in 1..<daySessions.count {
            let gap = daySessions[i].start.timeIntervalSince(daySessions[i-1].end)
            result.append((daySessions[i].start, gap))
        }
        return result
    }

    /// Rolling average gap BETWEEN sessions across `window` days, computed once per
    /// day from the first hit's day through today. Last `lastN` data points returned.
    func rollingAvg(window: Int = 7, lastN: Int = 30, now: Date = .now, threshold: TimeInterval = defaultSessionThresholdSec) -> [(Date, TimeInterval)] {
        let allSessions = sessions(threshold: threshold)
        guard allSessions.count >= 2 else { return [] }
        let cal = Calendar(identifier: .gregorian)
        let endDay = cal.startOfDay(for: now)
        let firstDay = cal.startOfDay(for: allSessions.first!.start.addingTimeInterval(TimeInterval(self.first!.tzOffsetMinutes * 60)))
        var result: [(Date, TimeInterval)] = []
        var day = firstDay
        while day <= endDay {
            let windowEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: day)!
            let windowStart = cal.date(byAdding: .day, value: -window, to: day)!
            let windowSessions = allSessions.filter { $0.end >= windowStart && $0.start <= windowEnd }
            if windowSessions.count >= 2 {
                let sorted = windowSessions.sorted { $0.start < $1.start }
                var totalGap: TimeInterval = 0
                for i in 1..<sorted.count {
                    totalGap += sorted[i].start.timeIntervalSince(sorted[i-1].end)
                }
                let avg = totalGap / Double(sorted.count - 1)
                result.append((day, avg))
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return [(Date, TimeInterval)](result.suffix(lastN))
    }

    /// End time of the most recent session (drives the spirit's ratio).
    func lastSessionEnd(threshold: TimeInterval = defaultSessionThresholdSec) -> Date? {
        sessions(threshold: threshold).last?.end
    }
}

private func parseDeviceDateKey(_ key: String) -> Date {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return .now }
    var comps = DateComponents()
    comps.year = parts[0]
    comps.month = parts[1]
    comps.day = parts[2]
    return Calendar(identifier: .gregorian).date(from: comps) ?? .now
}
