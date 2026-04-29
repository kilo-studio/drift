import Foundation

/// Mirrors a small slice of HitStore's state into App Group UserDefaults so the
/// widget extension can render without sharing the full SwiftData store.
/// Updated from the main app on every append; read-only inside the widget.
enum WidgetBridge {
    static let appGroupID = "group.studio.kilo.drift"

    private enum Keys {
        static let lastHit = "drift.bridge.lastHit"
        static let wakingAvgSec = "drift.bridge.wakingAvgSec"
        static let longestWakingGapSec = "drift.bridge.longestWakingGapSec"
        static let longestGapSec = "drift.bridge.longestGapSec"
    }

    /// Snapshot consumed by the widget timeline.
    struct Snapshot {
        let lastHit: Date?
        let wakingAvgSec: TimeInterval?
        let longestWakingGapSec: TimeInterval
        let longestGapSec: TimeInterval
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(_ snapshot: Snapshot) {
        guard let d = defaults else { return }
        if let last = snapshot.lastHit {
            d.set(last.timeIntervalSinceReferenceDate, forKey: Keys.lastHit)
        } else {
            d.removeObject(forKey: Keys.lastHit)
        }
        if let avg = snapshot.wakingAvgSec {
            d.set(avg, forKey: Keys.wakingAvgSec)
        } else {
            d.removeObject(forKey: Keys.wakingAvgSec)
        }
        d.set(snapshot.longestWakingGapSec, forKey: Keys.longestWakingGapSec)
        d.set(snapshot.longestGapSec, forKey: Keys.longestGapSec)
    }

    static func read() -> Snapshot {
        guard let d = defaults else {
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
