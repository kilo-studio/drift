import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// UserDefaults key for the baseline-skip flag. File-scope so both `HitStore`
/// (writing) and `NotificationScheduler` (reading, to suppress the X/N
/// baseline framing) can reach it.
let driftBaselineSkippedKey = "drift.baseline.skipped"

/// JSON snapshot of every logged hit, shaped like the Scriptable prototype
/// payload so it round-trips through `PrototypeImport.parse`. Carried via
/// `ShareLink` from Settings → Data → "export hits".
struct HitsExport: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

/// Emitted by `HitStore.append` when the gap that just ended was a long stretch
/// (≥ `longStretchThresholdSec`). ContentView observes it to show a one-time,
/// shame-free "record saved" acknowledgment, then clears it. `id` is fresh each
/// time so two consecutive long stretches of equal length still re-fire.
struct EndedLongStretch: Equatable {
    let gapSec: TimeInterval
    let wasNewRecord: Bool
    let id: UUID
}

@Observable
@MainActor
final class HitStore {
    private let context: ModelContext
    private(set) var hits: [Hit] = []
    private var records: Records

    /// Set by `append` when a long stretch just ended (the new hit closed a gap
    /// ≥ `longStretchThresholdSec`). ContentView shows the acknowledgment and
    /// then clears this back to nil. Not persisted — it's a transient signal.
    var endedLongStretch: EndedLongStretch?

    private let thresholdKey = "drift.session.thresholdSec"
    private let rollingWindowKey = "drift.rollingWindowDays"
    private let useSessionsKey = "drift.useSessions"

    /// How many of the user's chosen unit (sessions if `useSessions`, else hits)
    /// before the rolling average has enough samples to drive a meaningful
    /// spirit ratio. Drives the pre-baseline empty state, the X/N framing in
    /// the immediate notification, and the gate on scheduled notifications.
    static let baselineTarget = 5

    /// Once "free for" (now − last session end) reaches this, the home screen
    /// reframes into long-stretch mode — the frequency dashboard stops making
    /// sense (averages go stale, daily counts hit zero) and the durable
    /// "free for X" timer takes over. A full day is the human-scale threshold
    /// the user thinks in ("more than a day? a week?").
    static let longStretchThresholdSec: TimeInterval = 24 * 3600
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

    /// Persisted "user opted to skip the baseline period." Once set, the home
    /// dashboard switches to the normal post-baseline UI even with zero hits
    /// and notifications behave as usual (no X/5 framing). Reset clears it.
    var baselineSkipped: Bool {
        didSet {
            UserDefaults.standard.set(baselineSkipped, forKey: driftBaselineSkippedKey)
        }
    }

    /// Count of the unit the user picked in onboarding — sessions if
    /// `useSessions`, otherwise individual hits. Drives the donut on the
    /// pre-baseline home and the X/N framing in notifications.
    var baselineCount: Int {
        useSessions ? hits.sessions(threshold: effectiveSessionThreshold).count : hits.count
    }

