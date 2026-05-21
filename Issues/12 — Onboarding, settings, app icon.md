---
status: doing
priority: medium
tags: [polish]
---

# Onboarding, settings, app icon

Polish layer. Pre-launch.

> **Implementation status:** Settings tab + Behavior, Notifications, About, and Reset
> rows are in. App icon is in (Drift.icon Icon Composer bundle dropped into the
> Xcode target, App Icon build setting set to `Drift`). iCloud sync and the
> onboarding flow remain.

## Onboarding

**Scope grew during planning.** The original single-screen spec wasn't enough — the highest-leverage thing onboarding has to do is teach users how to bind "Log a hit" to the iOS Action Button, because users who don't bind it don't actually log. So onboarding becomes a multi-screen pager:

1. **Welcome**: spirit hero, "Drift" wordmark, one-paragraph what-it-is.
2. **Action Button setup**: animated walkthrough showing how to bind "Log a hit" in iOS Settings → Action Button. This is the critical screen. Show the actual iOS Settings UI as illustration with arrows / highlights. Include a "Skip — I'll set this up later" affordance.
3. **Widget (optional)**: a one-pager explaining the Drift home-screen widget and how to add it. Skippable.
4. **Notifications**: explains the three notification types in one paragraph, then "Enable notifications" / "Not now."
5. **Privacy line**: "Everything stays on your device. iCloud sync is off by default."
6. **Hand-off**: "Tap the + tab when you take a hit. Drift takes it from there." Drops the user on an empty-state home (see follow-up: dashboard empty state).

A persisted `drift.onboarding.complete` UserDefaults flag gates the flow. Skipped entirely on subsequent launches.

## Settings screen

- [x] Lives as a **fourth tab** in the existing `TabView`, between History and the trailing `Tab(role: .search)` + slot. Layout: home / history / settings / +. Apple Music's pattern as the reference — multiple destination tabs plus the search-role trailing slot for a focused secondary action.
- [x] Bottom bar **minimizes on scroll-down** (Apple Music-style) via `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView`.
- [x] Visual chrome mirrors HistoryView: sky background + AmbientLayer + Caveat hero label, then sectioned `driftCard` containers (no per-section headers — they fought with the page title; rows self-describe).
- [x] Each row uses two new design-system tokens: `driftRowLabel` (Quicksand-SemiBold 16) and `driftRowDescription` (Quicksand-Medium 14, on `driftInkSoft`). `driftCard`'s outer padding is uniform 20pt; rows are edge-flush and a divider with 10pt vertical padding handles inter-row breathing.
- [x] Picker rows split: label + description stay static on the leading edge, only the trailing value + chevron are the `Menu`'s tap target — keeps the label visible when the menu is open.

### Behavior

- [x] **Use sessions** — toggle, default **on**. Implemented via `useSessions: Bool` on `HitStore` plus `effectiveSessionThreshold`, which collapses to `0` when sessions are off so `sessions(threshold: 0)` yields one-hit sessions and every metric becomes hit-based without parallel implementations. See [[Issues/16 — Sessions vs individual hits#The "Use sessions" toggle]].
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

## Out of scope

- Multiple themes (just the Ghibli sky)
- Custom (user-selectable) app icons
