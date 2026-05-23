import Foundation
import UserNotifications

/// State captured at hit-append time, fed to the scheduler so it can reason
/// about baseline / records without coupling to HitStore.
struct HitNotificationContext {
    let now: Date
    let previousHitDate: Date?
    let totalHits: Int
    let wakingAvgSec: TimeInterval?
    let longestWakingGapSec: TimeInterval
    let longestGapSec: TimeInterval
    let isNewWakingBest: Bool
    let isNewOverallBest: Bool
}

/// UserDefaults keys for notification preferences. Free constants so both the
/// scheduler (reading) and HitStore (binding for settings UI) can reach them
/// without circular dependency. Defaults documented in Issue 12.
let driftNotifsEnabledKey         = "drift.notifs.enabled"
let driftNotifsImmediateKey       = "drift.notifs.immediate"
let driftNotifsBeatAverageKey     = "drift.notifs.beatAverage"
let driftNotifsBeatRecordKey      = "drift.notifs.beatRecord"
let driftNotifsBeatAvgOffsetKey   = "drift.notifs.beatAverageOffsetSec"
let driftNotifsBeatRecordOffsetKey = "drift.notifs.beatRecordOffsetSec"

@MainActor
enum NotificationScheduler {
    private static let beatAverageID       = "drift-beat-average"
    private static let beatWakingRecordID  = "drift-beat-waking-record"
    private static let beatOverallRecordID = "drift-beat-overall-record"
    private static let center = UNUserNotificationCenter.current()

    private static var scheduledIDs: [String] {
        [beatAverageID, beatWakingRecordID, beatOverallRecordID]
    }

    /// Request alert/sound/badge authorization. Idempotent — iOS only prompts on
    /// first call; later calls return the existing status. Per Issue 07, surface
    /// this from settings or on the first hit (not on cold launch).
    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Cancel all scheduled notifications, fire the immediate one, and re-add
    /// the scheduled set if state warrants it. Call after every append. Honors
    /// the user's notification preferences (master + per-type toggles).
    static func reschedule(after ctx: HitNotificationContext) async {
        center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)

        guard masterEnabled() else { return }

        // Only ask for permission if the user actually wants notifications. The
        // dialog is idempotent (system shows it once), but with the master toggle
        // off we shouldn't pester them about a permission they didn't ask for.
        _ = await requestAuthorization()

