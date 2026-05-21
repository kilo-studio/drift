import Foundation
import SwiftData

/// Schema version that includes the (now-removed) achievement system. Defined
/// here so SwiftData can open existing stores that were written by the
/// pre-removal app build — every device that ran Drift through ~mid-May 2026
/// has a SQLite file with `ZACHIEVEMENTSTATE` and `ZMILESTONEUNLOCK` tables in
/// it. `DriftMigrationPlan` carries those stores forward to `DriftSchemaV2`
/// (current), dropping the achievement tables while preserving `Hit` and
/// `Records` data.
///
/// `Hit` and `Records` are top-level types that didn't change shape across
/// versions — they're referenced as-is in both V1 and V2. The two
/// achievement types are nested inside this enum so they only exist for the
/// migration runtime; nothing in the running app imports them.
enum DriftSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Hit.self, Records.self, AchievementState.self, MilestoneUnlock.self]
    }

    /// Singleton ratchet records + cumulative counters. Lifted verbatim from
    /// the pre-removal `Data/Achievement.swift`.
    @Model
    final class AchievementState {
        var lowest7dSessionsPerDay: Double?
        var lowest7dSessionsPerDayDate: Date?

        var lowestRollingSessionsPerDay: Double?
        var lowestRollingSessionsPerDayDate: Date?

        var lowestSingleDaySessionCount: Int?
        var lowestSingleDayDate: Date?

        var lowestAvgHitsPerSession: Double?
        var lowestAvgHitsPerSessionDate: Date?

        var mostConsecutiveSoloSessions: Int = 0
        var mostConsecutiveSoloDate: Date?

        var totalTimeDriftedSec: Double = 0
        var totalSoloSessions: Int = 0

        init() {}
    }

    /// One row per unlocked one-time milestone. Lifted verbatim from the
    /// pre-removal `Data/Achievement.swift`.
    @Model
    final class MilestoneUnlock {
        @Attribute(.unique) var id: String
        var unlockedAt: Date

        init(id: String, unlockedAt: Date = .now) {
            self.id = id
            self.unlockedAt = unlockedAt
        }
    }
}
