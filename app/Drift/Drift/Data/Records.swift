import Foundation
import SwiftData

@Model
final class Records {
    var longestGapSec: TimeInterval = 0
    var longestWakingGapSec: TimeInterval = 0

    init(longestGapSec: TimeInterval = 0, longestWakingGapSec: TimeInterval = 0) {
        self.longestGapSec = longestGapSec
        self.longestWakingGapSec = longestWakingGapSec
    }
}
