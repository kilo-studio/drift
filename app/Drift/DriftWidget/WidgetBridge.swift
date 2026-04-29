import Foundation

/// Mirror of the main app's WidgetBridge. Read-only inside the widget target —
/// keeps file membership simple while sharing data via App Group UserDefaults.
enum WidgetBridge {
    static let appGroupID = "group.studio.kilo.drift"

    private enum Keys {
        static let lastHit = "drift.bridge.lastHit"
        static let wakingAvgSec = "drift.bridge.wakingAvgSec"
        static let longestWakingGapSec = "drift.bridge.longestWakingGapSec"
        static let longestGapSec = "drift.bridge.longestGapSec"
    }

    struct Snapshot {
        let lastHit: Date?
        let wakingAvgSec: TimeInterval?
        let longestWakingGapSec: TimeInterval
        let longestGapSec: TimeInterval
    }

    static func read() -> Snapshot {
        guard let d = UserDefaults(suiteName: appGroupID) else {
            return Snapshot(lastHit: nil, wakingAvgSec: nil, longestWakingGapSec: 0, longestGapSec: 0)
        }
        let lastHit: Date?
        if d.object(forKey: Keys.lastHit) != nil {
            lastHit = Date(timeIntervalSinceReferenceDate: d.double(forKey: Keys.lastHit))
        } else {
            lastHit = nil
        }
        let avg: TimeInterval? = d.object(forKey: Keys.wakingAvgSec) != nil
            ? d.double(forKey: Keys.wakingAvgSec)
            : nil
        return Snapshot(
            lastHit: lastHit,
            wakingAvgSec: avg,
            longestWakingGapSec: d.double(forKey: Keys.longestWakingGapSec),
            longestGapSec: d.double(forKey: Keys.longestGapSec)
        )
    }
}
