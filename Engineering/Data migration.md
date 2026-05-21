# Data migration

Notes on how Drift handles SwiftData schema changes, and the rule that exists because of a real incident.

## The rule

**Any change to `ModelContainer(for:...)` — adding, removing, or renaming a model type — requires bumping the schema version and adding a `MigrationStage` to `DriftMigrationPlan`.**

No exceptions. SwiftData's auto-migration is not reliable enough to handle removed model types without an explicit plan.

## File layout

```
Data/
├── DriftSchemaV1.swift          ← the pre-removal shape (Hit + Records +
│                                   AchievementState + MilestoneUnlock).
│                                   AchievementState and MilestoneUnlock are
│                                   nested inside the enum, defined verbatim
│                                   from the deleted Data/Achievement.swift.
├── DriftSchemaV2.swift          ← current shape (Hit + Records only).
└── DriftMigrationPlan.swift     ← `.lightweight(V1 → V2)` stage.
```

`DriftApp.swift` wires it up:

```swift
ModelContainer(
    for: Hit.self, Records.self,
    migrationPlan: DriftMigrationPlan.self
)
```

## Adding a new schema version

When you next change the container's `for:` list (e.g. adding an Interval type for some new feature):

1. Define `DriftSchemaV3` in a new file, including the new + existing types.
2. Append a `MigrationStage` to `DriftMigrationPlan.stages` going from V2 to V3. `.lightweight` is fine if the change is mechanical (additive properties with defaults, additive types, renames via `@Attribute(originalName:)`). `.custom` is required when data needs to be transformed.
3. Update `ModelContainer(for: ...)` to reference the new types.

Don't skip versions. Don't reuse old version numbers.

## Testing a migration before it touches a device

Before any build that includes a new migration stage gets installed on a real phone:

1. Set up the previous version's schema state in the simulator (either by checking out the old commit and building it, or by manually constructing a `.store` file matching the old shape).
2. Build the new version against that simulator install. SwiftData runs the migration on first launch.
3. Verify row counts, timestamps, and records match expectations after migration completes.

Skip this step at your peril — see the incident below.

## The 2026-05-20 incident

Roughly three weeks of daily hit data was destroyed on a real device by an untested schema change. The sequence:

1. Drift on the user's phone had been running the achievement-era schema since ~2026-04-29 — `Hit`, `Records`, `AchievementState`, `MilestoneUnlock`. Hits were accumulating normally; the user was logging multiple times a day via the Action Button.
2. We removed the achievement system mid-day on 2026-05-20, changing `ModelContainer(for: Hit.self, Records.self, AchievementState.self, MilestoneUnlock.self)` to `ModelContainer(for: Hit.self, Records.self)`. No migration plan was added.
3. After the Linger split + scheme regeneration that same day, the user reinstalled Drift from Xcode to their phone.
4. SwiftData's lightweight auto-migration could not handle two whole model types disappearing. It silently wiped the store. The app opened and showed an empty dashboard.
5. The user's iCloud backup from earlier in the day captured the pre-loss state, so recovery was possible via full-device restore from backup — but only because the timing worked out. If the backup window had landed differently, the loss would have been permanent.

What I (Claude) made worse during the investigation:

- Ran `PRAGMA wal_checkpoint(TRUNCATE)` on the user's downloaded `.xcappdata` to see if WAL data would yield more rows. This truncated a 403KB WAL that might have contained recoverable transactions. **Even a plain `SELECT` on a SwiftData store can trigger automatic WAL checkpoint** — always open `sqlite3 "file:$DB?mode=ro" ...` when investigating live data.

Lessons encoded into rules going forward:

- The "any container change needs a `MigrationStage`" rule above.
- The "open SwiftData stores read-only when investigating" rule.
- "Test the migration in the simulator before any device install."
- The achievement-era schema was reconstructable from git history because we hadn't squashed those commits. Keep a `git tag` on the commit just before any future destructive schema change.
