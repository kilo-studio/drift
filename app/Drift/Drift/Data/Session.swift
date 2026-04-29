import Foundation

/// Default session threshold: hits within 5 minutes of each other belong to the
/// same session. Configurable per Issue 16; the user-facing setting will store
/// the override in UserDefaults.
let defaultSessionThresholdSec: TimeInterval = 5 * 60

/// A maximal cluster of consecutive hits where every inter-hit gap is ≤ threshold.
/// Sessions are derived on read, never persisted. A solo hit is a session of length 1.
struct Session {
    let hits: [Hit]

    var start: Date { hits.first!.t }
    var end:   Date { hits.last!.t }
    var count: Int  { hits.count }
    var duration: TimeInterval { end.timeIntervalSince(start) }

    /// Waking-day bucket of the session's first hit. Per Issue 16 edge case:
    /// a session that starts at 3:45am and ends at 4:15am belongs to the
    /// first hit's bucket, not the second.
    var wakingDayKey: String { hits.first!.wakingDayKey }

    /// Calendar-day key (logged tz) of the session's first hit.
    var logLocalDateKey: String { hits.first!.logLocalDateKey }
}

extension Array where Element == Hit {
    /// Group consecutive hits into sessions. A gap STRICTLY greater than
    /// `threshold` ends a session; equal-to-threshold gaps stay in the
    /// same session (matches the prototype-style "no gap longer than X").
    func sessions(threshold: TimeInterval = defaultSessionThresholdSec) -> [Session] {
        let sorted = sortedByTime()
        var result: [Session] = []
        var current: [Hit] = []
        for hit in sorted {
            if let last = current.last,
               hit.t.timeIntervalSince(last.t) > threshold {
                result.append(Session(hits: current))
                current = []
            }
            current.append(hit)
        }
        if !current.isEmpty { result.append(Session(hits: current)) }
        return result
    }
}
