import SwiftUI
import SwiftData

@main
struct DriftApp: App {
    /// Shared container so App Intents (which run in the app's process when
    /// `openAppWhenRun = true`) can construct their own `HitStore` against the
    /// same SwiftData store.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Hit.self, Records.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    let store: HitStore

    init() {
        DriftFonts.register()
        store = MainActor.assumeIsolated {
            do {
                return try HitStore(context: DriftApp.container.mainContext)
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
