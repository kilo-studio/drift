# Drift

A small, beautiful iOS app that helps you notice the gaps. Currently a Scriptable prototype; planning the native rebuild.

> Free for **2h 33m**. The cloud spirit's eyes get bigger and the sky fills with sparkles the longer you've drifted. No shame, no streaks, no nag — just a gentle visual reward for the time you didn't reach for it.

## Status

Prototype still in daily personal use. Native iOS rebuild is feature-complete for v1's core: dashboard, spirit, sparkles, logging via App Intent, notifications, ambient cloud/star layer, dark mode, the prototype-data migration, hit history with calendar + edit/delete, three-tab nav (home / history / settings) + a trailing + tab with a scroll-minimizing bottom bar, the full settings tab (use-sessions toggle, session threshold, rolling window, sleep window, notification master + per-type toggles + timing offsets, reset, about), the app icon (an Icon Composer `Drift.icon` bundle), opaque spirit wisps, and smooth ease-out decay when a hit is logged. What's left before submission: empty-state polish for the home dashboard, multi-screen onboarding (especially the Action Button setup walkthrough), milestone glows on the hero (Issue 14), iCloud sync toggle (rest of Issue 12), privacy doc (Issue 02), and App Store metadata (Issue 13). Distribution: free on the App Store, source on GitHub, case study on portfolio.

## Where things live

- [[Plan]] — roadmap and phases
- [[Issues]] — flat list of work items, one file per issue, with status frontmatter (Issue 15 was explored and removed; the file stays for context)
- [[Design/Philosophy|Design philosophy]] — what this is, why it looks the way it does
- [[Design/Spirit|The spirit]] — the cloud character: ratio model, eye scaling, sparkle field, milestones
- [[Design/Design system|Design system]] — colors, type, color logic
- [[Engineering/Architecture|Architecture]] — SwiftUI app shape, sync strategy, native vs WebView trade-offs
- [[Engineering/Data model|Data model]] — Hit entity, rolling windows, waking-day grouping
- [[Engineering/Notifications|Notifications]] — immediate + scheduled, overnight hedge
- [[Case study]] — portfolio writeup outline
- [[Notes]] — private scratch
- [[Prototype]] — Scriptable prototype docs (the system that already runs)

## Related projects

[[../Linger/README]] — a sibling app for on/off duration tracking (Invisalign-style). Started as Drift's `duration-mode` branch and was split into its own repo so each app can have a focused identity. The split decision is a good design story for the case study.

## Quick context

The prototype is two Scriptable scripts in iCloud:
- `vape-log.js` — silent background logger triggered by the iOS Action Button
- `vape-stats.js` — HTML dashboard rendered in a WebView

The native rebuild keeps the same data model, same visual language, same notification logic, but loses the Scriptable dependency and adds: App Intents for Lock Screen / Shortcuts logging, a Home Screen widget, CloudKit sync, native charts, native particle rendering for the sparkle field.

See [[Prototype]] for the full Scriptable docs (which double as the spec for the rebuild).

## Naming

**Drift** — verb (cloud drift, drifting between hits) and noun (a slow change, a mood). Avoids vape-specific framing for App Store.