        if immediateEnabled() {
            await fireImmediate(ctx)
        }
        if beatAverageEnabled(), ctx.totalHits >= HitStore.baselineTarget, let avg = ctx.wakingAvgSec, avg > 0 {
            await scheduleBeatAverage(avgSec: avg)
        }
        if beatRecordEnabled(), ctx.totalHits >= 2 {
            if ctx.longestWakingGapSec > 0 {
                await scheduleBeatWakingRecord(longestSec: ctx.longestWakingGapSec, now: ctx.now)
            }
            // Only schedule overall-best if it's actually distinct from the
            // waking-best — otherwise both fire at the same moment and feel
            // duplicative.
            if ctx.longestGapSec > ctx.longestWakingGapSec {
                await scheduleBeatOverallRecord(longestSec: ctx.longestGapSec, now: ctx.now)
            }
        }
    }

    /// Cancel any pending scheduled notifications. Called from HitStore when the
    /// user changes notification preferences mid-day so prior schedules don't
    /// fire under stale settings. Already-delivered banners stay until dismissed.
    static func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)
    }

    // MARK: - Preference reads (defaults match Issue 12)

    private static func masterEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: driftNotifsEnabledKey) as? Bool) ?? true
    }
    private static func immediateEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: driftNotifsImmediateKey) as? Bool) ?? true
    }
    private static func beatAverageEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: driftNotifsBeatAverageKey) as? Bool) ?? true
    }
    private static func beatRecordEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: driftNotifsBeatRecordKey) as? Bool) ?? true
    }
    private static func beatAverageOffsetSec() -> TimeInterval {
        // `double(forKey:)` returns 0 for unset keys — and 0 is a valid offset
        // ("right at"), so distinguish via `object(forKey:)` to apply the
        // default only when nothing's stored. Default: +5 min — the
        // beat-average nudge is gentle, and 5 minutes past the average is
        // when "wait it out" starts to feel meaningful.
        if let v = UserDefaults.standard.object(forKey: driftNotifsBeatAvgOffsetKey) as? Double { return v }
        return 300
    }
    private static func beatRecordOffsetSec() -> TimeInterval {
        if let v = UserDefaults.standard.object(forKey: driftNotifsBeatRecordOffsetKey) as? Double { return v }
        return 0
    }

    // MARK: - Immediate

    private static func fireImmediate(_ ctx: HitNotificationContext) async {
        let content = UNMutableNotificationContent()
        content.title = "Drift"
        content.body = immediateBody(ctx)
        // Unique identifier so the immediate banner doesn't replace itself if
        // the user logs twice quickly — both should appear / coalesce naturally.
        let req = UNNotificationRequest(
            identifier: "drift-logged-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(req)
    }

    private static func immediateBody(_ ctx: HitNotificationContext) -> String {
        guard let prev = ctx.previousHitDate else {
            return "First hit logged. Building your baseline."
        }
        let deltaMin = Int(ctx.now.timeIntervalSince(prev) / 60)

        // X/N baseline framing only applies to users still establishing.
        // Skipped users get the normal body from hit 1 — they opted out of
        // the establishing period.
        let baselineSkipped = UserDefaults.standard.bool(forKey: driftBaselineSkippedKey)
        if !baselineSkipped, ctx.totalHits < HitStore.baselineTarget {
            return "\(deltaMin)m since last hit · \(ctx.totalHits)/\(HitStore.baselineTarget) baseline"
        }
        let avgMin = Int((ctx.wakingAvgSec ?? 0) / 60)
        var body = "⏱ \(deltaMin)m since last hit · avg \(avgMin)m"
        if ctx.isNewOverallBest {
            body += " · 🏆 new all-time best"
        } else if ctx.isNewWakingBest {
            body += " · 🥇 new waking best"
        }
        return body
    }

    // MARK: - Beat your average

    private static func scheduleBeatAverage(avgSec: TimeInterval) async {
        let triggerInterval = avgSec + beatAverageOffsetSec()
        let triggerDate = Date().addingTimeInterval(triggerInterval)

        // No notifications during the user's sleep window — the original "if
        // you're still awake" hedge was confusing on wake-up. Just don't fire.
        guard !isOvernight(triggerDate) else { return }

        let avgMin = Int(avgSec / 60)
        let content = UNMutableNotificationContent()
        content.title = "👏 You're beating your average"
        content.body = "Don't hit it. You're past your average of \(avgMin)m"

        let req = UNNotificationRequest(
            identifier: beatAverageID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        )
        try? await center.add(req)
    }

    // MARK: - Beat your waking record

    private static func scheduleBeatWakingRecord(longestSec: TimeInterval, now: Date) async {
        let triggerInterval = longestSec + beatRecordOffsetSec()
        let triggerDate = now.addingTimeInterval(triggerInterval)

        // Skip if the trigger lands past the next 4am cutoff — sleep gaps shouldn't
        // be celebrated as a "waking best."
        guard triggerDate <= endOfWakingDay(now) else { return }
        guard !isOvernight(triggerDate) else { return }

        let bestMin = Int(longestSec / 60)
        let content = UNMutableNotificationContent()
        content.title = "🥇 new waking best"
        content.body = "You just beat your longest waking stretch of \(bestMin)m. Keep drifting."

        let req = UNNotificationRequest(
            identifier: beatWakingRecordID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        )
        try? await center.add(req)
    }

    // MARK: - Beat your overall record

    /// All-time longest gap. Scheduled separately from the waking-best so that a
    /// gap stretching across a sleep window can still be celebrated when the
    /// user wakes up — but if the trigger lands during the configured sleep
    /// window, skip it (no wake-up surprises).
    private static func scheduleBeatOverallRecord(longestSec: TimeInterval, now: Date) async {
        let triggerInterval = longestSec + beatRecordOffsetSec()
        let triggerDate = now.addingTimeInterval(triggerInterval)

        guard !isOvernight(triggerDate) else { return }

        let bestMin = Int(longestSec / 60)
        let content = UNMutableNotificationContent()
        content.title = "🏆 new all-time best"
        content.body = "You just beat your longest gap ever: \(bestMin)m. Keep drifting."

        let req = UNNotificationRequest(
            identifier: beatOverallRecordID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        )
        try? await center.add(req)
    }

    /// Whether `date`'s hour-of-day falls inside the user's configured sleep window.
    /// Typical case: window crosses midnight (start > end), e.g. 23 → 6 → return true
    /// for hours ≥23 or <6. Edge case: someone with an inverted schedule (sleep at
    /// 4am, wake at noon → start < end) → return true for hours in [start, end).
    private static func isOvernight(_ date: Date) -> Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: date)
        let start = driftSleepStartHour()
        let end = driftSleepEndHour()
        if start > end { return hour >= start || hour < end }
        if start < end { return hour >= start && hour < end }
        return false
    }
}
