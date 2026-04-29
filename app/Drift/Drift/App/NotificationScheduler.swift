import Foundation
import UserNotifications

/// State captured at hit-append time, fed to the scheduler so it can reason
/// about baseline / records / overnight hedge without coupling to HitStore.
struct HitNotificationContext {
    let now: Date
    let previousHitDate: Date?
    let totalHits: Int
    let wakingAvgSec: TimeInterval?
    let longestWakingGapSec: TimeInterval
    let isNewWakingBest: Bool
}

@MainActor
enum NotificationScheduler {
    private static let beatAverageID = "drift-beat-average"
    private static let beatRecordID  = "drift-beat-record"
    private static let center = UNUserNotificationCenter.current()

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

    /// Cancel both scheduled notifications, fire the immediate one, and re-add
    /// the scheduled pair if the state warrants it. Call after every append.
    static func reschedule(after ctx: HitNotificationContext) async {
        // Surface the permission prompt on every hit append. Idempotent — iOS
        // only shows the system dialog the first time the app makes the request,
        // and the Settings → Drift → Notifications row only appears once
        // requestAuthorization has been called at least once.
        _ = await requestAuthorization()

        center.removePendingNotificationRequests(withIdentifiers: [beatAverageID, beatRecordID])

        await fireImmediate(ctx)

        if ctx.totalHits >= 10, let avg = ctx.wakingAvgSec, avg > 0 {
            await scheduleBeatAverage(avgSec: avg)
        }
        if ctx.longestWakingGapSec > 0, ctx.totalHits >= 2 {
            await scheduleBeatRecord(longestSec: ctx.longestWakingGapSec, now: ctx.now)
        }
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

        if ctx.totalHits < 10 {
            return "\(deltaMin)m since last hit · \(ctx.totalHits)/10 baseline"
        }
        let avgMin = Int((ctx.wakingAvgSec ?? 0) / 60)
        var body = "⏱ \(deltaMin)m since last hit · avg \(avgMin)m"
        if ctx.isNewWakingBest { body += " · 🥇 new waking best" }
        return body
    }

    // MARK: - Beat your average

    private static func scheduleBeatAverage(avgSec: TimeInterval) async {
        let triggerInterval = avgSec + 60  // 60s grace
        let triggerDate = Date().addingTimeInterval(triggerInterval)
        let avgMin = Int(avgSec / 60)

        let content = UNMutableNotificationContent()
        content.title = "👏 You're beating your average"
        content.body = isOvernight(triggerDate)
            ? "If you're still awake, you're past your average of \(avgMin)m"
            : "Don't hit it — you're past your average of \(avgMin)m"

        let req = UNNotificationRequest(
            identifier: beatAverageID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        )
        try? await center.add(req)
    }

    // MARK: - Beat your record

    private static func scheduleBeatRecord(longestSec: TimeInterval, now: Date) async {
        let triggerInterval = longestSec + 1
        let triggerDate = now.addingTimeInterval(triggerInterval)

        // Skip if the trigger lands past the next 4am cutoff — sleep gaps shouldn't
        // be celebrated as a "waking best."
        guard triggerDate <= endOfWakingDay(now) else { return }

        let bestMin = Int(longestSec / 60)
        let content = UNMutableNotificationContent()
        content.title = "🥇 new waking best"
        content.body = isOvernight(triggerDate)
            ? "If you're still awake, you just beat your longest waking stretch of \(bestMin)m. Keep drifting."
            : "You just beat your longest waking stretch of \(bestMin)m. Keep drifting."

        let req = UNNotificationRequest(
            identifier: beatRecordID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        )
        try? await center.add(req)
    }

    private static func isOvernight(_ date: Date) -> Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: date)
        return hour >= 23 || hour < 6
    }
}
