---
status: doing
priority: medium
tags: [polish]
---

# Onboarding, settings, app icon

Polish layer. Pre-launch.

> **Implementation status:** Settings tab + Behavior, Notifications, About, Reset, and Export rows are in. App icon is in (Drift.icon Icon Composer bundle dropped into the Xcode target, App Icon build setting set to `Drift`). iCloud sync toggle and the first-launch experience still remain.

## Onboarding

First-time UX is in scope for v1. **The previous attempt — a 7-step pager (welcome → Action Button setup → widget → notifications → privacy → tip jar → hand-off) — is ruled out.** It felt like a checkpoint maze for a quiet app and added friction up front, which is exactly the tone we're avoiding. Don't reintroduce that shape.

What still needs to land:

- A first-time experience that feels like a continuation of the app's voice — quiet, gentle, present-tense. Not a wizard.
- The **Action Button binding** is the single highest-leverage thing onboarding must do: users who don't bind it don't log via the path the app is designed around. The first attempt's animated iOS Settings walkthrough was the right idea on the wrong surface.
- **Notifications permission** should be requested at a moment that justifies it (e.g. right after the user logs their first hit, when the value of "we'll celebrate the gap" is concrete), not at first launch.
- **Privacy + tip jar** still need surfaces somewhere — they were screens in the pager but could just as well live as Settings rows the first-time user is gently pointed to.

Design direction TBD. Constraints / smells to avoid based on the previous attempt:

- **Pager-style step counters** ("1 of 7") feel like a setup checklist; they fight the tone.
- **Modal overlays that block the dashboard** are heavier than the moment usually warrants.
- **Multiple skip buttons** add cognitive load even when each one is individually friendly.
- The app's empty state already does *some* of this work — whatever the new shape is, it should compose with that, not replace or duplicate it.

A persisted `drift.onboarding.complete` flag is still the right gating mechanism whatever the shape ends up being.

## Settings screen

- [x] Lives as a **fourth tab** in the existing `TabView`, between History and the trailing `Tab(role: .search)` + slot. Layout: home / history / settings / +. Apple Music's pattern as the reference — multiple destination tabs plus the search-role trailing slot for a focused secondary action.
- [x] Bottom bar **minimizes on scroll-down** (Apple Music-style) via `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView`.
- [x] Visual chrome mirrors HistoryView: sky background + AmbientLayer + Caveat hero label, then sectioned `driftCard` containers (no per-section headers — they fought with the page title; rows self-describe).
- [x] Each row uses two new design-system tokens: `driftRowLabel` (Quicksand-SemiBold 16) and `driftRowDescription` (Quicksand-Medium 14, on `driftInkSoft`). `driftCard`'s outer padding is uniform 20pt; rows are edge-flush and a divider with 10pt vertical padding handles inter-row breathing.
- [x] Picker rows split: label + description stay static on the leading edge, only the trailing value + chevron are the `Menu`'s tap target — keeps the label visible when the menu is open.

### Behavior

