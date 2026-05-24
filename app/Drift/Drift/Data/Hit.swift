import Foundation
import SwiftData

@Model
final class Hit {
    // Default values are required for CloudKit sync (every attribute must be
    // optional or defaulted). They don't change the local store schema — the
    // CoreData version hash ignores defaults — so existing stores open unchanged
    // with no migration. The init still supplies the real values on insert.
    var t: Date = Date.distantPast
    var tzOffsetMinutes: Int = 0

    init(t: Date = .now, tzOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60) {
        self.t = t
        self.tzOffsetMinutes = tzOffsetMinutes
    }
}
