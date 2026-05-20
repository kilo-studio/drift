import Foundation
import SwiftData

@Observable
@MainActor
final class HitStore {
    private let context: ModelContext
    private(set) var hits: [Hit] = []
    private var records: Records

    private let thresholdKey = "drift.session.thresholdSec"
    private let rollingWindowKey = "drift.rollingWindowDays"
    private let useSessionsKey = "drift.useSessions"
    // Sleep-window keys live in Hit+DateKeys.swift so the date-key free functions
    // can read them without taking HitStore as a dependency. Mirrored here as
    // observable stored properties so settings UI can bind two-way.

    /// Session threshold in seconds. UI exposes this as a picker (1 / 3 / 5 / 10 / 15 / 30 min).
    /// Stored as an observable property so dashboard views reactively update when the
    /// settings picker changes it. `didSet` mirrors to UserDefaults and recomputes records,
    /// since longest-gap records are session-derived and depend on this threshold.
    var sessionThresholdSec: TimeInterval {
        didSet {
            UserDefaults.standard.set(sessionThresholdSec, forKey: thresholdKey)
            if oldValue != sessionThresholdSec {
                recomputeRecords()
            }
        }
    }

    /// Rolling-average window length in days. Drives the "X-day avg" stat card,
    /// `wakingAvgSec`, `avgSessionsPerDay`, `avgHitsPerDay`, and the rolling-avg chart's
    /// smoothing. Picker exposes 7 / 14 / 30 / 60 (default 7).
    var rollingWindowDays: Int {
        didSet {
            UserDefaults.standard.set(rollingWindowDays, forKey: rollingWindowKey)
        }
    }

