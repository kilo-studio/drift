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
    /// `includeToday: false` matches `avgPerDay`'s window; `true` matches `wakingAvgSec`'s.
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

    /// Hits whose logged-local date matches today's device-local date.
    func todayCount(now: Date = .now) -> Int {
        let todayKey = deviceLocalDateKey(now)
        return filter { $0.logLocalDateKey == todayKey }.count
    }

    /// Mean of per-day counts over the last `window` days, excluding today.
    /// Iteration starts from the later of (first hit's day, window start) so
    /// pre-history days don't dilute the average with zeros.
    func avgPerDay(now: Date = .now, window: Int = 30) -> Double {
        guard !isEmpty else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -window, to: todayStart)!
        let endKey = deviceLocalDateKey(todayStart)
        let windowStartKey = deviceLocalDateKey(windowStart)

        let countsByKey = Dictionary(grouping: self, by: \.logLocalDateKey).mapValues(\.count)
        let sorted = sortedByTime()
        guard let firstKey = sorted.first?.logLocalDateKey else { return 0 }
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

    /// Average gap between consecutive hits within waking-day buckets,
    /// across the last `window` days INCLUDING today. nil if no day has 2+ hits.
    func wakingAvgSec(now: Date = .now, window: Int = 30) -> TimeInterval? {
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .day, value: -window, to: todayStart)!
        let windowStartKey = deviceLocalDateKey(windowStart)
        let inWindow = filter { $0.logLocalDateKey >= windowStartKey }
        let buckets = Dictionary(grouping: inWindow, by: \.wakingDayKey)
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

    /// 24 buckets, hour-of-day distribution across all hits using each hit's logged-local hour.
    func hitsByHour() -> [Int] {
        var counts: [Int] = .init(repeating: 0, count: 24)
        for hit in self {
            counts[utcCalendar.component(.hour, from: hit.local)] += 1
        }
        return counts
    }

    /// Per-day counts for the last `lastN` days (oldest first). Today is the last entry.
    func dailyCounts(lastN: Int = 14, now: Date = .now) -> [DailyCount] {
        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: now)
        let countsByKey = Dictionary(grouping: self, by: \.logLocalDateKey).mapValues(\.count)
        var result: [DailyCount] = []
        for offset in stride(from: lastN - 1, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            let key = deviceLocalDateKey(day)
            result.append(DailyCount(date: day, count: countsByKey[key, default: 0], isToday: offset == 0))
        }
        return result
    }

    /// Stretches between consecutive hits within today's waking-day bucket.
    /// Each entry is (timestamp of the later hit, gap duration).
    func todayStretches(now: Date = .now) -> [(Date, TimeInterval)] {
        let todayKey = currentWakingDayKey(now)
        let todayHits = filter { $0.wakingDayKey == todayKey }.sorted { $0.t < $1.t }
        var result: [(Date, TimeInterval)] = []
        for i in 1..<todayHits.count {
            let gap = todayHits[i].t.timeIntervalSince(todayHits[i-1].t)
            result.append((todayHits[i].t, gap))
        }
        return result
    }

    /// Rolling average gap across `window` days, computed once per day from the first
    /// hit's day through today. Last `lastN` data points returned, oldest first.
    func rollingAvg(window: Int = 7, lastN: Int = 30, now: Date = .now) -> [(Date, TimeInterval)] {
        guard count >= 2 else { return [] }
        let sorted = sortedByTime()
        let cal = Calendar(identifier: .gregorian)
        let endDay = cal.startOfDay(for: now)
        let firstHitDay = cal.startOfDay(for: sorted.first!.local)
        var result: [(Date, TimeInterval)] = []
        var day = firstHitDay
        while day <= endDay {
            let windowEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: day)!
            let windowStart = cal.date(byAdding: .day, value: -window, to: day)!
            let windowHits = sorted.filter { $0.t >= windowStart && $0.t <= windowEnd }
            if windowHits.count >= 2 {
                var totalGap: TimeInterval = 0
                for i in 1..<windowHits.count {
                    totalGap += windowHits[i].t.timeIntervalSince(windowHits[i-1].t)
                }
                let avg = totalGap / Double(windowHits.count - 1)
                result.append((day, avg))
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return [(Date, TimeInterval)](result.suffix(lastN))
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