    /// Whether the user is past the establishing-baseline period. True once
    /// `baselineCount >= baselineTarget`, or immediately when the user taps
    /// Skip. Drives History tab visibility and home-view branching.
    var isBaselineEstablished: Bool {
        baselineSkipped || baselineCount >= Self.baselineTarget
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
        self.notifsBeatAverageOffsetSec = (UserDefaults.standard.object(forKey: driftNotifsBeatAvgOffsetKey) as? Double) ?? 300
        self.notifsBeatRecordOffsetSec = (UserDefaults.standard.object(forKey: driftNotifsBeatRecordOffsetKey) as? Double) ?? 0
        self.baselineSkipped = UserDefaults.standard.bool(forKey: driftBaselineSkippedKey)

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
        let prevOverallRecord = records.longestGapSec
        var isNewWakingBest = false
        var isNewOverallBest = false

        if let last = prevLast {
            let delta = hit.t.timeIntervalSince(last.t)
            if delta > threshold {
                if delta > records.longestGapSec {
                    records.longestGapSec = delta
                    isNewOverallBest = records.longestGapSec > prevOverallRecord
                }
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

        // If this hit closed a long stretch, surface a one-time acknowledgment.
        // Framed (in the UI) as a kept record, never a broken streak — the
        // longest-gap record above is already persisted and only ever grows.
        if let last = prevLast {
            let endedGap = hit.t.timeIntervalSince(last.t)
            if endedGap >= Self.longStretchThresholdSec {
                endedLongStretch = EndedLongStretch(gapSec: endedGap, wasNewRecord: isNewOverallBest, id: UUID())
            }
        }

        let notifContext = HitNotificationContext(
            now: hit.t,
            previousHitDate: prevLast?.t,
            totalHits: hits.count,
            wakingAvgSec: hits.wakingAvgSec(threshold: threshold),
            longestWakingGapSec: records.longestWakingGapSec,
            longestGapSec: records.longestGapSec,
            isNewWakingBest: isNewWakingBest,
            isNewOverallBest: isNewOverallBest
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
        // Re-run onboarding and the baseline period next launch — a reset
        // should mean a real reset, not just a data wipe leaving the user
        // staring at an empty post-baseline dashboard.
        UserDefaults.standard.removeObject(forKey: driftOnboardingCompleteKey)
        baselineSkipped = false
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

    /// Snapshot every hit + records into a JSON file matching the prototype
    /// payload shape (`{ hits: [{t, tz}], longestGap, longestWakingGap }`) so the
    /// export round-trips through `PrototypeImport.parse` if it ever needs to
    /// be re-imported. Filename is timestamped so multiple exports don't collide.
    func makeHitsExport() -> HitsExport {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let hitDicts: [[String: Any]] = hits.map { hit in
            ["t": iso.string(from: hit.t), "tz": hit.tzOffsetMinutes]
        }
        let root: [String: Any] = [
            "hits": hitDicts,
            "longestGap": records.longestGapSec,
            "longestWakingGap": records.longestWakingGapSec
        ]
        let data = (try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data()

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd-HHmmss"
        return HitsExport(data: data, filename: "drift-export-\(stamp.string(from: Date())).json")
    }

    /// Replace **all** existing hits + records with an imported snapshot.
    /// Destructive — call sites confirm with the user first. Unlike
    /// `resetEverything` this leaves onboarding/baseline state untouched, since
    /// the user is restoring data, not starting over. Gap records are rebuilt
    /// by `bulkImport`'s delta walk, with the file's stored records kept as a
    /// floor in case they exceed what the restored hits alone yield.
    func replaceWithImport(_ parsed: PrototypeImport.Parsed) throws {
        for h in hits { context.delete(h) }
        records.longestGapSec = 0
        records.longestWakingGapSec = 0
        try context.save()
        try reload()
        try bulkImport(parsed.hits)
        if parsed.longestGapSec > records.longestGapSec { records.longestGapSec = parsed.longestGapSec }
        if let w = parsed.longestWakingGapSec, w > records.longestWakingGapSec { records.longestWakingGapSec = w }
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

    /// The from→to dates of the longest gap between completed sessions — used to
    /// label the "longest drift" card. Excludes the current ongoing drift (no
    /// closing session yet), so mid-drift this returns the previous best, which
    /// is what we want to show as the number to beat. nil with < 2 sessions.
    func longestGapBounds() -> (from: Date, to: Date)? {
        let sessions = hits.sessions(threshold: effectiveSessionThreshold)
        guard sessions.count >= 2 else { return nil }
        var best: TimeInterval = 0
        var bounds: (from: Date, to: Date)?
        for i in 1..<sessions.count {
            let gap = sessions[i].start.timeIntervalSince(sessions[i - 1].end)
            if gap > best {
                best = gap
                bounds = (sessions[i - 1].end, sessions[i].start)
            }
        }
        return bounds
    }

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

// MARK: - Debug scenario seeding

#if DEBUG
/// Preset datasets for jumping between the home screen's modes/states while
/// developing. Surfaced as a debug-only card in Settings.
enum DebugScenario: String, CaseIterable, Identifiable {
    case fresh
    case baselinePartial
    case normal
    case longDay
    case longWeek
    case longMonth
    case belowRecord

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fresh:           return "Fresh — baseline 0/5"
        case .baselinePartial: return "Baseline 3/5"
        case .normal:          return "Normal — last hit 30m ago"
        case .longDay:         return "Long stretch — 1 day free"
        case .longWeek:        return "Long stretch — 1 week free"
        case .longMonth:       return "Long stretch — 1 month free"
        case .belowRecord:     return "Long stretch — 2d, below your record"
        }
    }
}

extension HitStore {
    /// Wipe and replace the store with a generated dataset for `scenario`.
    /// DEBUG-only. Same-file extension so it can reach the private `context`,
    /// `records`, `hits`, and `recomputeRecords()`.
    func seedScenario(_ scenario: DebugScenario) {
        for h in hits { context.delete(h) }
        records.longestGapSec = 0
        records.longestWakingGapSec = 0
        try? context.save()
        try? reload()

        let now = Date()
        var dates: [Date] = []
        switch scenario {
        case .fresh:
            baselineSkipped = false
        case .baselinePartial:
            baselineSkipped = false
            dates = [-3, -2, -1].map { now.addingTimeInterval(Double($0) * 3600) }
        case .normal:
            baselineSkipped = true
            dates = Self.seedHistory(endingAt: now.addingTimeInterval(-30 * 60), days: 14, sessionsPerDay: 11)
        case .longDay:
            baselineSkipped = true
            dates = Self.seedHistory(endingAt: now.addingTimeInterval(-26 * 3600), days: 14, sessionsPerDay: 11)
        case .longWeek:
            baselineSkipped = true
            dates = Self.seedHistory(endingAt: now.addingTimeInterval(-8 * 86400), days: 14, sessionsPerDay: 11)
        case .longMonth:
            baselineSkipped = true
            dates = Self.seedHistory(endingAt: now.addingTimeInterval(-32 * 86400), days: 14, sessionsPerDay: 11)
        case .belowRecord:
            // An older block ending ~16 days ago, then a ~12-day void, then
            // recent activity ending 2 days ago → longest gap ~12 days while
            // the current free-for (2 days) sits below it → the "below record"
            // treatment on the record line.
            baselineSkipped = true
            dates = Self.seedHistory(endingAt: now.addingTimeInterval(-16 * 86400), days: 4, sessionsPerDay: 12)
                  + Self.seedHistory(endingAt: now.addingTimeInterval(-2 * 86400), days: 2, sessionsPerDay: 12)
        }

        let tz = TimeZone.current.secondsFromGMT() / 60
        for t in dates.sorted() {
            let hit = Hit(t: t, tzOffsetMinutes: tz)
            context.insert(hit)
            hits.append(hit)
        }
        try? context.save()
        try? reload()
        recomputeRecords()
        // Seeding shouldn't fire the relapse acknowledgment.
        endedLongStretch = nil
    }

    /// Generates realistic daily session clusters for `days` days, with the very
    /// last hit pinned exactly at `anchor`. Sessions are spread across waking
    /// hours (8am–11pm) with light jitter; some sessions get a quick second hit.
    /// The overnight void between waking days becomes the natural longest-gap.
    private static func seedHistory(endingAt anchor: Date, days: Int, sessionsPerDay: Int) -> [Date] {
        let cal = Calendar(identifier: .gregorian)
        let wakeStartSec = 8.0 * 3600
        let wakeSpanSec = 15.0 * 3600   // 8:00 → 23:00
        var out: [Date] = []
        for d in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -d, to: anchor) else { continue }
            let dayStart = cal.startOfDay(for: day)
            for i in 0..<sessionsPerDay {
                let frac = (Double(i) + 0.5) / Double(sessionsPerDay)
                let jitter = Double.random(in: -700...700)
                let t = dayStart.addingTimeInterval(wakeStartSec + frac * wakeSpanSec + jitter)
                if t <= anchor { out.append(t) }
                if Bool.random() {
                    let t2 = t.addingTimeInterval(Double.random(in: 20...90))
                    if t2 <= anchor { out.append(t2) }
                }
            }
        }
        out.append(anchor)
        return out
    }
}
#endif
