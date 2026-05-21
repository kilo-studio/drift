import AppIntents
import SwiftData
import WidgetKit

/// "Log a hit" — surfaces in Shortcuts, Siri, the Action Button, Spotlight, and the
/// widget tap target.
///
/// `openAppWhenRun = false` so the intent runs silently while the phone is locked
/// (the Action Button can't unlock the device). The static `DriftApp.container`
/// auto-initializes on first access so a cold trigger spins up SwiftData in the
/// background, mutates the store, and returns. When the app IS running, we reuse
/// the live `sharedStore` so the dashboard's `@Observable` broadcasts the update.
///
/// Returns plain `IntentResult` (no `ProvidesDialog`) so the system doesn't surface
/// a shortcut-completion banner — `HitStore.append` already schedules the immediate
/// confirmation notification, and the dialog banner duplicates it.
struct LogHitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a hit"
    static var description = IntentDescription(
        "Log a hit. Drift records the time and updates your stats."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = try DriftApp.sharedStore ?? HitStore(context: DriftApp.container.mainContext)
        try store.append()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
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
