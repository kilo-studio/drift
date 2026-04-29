import Foundation
import SwiftData

@Model
final class Hit {
    var t: Date
    var tzOffsetMinutes: Int

    init(t: Date = .now, tzOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60) {
        self.t = t
        self.tzOffsetMinutes = tzOffsetMinutes
    }
}
