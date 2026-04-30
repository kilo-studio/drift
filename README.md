# Drift

A small, beautiful iOS app that helps you notice the gaps. Currently a Scriptable prototype; planning the native rebuild.

> Free for **2h 33m**. The cloud spirit's eyes get bigger and the sky fills with sparkles the longer you've drifted. No shame, no streaks, no nag — just a gentle visual reward for the time you didn't reach for it.

## Status

Prototype still in daily personal use. Native iOS rebuild well underway: dashboard, spirit, sparkles, logging via App Intent, notifications, ambient cloud/star layer, dark mode, and the prototype-data migration are all in. What's left before submission: settings + onboarding + app icon (Issue 12), hit history (Issue 17), milestone glows (Issue 14), and App Store metadata (Issue 13). Distribution: free on the App Store, source on GitHub, case study on portfolio.

## Where things live

- [[Plan]] — roadmap and phases
- [[Issues]] — flat list of work items, one file per issue, with status frontmatter
- [[Design/Philosophy|Design philosophy]] — what this is, why it looks the way it does
- [[Design/Spirit|The spirit]] — the cloud character: ratio model, eye scaling, sparkle field, milestones
- [[Design/Design system|Design system]] — colors, type, color logic
- [[Engineering/Architecture|Architecture]] — SwiftUI app shape, sync strategy, native vs WebView trade-offs
- [[Engineering/Data model|Data model]] — Hit entity, rolling windows, waking-day grouping
- [[Engineering/Notifications|Notifications]] — immediate + scheduled, overnight hedge
- [[Case study]] — portfolio writeup outline
- [[Notes]] — private scratch
- [[Prototype]] — Scriptable prototype docs (the system that already runs)

## Quick context

The prototype is two Scriptable scripts in iCloud:
- `vape-log.js` — silent background logger triggered by the iOS Action Button
- `vape-stats.js` — HTML dashboard rendered in a WebView

The native rebuild keeps the same data model, same visual language, same notification logic, but loses the Scriptable dependency and adds: App Intents for Lock Screen / Shortcuts logging, a Home Screen widget, CloudKit sync, native charts, native particle rendering for the sparkle field.

See [[Prototype]] for the full Scriptable docs (which double as the spec for the rebuild).

## Naming

**Drift** — verb (cloud drift, drifting between hits) and noun (a slow change, a mood). Avoids vape-specific framing for App Store.
