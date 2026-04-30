import AppIntents
import SwiftData
import WidgetKit

/// "Log a hit" — surfaces in Shortcuts, Siri, the Action Button, Spotlight, and the
/// widget tap target. Phase A: opens Drift on run so we can reuse the app's
/// `ModelContainer` without an App Group. Phase B will flip `openAppWhenRun = false`
/// once shared SwiftData is wired through.
struct LogHitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a hit"
    static var description = IntentDescription(
        "Log a hit. Drift records the time and updates your stats."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Prefer the running app's live store so the dashboard sees the new hit
        // immediately (the @Observable on the running HitStore broadcasts the
        // change to HomeView). Fall back to a fresh store when the app isn't
        // already running yet.
        let store = try DriftApp.sharedStore ?? HitStore(context: DriftApp.container.mainContext)
        let prevLast = store.lastHitDate
        try store.append()

        WidgetCenter.shared.reloadAllTimelines()

        let dialog = formatDialog(
            prevLast: prevLast,
            now: Date(),
            avgSec: store.wakingAvgSec(),
            totalHits: store.hits.count
        )
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

private func formatDialog(prevLast: Date?, now: Date, avgSec: TimeInterval?, totalHits: Int) -> String {
    if totalHits < 10 {
        return "First steps logged. \(totalHits)/10 baseline."
    }
    guard let prev = prevLast else {
        return "First hit logged. Building your baseline."
    }
    let deltaMin = Int(now.timeIntervalSince(prev) / 60)
    let avgMin = Int((avgSec ?? 0) / 60)
    return "Logged. \(deltaMin)m since last hit · avg \(avgMin)m."
}

/// Surfaces `LogHitIntent` as a built-in App Shortcut so iOS suggests it without the
/// user having to manually create a Shortcut.
struct DriftAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHitIntent(),
            phrases: [
                "Log a hit in \(.applicationName)",
                "\(.applicationName) hit",
                "Log hit in \(.applicationName)"
            ],
            shortTitle: "Log hit",
            systemImageName: "plus.circle.fill"
        )
    }
}
