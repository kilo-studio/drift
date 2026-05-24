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
    ///
    /// iCloud sync is always on (CloudKit `.automatic`, reading the container
    /// from the entitlement) — it's the user's own private CloudKit database, so
    /// it's privacy-preserving (we never receive a copy) and matches how Apple's
    /// own apps behave; users disable it per-app in iOS Settings → iCloud. With
    /// no account it just no-ops to local. If container creation throws (e.g.
    /// the CloudKit capability/container is misconfigured) we fall back to a
    /// plain local store at the same URL so the app still launches.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Hit.self, Records.self,
                migrationPlan: DriftMigrationPlan.self,
                configurations: ModelConfiguration(cloudKitDatabase: .automatic)
            )
        } catch {
            NSLog("Drift: CloudKit container unavailable, using local store: \(error)")
            do {
                return try ModelContainer(
                    for: Hit.self, Records.self,
                    migrationPlan: DriftMigrationPlan.self
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
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
                // Existing-hits skip: users restoring from backup or upgrading
                // from a pre-onboarding build already have data and aren't new
                // users — flip the flag so they go straight to the dashboard.
                let defaults = UserDefaults.standard
                if !s.hits.isEmpty && !defaults.bool(forKey: driftOnboardingCompleteKey) {
                    defaults.set(true, forKey: driftOnboardingCompleteKey)
                }
                DriftApp.sharedStore = s
                #if DEBUG
                // Launch-arg seeding for testing: `--seed longWeek` (any
                // DebugScenario rawValue). Also forces onboarding complete so
                // the seeded scenario is what you land on. Compiled out of release.
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "--seed"), i + 1 < args.count,
                   let scenario = DebugScenario(rawValue: args[i + 1]) {
                    UserDefaults.standard.set(true, forKey: driftOnboardingCompleteKey)
                    s.seedScenario(scenario)
                }
                #endif
                return s
            } catch {
                fatalError("Failed to create HitStore: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(DriftApp.container)
    }
}

/// Gates between onboarding and the dashboard. Reads the persisted flag via
/// `@AppStorage` so flipping it (from the conclusion card or a settings reset)
/// triggers an automatic swap.
private struct RootView: View {
    @AppStorage(driftOnboardingCompleteKey) private var onboardingComplete: Bool = false
    #if DEBUG
    @Environment(HitStore.self) private var store
    #endif

    var body: some View {
        Group {
            if onboardingComplete {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        #if DEBUG
        // `--relapse` (paired with `--seed <longScenario>`): log a hit shortly
        // after launch so the relapse acknowledgment fires — a way to test that
        // path without tapping. Compiled out of release.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--relapse") else { return }
            store.notifsEnabled = false   // avoid the auth prompt obscuring the ack in tests
            try? await Task.sleep(for: .seconds(1.5))
            try? store.append()
        }
        #endif
    }
}
