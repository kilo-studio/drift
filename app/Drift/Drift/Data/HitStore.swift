import Foundation
import SwiftData

@Observable
@MainActor
final class HitStore {
    private let context: ModelContext
    private(set) var hits: [Hit] = []
    private var records: Records

    private let thresholdKey = "drift.session.thresholdSec"

    /// Session threshold in seconds. UI exposes this as a picker (1 / 3 / 5 / 10 / 15 / 30 min).
    var sessionThresholdSec: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: thresholdKey)
            return stored > 0 ? stored : defaultSessionThresholdSec
        }
        set { UserDefaults.standard.set(newValue, forKey: thresholdKey) }
    }

    init(context: ModelContext) throws {
        self.context = context
        if let existing = try context.fetch(FetchDescriptor<Records>()).first {
            self.records = existing
        } else {
            let new = Records()
            context.insert(new)
            try context.save()
            self.records = new
        }
        try reload()
        publishToWidget()
    }

    func reload() throws {
        var descriptor = FetchDescriptor<Hit>()
        descriptor.sortBy = [SortDescriptor(\.t)]
        hits = try context.fetch(descriptor)
    }

    /// Append a hit. Records (`longestGapSec`, `longestWakingGapSec`) only update
    /// when the new hit STARTS a new session — i.e., when its delta from the
    /// previous hit exceeds the session threshold. Intra-session hits don't.
    func append(_ hit: Hit = Hit()) throws {
        let threshold = sessionThresholdSec
        let prevLast = hits.last
        let prevWakingRecord = records.longestWakingGapSec
        var isNewWakingBest = false

        if let last = prevLast {
            let delta = hit.t.timeIntervalSince(last.t)
            if delta > threshold {
                if delta > records.longestGapSec { records.longestGapSec = delta }
                if last.wakingDayKey == hit.wakingDayKey, delta > records.longestWakingGapSec {
                    records.longestWakingGapSec = delta
                    isNewWakingBest = records.longestWakingGapSec > prevWakingRecord
                }
            }
        }
        context.insert(hit)
        try context.save()
        hits.append(hit)
        publishToWidget()

        let notifContext = HitNotificationContext(
            now: hit.t,
            previousHitDate: prevLast?.t,
            totalHits: hits.count,
            wakingAvgSec: hits.wakingAvgSec(threshold: threshold),
            longestWakingGapSec: records.longestWakingGapSec,
            isNewWakingBest: isNewWakingBest
        )
        Task {
            await NotificationScheduler.reschedule(after: notifContext)
        }
    }

    func remove(_ hit: Hit) throws {
        context.delete(hit)
        try context.save()
        try reload()
        publishToWidget()
    }

    /// Mirrors the slice of state the widget renders from.
    private func publishToWidget() {
        WidgetBridge.write(.init(
            lastHit: hits.lastHitDate,
            wakingAvgSec: hits.wakingAvgSec(threshold: sessionThresholdSec),
            longestWakingGapSec: records.longestWakingGapSec,
            longestGapSec: records.longestGapSec
        ))
    }

    // MARK: - Records (persisted, session-level gaps)

    var longestGapSec: TimeInterval { records.longestGapSec }
    var longestWakingGapSec: TimeInterval { records.longestWakingGapSec }

    // MARK: - Live metrics — session-level (frequency, drives spirit + dashboard)

    var lastHit: Hit? { hits.last }
    var lastHitDate: Date? { hits.lastHitDate }
    func lastSessionEnd() -> Date? { hits.lastSessionEnd(threshold: sessionThresholdSec) }

    func todaySessionCount(now: Date = .now) -> Int {
        hits.todaySessionCount(now: now, threshold: sessionThresholdSec)
    }
    func avgSessionsPerDay(now: Date = .now, window: Int = 30) -> Double {
        hits.avgSessionsPerDay(now: now, window: window, threshold: sessionThresholdSec)
    }
    func wakingAvgSec(now: Date = .now, window: Int = 30) -> TimeInterval? {
        hits.wakingAvgSec(now: now, window: window, threshold: sessionThresholdSec)
    }
    func sessionsByHour() -> [Int] { hits.sessionsByHour(threshold: sessionThresholdSec) }
    func dailySessionCounts(lastN: Int = 14, now: Date = .now) -> [DailyCount] {
        hits.dailySessionCounts(lastN: lastN, now: now, threshold: sessionThresholdSec)
    }
    func todayStretches(now: Date = .now) -> [(Date, TimeInterval)] {
        hits.todayStretches(now: now, threshold: sessionThresholdSec)
    }
    func rollingAvg(window: Int = 7, lastN: Int = 30, now: Date = .now) -> [(Date, TimeInterval)] {
        hits.rollingAvg(window: window, lastN: lastN, now: now, threshold: sessionThresholdSec)
    }

    // MARK: - Live metrics — hit-level (intensity, secondary display + achievements)

    func todayHitCount(now: Date = .now) -> Int { hits.todayHitCount(now: now) }
    func avgHitsPerSession(now: Date = .now, window: Int = 30) -> Double? {
        hits.avgHitsPerSession(now: now, window: window, threshold: sessionThresholdSec)
    }
}
