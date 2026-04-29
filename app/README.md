# app/

Native SwiftUI iOS app. Currently empty — Xcode will populate it when the project is created.

See [[Architecture]] for the architectural shape, and [[Issues/03 — Xcode project setup]] for the setup checklist.

## Where Xcode goes

When creating the Xcode project, target this directory:

```
app/
├── Drift.xcodeproj           ← Xcode project file
├── Drift/                    ← app target source
│   ├── DriftApp.swift        ← @main entry
│   ├── App/                  ← top-level SwiftUI views (Dashboard, Hero)
│   ├── Data/                 ← Hit model, HitStore, computed metrics
│   ├── Spirit/               ← SpiritView (Canvas), SparkleField, animations
│   ├── Notifications/        ← NotificationScheduler
│   ├── Intents/              ← LogHitIntent + supporting types
│   ├── Widget/               ← Home Screen + Lock Screen widgets
│   └── Resources/            ← Assets.xcassets, fonts, design tokens
└── Tests/                    ← Unit + snapshot tests
```

Bundle ID: `studio.kilo.drift` (or similar — confirm before TestFlight).

## What's already gitignored

The repo's `.gitignore` already excludes Xcode noise:

- `**/xcuserdata/`
- `**/build/`
- `**/.build/`
- `**/*.xcuserstate`
- `**/DerivedData/`
- `**/Package.resolved`
- `**/.swiftpm/`

So once Xcode generates the project, `git status` should only show files that genuinely belong in source control.

## Don't pre-create folders

This README is the only file here for now. When Xcode creates the project, let it own the subfolder structure — pre-existing empty folders sometimes confuse the Xcode template.
