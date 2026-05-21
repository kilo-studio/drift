import Foundation
import SwiftData

/// Current schema. `AchievementState` and `MilestoneUnlock` are gone; only
/// the two types the app actually uses remain.
enum DriftSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Hit.self, Records.self]
    }
}
