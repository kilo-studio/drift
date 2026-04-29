import SwiftUI
import SwiftData

@main
struct DriftApp: App {
    let container: ModelContainer
    let store: HitStore

    init() {
        DriftFonts.register()
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Hit.self, Records.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c
        store = MainActor.assumeIsolated {
            do {
                return try HitStore(context: c.mainContext)
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
        .modelContainer(container)
    }
}