    /// Notification preferences (Issue 12). Stored on `HitStore` so settings UI
    /// can `@Bindable` them; `NotificationScheduler` reads the same UserDefaults
    /// keys directly so it doesn't need a HitStore reference. Each `didSet`
    /// cancels pending scheduled notifications so stale schedules don't fire
    /// under new preferences — the next `append` reschedules with current
    /// settings.
    var notifsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notifsEnabled, forKey: driftNotifsEnabledKey)
            NotificationScheduler.cancelPending()
        }
    }
    var notifsImmediateEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notifsImmediateEnabled, forKey: driftNotifsImmediateKey)
        }
    }
    var notifsBeatAverageEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notifsBeatAverageEnabled, forKey: driftNotifsBeatAverageKey)
            NotificationScheduler.cancelPending()
        }
    }
    var notifsBeatRecordEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notifsBeatRecordEnabled, forKey: driftNotifsBeatRecordKey)
            NotificationScheduler.cancelPending()
        }
    }
    var notifsBeatAverageOffsetSec: TimeInterval {
        didSet {
            UserDefaults.standard.set(notifsBeatAverageOffsetSec, forKey: driftNotifsBeatAvgOffsetKey)
            NotificationScheduler.cancelPending()
        }
    }
    var notifsBeatRecordOffsetSec: TimeInterval {
        didSet {
            UserDefaults.standard.set(notifsBeatRecordOffsetSec, forKey: driftNotifsBeatRecordOffsetKey)
            NotificationScheduler.cancelPending()
        }
    }

    /// Hour of day (0–23) when the user typically goes to sleep. Drives the
    /// notification overnight hedge in `NotificationScheduler.isOvernight`.
    /// Default 23 per Issue 12.
    var sleepStartHour: Int {
        didSet {
            UserDefaults.standard.set(sleepStartHour, forKey: driftSleepStartHourKey)
        }
    }

    /// Hour of day (0–23) when the user typically wakes. Drives both the waking-day
    /// cutoff (hits before this hour roll into the previous waking day) and the
    /// overnight hedge. Default 6 per Issue 12. Changing this re-shapes every
    /// waking-day bucket, so `didSet` recomputes the longest-gap records.
    var sleepEndHour: Int {
        didSet {
            UserDefaults.standard.set(sleepEndHour, forKey: driftSleepEndHourKey)
            if oldValue != sleepEndHour {
                recomputeRecords()
            }
        }
    }

    /// Master toggle for session derivation (Issue 16's "Use sessions" setting).
    /// When `true` (default), every gap-based metric collapses rapid hits into sessions
    /// using `sessionThresholdSec`. When `false`, every hit is its own event — implemented
    /// by routing metric calls through `effectiveSessionThreshold`, which returns 0 in that
    /// mode (so `sessions(threshold: 0)` yields one session per hit). `didSet` recomputes
    /// records since longest-gap definitions change with the mode.
    var useSessions: Bool {
        didSet {
            UserDefaults.standard.set(useSessions, forKey: useSessionsKey)
            if oldValue != useSessions {
                recomputeRecords()
            }
        }
    }

    /// Threshold the metric layer actually uses. The user-configured `sessionThresholdSec`
    /// is preserved across toggling so flipping back on restores their chosen value.
    var effectiveSessionThreshold: TimeInterval {
        useSessions ? sessionThresholdSec : 0
    }

    init(context: ModelContext) throws {
        self.context = context

        let storedThreshold = UserDefaults.standard.double(forKey: thresholdKey)
        self.sessionThresholdSec = storedThreshold > 0 ? storedThreshold : defaultSessionThresholdSec
        let storedWindow = UserDefaults.standard.integer(forKey: rollingWindowKey)
        self.rollingWindowDays = storedWindow > 0 ? storedWindow : 7
        // `object(forKey:)` is nil for an unset key — distinguishes that from
        // an explicit `false` so new installs get the `true` default rather than
        // `bool(forKey:)`'s implicit `false`.
        self.useSessions = (UserDefaults.standard.object(forKey: useSessionsKey) as? Bool) ?? true
        self.sleepStartHour = (UserDefaults.standard.object(forKey: driftSleepStartHourKey) as? Int) ?? 23
        self.sleepEndHour = (UserDefaults.standard.object(forKey: driftSleepEndHourKey) as? Int) ?? 6
        self.notifsEnabled = (UserDefaults.standard.object(forKey: driftNotifsEnabledKey) as? Bool) ?? true
        self.notifsImmediateEnabled = (UserDefaults.standard.object(forKey: driftNotifsImmediateKey) as? Bool) ?? true
        self.notifsBeatAverageEnabled = (UserDefaults.standard.object(forKey: driftNotifsBeatAverageKey) as? Bool) ?? true
        self.notifsBeatRecordEnabled = (UserDefaults.standard.object(forKey: driftNotifsBeatRecordKey) as? Bool) ?? true
        self.notifsBeatAverageOffsetSec = (UserDefaults.standard.object(forKey: driftNotifsBeatAvgOffsetKey) as? Double) ?? 60
        self.notifsBeatRecordOffsetSec = (UserDefaults.standard.object(forKey: driftNotifsBeatRecordOffsetKey) as? Double) ?? 0

        if let existing = try context.fetch(FetchDescriptor<Records>()).first {
            self.records = existing
        } else {
            let new = Records()
            context.insert(new)
            try context.save()
            self.records = new
        }
        try reload()
        // Always recompute on launch — cheap O(n) over all sessions, and it
        // re-syncs persisted records with the *current* settings (sleep window,
        // session threshold, use-sessions). Without this, changing those
        // settings between launches would leave records computed under the old
        // configuration. publishToWidget runs at the tail of recomputeRecords.
        recomputeRecords()
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
        let threshold = effectiveSessionThreshold
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
        recomputeRecords()
    }

    /// Inserts a hit at an arbitrary past date — used by the "add forgotten hit"
    /// flow. Walks the same record path as `remove` so longest-gap records reflect
    /// the new neighbor relationships rather than the simple-append rule.
    func addPast(at date: Date) throws {
        let hit = Hit(
            t: date,
            tzOffsetMinutes: TimeZone.current.secondsFromGMT() / 60
        )
        context.insert(hit)
        try context.save()
        try reload()
        recomputeRecords()
    }

    /// Reassigns a hit's timestamp. The session and bucket it belongs to are
    /// derived on read, so they automatically recompute.
    func editHit(_ hit: Hit, to newDate: Date) throws {
        hit.t = newDate
        hit.tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        try context.save()
        try reload()
        recomputeRecords()
    }

    /// Records are persisted but per Issue 17 they describe what's true *now* in
    /// the data. After any edit/delete/add we recompute from current sessions
    /// rather than relying on the simple-append rule used by `append`.
    private func recomputeRecords() {
        let threshold = effectiveSessionThreshold
        let allSessions = hits.sessions(threshold: threshold)

        var longestGap: TimeInterval = 0
        if allSessions.count >= 2 {
            for i in 1..<allSessions.count {
                let gap = allSessions[i].start.timeIntervalSince(allSessions[i-1].end)
                if gap > longestGap { longestGap = gap }
            }
        }

        var longestWaking: TimeInterval = 0
        let byDay = Dictionary(grouping: allSessions, by: \.wakingDayKey)
        for (_, daySessions) in byDay where daySessions.count >= 2 {
            let sorted = daySessions.sorted { $0.start < $1.start }
            for i in 1..<sorted.count {
                let gap = sorted[i].start.timeIntervalSince(sorted[i-1].end)
                if gap > longestWaking { longestWaking = gap }
            }
        }

        records.longestGapSec = longestGap
        records.longestWakingGapSec = longestWaking
        try? context.save()
        publishToWidget()
    }

    /// Wipes all hits and resets the persisted records. Debug-only — used by
    /// settings' "Reset all data" and the "Reload from prototype" path.
    func resetEverything() throws {
        for h in hits {
            context.delete(h)
        }
        records.longestGapSec = 0
        records.longestWakingGapSec = 0
        try context.save()
        try reload()
        publishToWidget()
    }

    /// Inserts many hits in chronological order, walking the same record-update logic
    /// as `append` but without firing notifications or saving per-hit. Used by the
    /// one-time prototype import.
    func bulkImport(_ parsed: [PrototypeImport.ParsedHit]) throws {
        let threshold = effectiveSessionThreshold
        for ph in parsed {
            let hit = Hit(t: ph.t, tzOffsetMinutes: ph.tzOffsetMinutes)
            if let last = hits.last {
                let delta = hit.t.timeIntervalSince(last.t)
                if delta > threshold {
                    if delta > records.longestGapSec { records.longestGapSec = delta }
                    if last.wakingDayKey == hit.wakingDayKey, delta > records.longestWakingGapSec {
                        records.longestWakingGapSec = delta
                    }
                }
            }
            context.insert(hit)
            hits.append(hit)
        }
        try context.save()
        publishToWidget()
    }

    /// Mirrors the slice of state the widget renders from.
    private func publishToWidget() {
        WidgetBridge.write(.init(
            lastHit: hits.lastHitDate,
            wakingAvgSec: hits.wakingAvgSec(threshold: effectiveSessionThreshold),
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
    func lastSessionEnd() -> Date? { hits.lastSessionEnd(threshold: effectiveSessionThreshold) }

    func todaySessionCount(now: Date = .now) -> Int {
        hits.todaySessionCount(now: now, threshold: effectiveSessionThreshold)
    }
    /// `window` defaults to the user-configured `rollingWindowDays` setting.
    func avgSessionsPerDay(now: Date = .now, window: Int? = nil) -> Double {
        hits.avgSessionsPerDay(now: now, window: window ?? rollingWindowDays, threshold: effectiveSessionThreshold)
    }
    /// `window` defaults to the user-configured `rollingWindowDays` setting.
    func wakingAvgSec(now: Date = .now, window: Int? = nil) -> TimeInterval? {
        hits.wakingAvgSec(now: now, window: window ?? rollingWindowDays, threshold: effectiveSessionThreshold)
    }
    func todayWakingAvgSec(now: Date = .now) -> TimeInterval? {
        hits.todayWakingAvgSec(now: now, threshold: effectiveSessionThreshold)
    }
    func sessionsByHour() -> [Int] { hits.sessionsByHour(threshold: effectiveSessionThreshold) }
    func dailySessionCounts(lastN: Int = 14, now: Date = .now) -> [DailyCount] {
        hits.dailySessionCounts(lastN: lastN, now: now, threshold: effectiveSessionThreshold)
    }
    func todayStretches(now: Date = .now) -> [(Date, TimeInterval)] {
        hits.todayStretches(now: now, threshold: effectiveSessionThreshold)
    }
    /// `window` defaults to the user-configured `rollingWindowDays` setting.
    func rollingAvg(window: Int? = nil, lastN: Int = 30, now: Date = .now) -> [(Date, TimeInterval)] {
        hits.rollingAvg(window: window ?? rollingWindowDays, lastN: lastN, now: now, threshold: effectiveSessionThreshold)
    }

    // MARK: - Live metrics — hit-level (intensity, secondary display)

    func todayHitCount(now: Date = .now) -> Int { hits.todayHitCount(now: now) }
    /// `window` defaults to the user-configured `rollingWindowDays` setting.
    func avgHitsPerSession(now: Date = .now, window: Int? = nil) -> Double? {
        hits.avgHitsPerSession(now: now, window: window ?? rollingWindowDays, threshold: effectiveSessionThreshold)
    }
    /// `window` defaults to the user-configured `rollingWindowDays` setting.
    func avgHitsPerDay(now: Date = .now, window: Int? = nil) -> Double {
        hits.avgHitsPerDay(now: now, window: window ?? rollingWindowDays)
    }
}
