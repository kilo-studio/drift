---
status: todo
priority: high
tags: [foundation]
---

# Xcode project setup

Create the iOS app target. Get a runnable empty SwiftUI app with the data store wired in.

## Tasks

- [ ] New Xcode project: iOS App, SwiftUI, Swift, name `Drift`, bundle ID `studio.kilo.drift` (or similar)
- [ ] Minimum iOS 17 (App Intents on Lock Screen, native Charts, Observation framework)
- [ ] Add SwiftData container; define empty `Hit` model placeholder
- [ ] Add target: WidgetKit extension (for the home-screen logging widget — wire up later)
- [ ] Add target: AppIntents extension if needed (or run intents in-app)
- [ ] Set up signing (personal team is fine for early dev; switch to Kilo studio team before TestFlight)
- [ ] Create `.gitignore` (Xcode template covers most of it, add `.DS_Store`, user data)
- [ ] Initial commit on GitHub — repo private until launch readiness

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
