import SwiftData

/// One-way migration from the achievement-era schema to the current one.
///
/// SwiftData's `.lightweight` stage handles dropping the `AchievementState`
/// and `MilestoneUnlock` model types — the underlying SQLite tables get
/// removed, but `Hit` and `Records` (whose types didn't change) are
/// preserved row-for-row.
///
/// Before this plan existed, the app shipped a `ModelContainer` whose `for:`
/// list silently went from four types to two without an explicit migration.
/// SwiftData's auto-migration couldn't figure that out and dropped data on
/// at least one real device — this plan exists so that never happens again.
enum DriftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DriftSchemaV1.self, DriftSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: DriftSchemaV1.self,
                toVersion: DriftSchemaV2.self
            )
        ]
    }
}
