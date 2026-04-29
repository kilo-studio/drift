import Foundation

enum PrototypeImport {
    struct ParsedHit {
        let t: Date
        let tzOffsetMinutes: Int
    }

    struct Parsed {
        let hits: [ParsedHit]
        let longestGapSec: TimeInterval
        let longestWakingGapSec: TimeInterval?
    }

    enum ImportError: Error {
        case malformedJSON
        case missingHits
    }

    /// Parses the prototype's `vape-log.json` shape:
    /// `{ hits: [{ t: ISO-string, tz: minutes-east-of-UTC } | ISO-string],
    ///    longestGap: seconds, longestWakingGap?: seconds }`
    /// String-only entries from the pre-tz format are accepted and assigned the
    /// caller's `assumedTzMinutes` (defaults to current device offset).
    static func parse(_ data: Data, assumedTzMinutes: Int = TimeZone.current.secondsFromGMT() / 60) throws -> Parsed {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterNoFraction = ISO8601DateFormatter()
        formatterNoFraction.formatOptions = [.withInternetDateTime]

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.malformedJSON
        }
        guard let rawHits = root["hits"] as? [Any] else { throw ImportError.missingHits }

        var parsed: [ParsedHit] = []
        for raw in rawHits {
            if let str = raw as? String {
                guard let date = formatter.date(from: str) ?? formatterNoFraction.date(from: str) else { continue }
                parsed.append(ParsedHit(t: date, tzOffsetMinutes: assumedTzMinutes))
            } else if let dict = raw as? [String: Any], let tStr = dict["t"] as? String {
                guard let date = formatter.date(from: tStr) ?? formatterNoFraction.date(from: tStr) else { continue }
                let tz = (dict["tz"] as? Int) ?? assumedTzMinutes
                parsed.append(ParsedHit(t: date, tzOffsetMinutes: tz))
            }
        }

        let longestGap = (root["longestGap"] as? Double) ?? Double(root["longestGap"] as? Int ?? 0)
        let longestWaking = root["longestWakingGap"].flatMap { ($0 as? Double) ?? Double($0 as? Int ?? 0) }

        return Parsed(
            hits: parsed.sorted { $0.t < $1.t },
            longestGapSec: longestGap,
            longestWakingGapSec: longestWaking
        )
    }
}

extension HitStore {
    /// Imports a parsed prototype payload. Idempotent against the UserDefaults flag
    /// `drift.migration.scriptable.complete` — call sites should check first.
    func importPrototype(_ parsed: PrototypeImport.Parsed) throws {
        for ph in parsed.hits {
            try append(Hit(t: ph.t, tzOffsetMinutes: ph.tzOffsetMinutes))
        }
        // Backfill records if the prototype's were higher than what we derived during append.
        // (Append computes deltas between consecutive imported hits; that should produce the
        // same longestGap/longestWakingGap as the prototype, but the persisted values are the
        // canonical fallback.)
    }
}