- [x] **Use sessions** — toggle, default **on**. Implemented via `useSessions: Bool` on `HitStore` plus `effectiveSessionThreshold`, which collapses to `0` when sessions are off so `sessions(threshold: 0)` yields one-hit sessions and every metric becomes hit-based without parallel implementations. See [Issues/16 — Sessions vs individual hits](16%20%E2%80%94%20Sessions%20vs%20individual%20hits.md#the-use-sessions-toggle).
- [x] **Session threshold** — picker: 1 / 3 / 5 / 10 / 15 / 30 minutes, default 5. **Hidden when "Use sessions" is off.** Persisted as `drift.session.thresholdSec`.
- [x] **Rolling window length** — picker: 7 / 14 / 30 / 60 days, **default 7**. Drives the "X-day avg" stat card, `wakingAvgSec`, `avgSessionsPerDay`, `avgHitsPerDay`, and the rolling-avg chart's smoothing window.
- [x] **Sleep window** — two hour pickers (*bedtime* + *wake up*), default 23 and 6. `sleepEndHour` drives the waking-day cutoff in `wakingDayKey` / `currentWakingDayKey` / `endOfWakingDay`. Both drive the notification overnight hedge in `NotificationScheduler.isOvernight`. Changing `sleepEndHour` recomputes records since waking-day buckets shift. Hour-only granularity (DatePicker minute precision deferred — comparisons only need hours).
- [x] `HitStore.init` now ends with `recomputeRecords()` so persisted records re-sync with the *current* settings on every launch — covers settings changes between sessions.

### Notifications

- [x] **Notifications** — master toggle (`notifsEnabled`). Off ⇒ scheduler cancels pending and short-circuits, including the permission prompt.
- [x] **Immediate (on log)** — per-type toggle (`notifsImmediateEnabled`).
- [x] **Beat your average** — per-type toggle (`notifsBeatAverageEnabled`) + **timing offset** picker (`notifsBeatAverageOffsetSec`): *right at average / +1 min / +5 min / +10 min / +15 min*. Default **+1 min**. Replaces the hard-coded +60s constant in `scheduleBeatAverage`.
- [x] **Beat your record** — per-type toggle (`notifsBeatRecordEnabled`) + **timing offset** picker (`notifsBeatRecordOffsetSec`), same options. Default **right at** (0). Replaces the hard-coded +1s in `scheduleBeatRecord`.
- [x] Settings flips call `NotificationScheduler.cancelPending()` so prior schedules don't fire under stale prefs; the next hit reschedules with current settings.
- [ ] *Customizing notification body text is deferred — not v1.*

### Data

- [ ] **Sync iCloud** — toggle, default off. Toggling on triggers CloudKit setup.
- [x] **Reset data** — destructive button with confirmation alert; calls `HitStore.resetEverything()`.

### About

- [x] Link to privacy policy (Safari) — placeholder URL until hosted (Issue 02 / Issue 14).
- [x] Link to GitHub repo — placeholder URL until repo is public.
- [x] App version (CFBundleShortVersionString + CFBundleVersion).

## App icon

- [x] Design icon: stylized cloud spirit on warm cream / sky-blue background. Soft, recognizable at 60×60.
- [x] Authored in Icon Composer as a `Drift.icon` bundle (single source, all variants generated from it — including tinted and dark)
- [x] Dropped into the Xcode target at the project root (alongside `DriftApp.swift`); App Icon build setting points to `Drift`
- [x] Replaces the old `AppIcon.appiconset` (Xcode 16+ prefers the `.icon` file when both exist)

## Tip jar

Drift is free, no ads, no data collection. An optional "support Drift" CTA needs two homes:

- **Onboarding**: penultimate screen, framed in keeping with the app's tone — "Drift is free, no ads, no data. If you'd like to support it, here's how." Always skippable; never gates the next screen.
- **Settings → About card**: a permanent "Support Drift" row that lives alongside privacy / github / version. Users who want to come back to it later have an obvious home.

**Open implementation question**: two viable paths.

1. **IAP consumable tip jar.** Three or four preset amounts (e.g. $0.99 / $2.99 / $4.99). Each is a consumable In-App Purchase product set up in App Store Connect. StoreKit 2 inside the app. Apple takes 30% (15% for small developers). Standard pattern used by Overcast, Olivetti, Fenix, etc. Cleanest UX — stays in-app. Requires Apple Developer Program enrollment, App Store Connect product setup, and a few hours of StoreKit code.
2. **External link to a sponsorship platform.** Buy Me a Coffee, GitHub Sponsors, Ko-fi, or a Stripe Payment Link. Settings row opens Safari. No Apple cut. Allowed for free apps that don't sell digital content. Trivially fast to ship — one button. Kicks the user out of the app, which feels slightly off for the tone.

For v1 the external link is the pragmatic shortcut; IAP is the cleaner end-state and can replace the external link later without changing the UI shape (same row, different action).

## Out of scope

- Multiple themes (just the Ghibli sky)
- Custom (user-selectable) app icons
