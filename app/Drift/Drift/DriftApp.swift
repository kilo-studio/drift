import SwiftUI
import SwiftData

@main
struct DriftApp: App {
    init() {
        DriftFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Hit.self)
    }
}
