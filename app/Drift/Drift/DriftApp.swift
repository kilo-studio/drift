import SwiftUI
import SwiftData

@main
struct DriftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Hit.self)
    }
}
