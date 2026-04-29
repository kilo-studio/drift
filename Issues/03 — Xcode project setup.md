---
status: done
priority: high
tags: [foundation]
---

# Xcode project setup

Create the iOS app target. Get a runnable empty SwiftUI app with the data store wired in.

## Tasks

- [x] New Xcode project: iOS App, SwiftUI, Swift, name `Drift`, bundle ID `studio.kilo.drift`
- [x] Minimum iOS 26 (intentional — newer APIs available throughout)
- [x] Add SwiftData container; define empty `Hit` model placeholder
- [x] Add target: WidgetKit extension (`DriftWidgetExtension`) — Xcode wizard scaffolded `DriftWidget`, `DriftWidgetBundle`, `DriftWidgetControl`, `DriftWidgetLiveActivity`. Real widget work in Issue 13; Control/LiveActivity stubs may be pruned then.
- [x] AppIntents: running in-app (no separate extension target). Revisit if widget-tap latency becomes a problem.
- [x] Signing — personal team on both `Drift` and `DriftWidgetExtension`. Switch to Kilo studio team before TestFlight.
- [x] `.gitignore` covers Xcode artifacts (xcuserdata, build, DerivedData, .swiftpm, Package.resolved)
- [x] Repo already on origin (private)

## Repo layout

```
Drift/
├── App/                    ← SwiftUI views, app entry
├── Data/                   ← SwiftData models, store, computed metrics
├── Spirit/                 ← spirit Canvas, sparkle field, animations
├── Notifications/          ← scheduler
├── Intents/                ← LogHitIntent, related entities
├── Widget/                 ← Home Screen widget
├── Resources/              ← assets, fonts (if bundling), color/font tokens
└── Tests/
```

## Out of scope

- App icon (separate issue)
- CI / Fastlane (overkill for solo)
