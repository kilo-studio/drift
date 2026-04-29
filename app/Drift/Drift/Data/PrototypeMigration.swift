import Foundation

/// One-time bundled-JSON import. Reads `vape-log-bundle.json` from the app bundle
/// (gitignored — copied in locally for the dev device) and pours the hits into the
/// store via `HitStore.bulkImport`. Idempotent: gated by a UserDefaults flag plus
/// an "already has data" check so reinstalls don't double-import.
@MainActor
enum PrototypeMigration {
    private static let flagKey = "drift.migration.scriptable.complete"
    private static let bundleResource = "vape-log-bundle"

    static func runIfNeeded(_ store: HitStore) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        // Don't clobber existing data on reinstall.
        guard store.hits.isEmpty else {
            defaults.set(true, forKey: flagKey)
            return
        }

        guard let url = Bundle.main.url(forResource: bundleResource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? PrototypeImport.parse(data)
        else {
            return
        }

        do {
            try store.bulkImport(parsed.hits)
            defaults.set(true, forKey: flagKey)
        } catch {
            // Don't set the flag — leave the door open for a retry on next launch.
        }
    }
}
