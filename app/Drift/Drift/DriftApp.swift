import SwiftUI
import SwiftData

@main
struct DriftApp: App {
    /// Shared container so App Intents (which run in the app's process when
    /// `openAppWhenRun = true`) can construct their own `HitStore` against the
    /// same SwiftData store. The migration plan handles devices that still
    /// have the pre-removal V1 schema (with achievement tables) on disk —
    /// `.lightweight` drops the unused tables while preserving `Hit` and
    /// `Records` data.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Hit.self, Records.self,
                migrationPlan: DriftMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// Live reference to the running app's HitStore. The App Intent prefers this
    /// when set so a foreground hit logs into the same @Observable instance the
    /// dashboard is observing — without it the intent's mutations would land on
    /// a separate store instance and the UI would stay frozen until next launch.
    @MainActor static var sharedStore: HitStore?

    let store: HitStore

    init() {
        DriftFonts.register()
        store = MainActor.assumeIsolated {
            do {
                let s = try HitStore(context: DriftApp.container.mainContext)
                PrototypeMigration.runIfNeeded(s)
                DriftApp.sharedStore = s
                return s
            } catch {
                fatalError("Failed to create HitStore: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(DriftApp.container)
    }
}
