---
status: doing
priority: medium
tags: [polish]
---

# Onboarding, settings, app icon

Polish layer. Pre-launch.

> **Implementation status:** Settings tab + Behavior, Notifications, About, and Reset
> rows are in. iCloud sync, onboarding, and the app icon remain — those are phase 6
> of the build sequence and the only blockers between this issue and Issue 13 (App
> Store submission).

## Onboarding

A single screen on first launch:

1. **The hero**: a static spirit at low ratio, small "Drift" wordmark, subtitle: "Notice the gaps."
2. **One paragraph**: what it does. "Tap once to log a hit. Drift shows you the time between, the average, and your records. The cloud spirit gets happier the longer you've gone." Or similar — keep it human.
3. **Privacy line**: "Everything stays on your device. iCloud sync is off by default."
4. **Two buttons**: "Enable notifications" (requests permission), "Get started" (skip notifications, can enable later in settings).

Skip onboarding entirely on subsequent launches.

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

- [ ] Design icon: stylized cloud spirit on warm cream / sky-blue background. Soft, recognizable at 60×60.
- [ ] Tinted icon variant (iOS 18) — monochrome silhouette
- [ ] Dark icon variant — same spirit on a deep-blue night sky maybe
- [ ] All 14 required sizes via Asset Catalog

## Out of scope

- Multiple themes (just the Ghibli sky)
- Custom app icons
- Tutorial / hand-holding beyond the one onboarding screen
