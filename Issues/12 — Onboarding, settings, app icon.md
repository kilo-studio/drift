---
status: done
priority: medium
tags: [polish]
---

# Onboarding, settings, app icon

Polish layer. Pre-launch.

> **Implementation status:** Settings tab + Behavior, Notifications, About, Reset, and Export rows are in. App icon is in (Drift.icon Icon Composer bundle dropped into the Xcode target, App Icon build setting set to `Drift`). iCloud sync toggle and the first-launch experience still remain.

## Onboarding

First-time UX is in scope for v1.

**Previous attempt — ruled out.** A 7-step narrative pager (welcome → Action Button → widget → notifications → privacy → tip jar → hand-off) that mostly read text at the user. Pager step counters, modal overlays, multiple skip buttons. Felt like a checkpoint maze for a quiet app. Don't reintroduce that shape.

### Direction

**Functional onboarding via a carousel of cards** — each card does real work (sets a preference, requests a permission, shows a working preview), not just narrates. The spirit floats at the top of every card so the character is present from second one.

Each card's setting writes to UserDefaults immediately, so by the time the user reaches the final card the app is configured the way they wanted. Every choice is also reachable from Settings later (use a "you can change this anytime in Settings" note to lower the stakes of each card).

### Card sequence

1. **Intro.** Purpose of the app in one paragraph: "Drift helps you notice the gaps between hits and gently reduce them over time. No streaks, no shame — just a present-tense view of what's actually happening." Spirit at top, "drift" wordmark, single "let's go" CTA.

2. **Sessions vs hits.** "How do you want Drift to count?" Briefly explain that rapid hits often happen as a session, and Drift can group them. Inline `useSessions` toggle and, when on, the session-threshold picker (same control as Settings → Behavior → Use sessions). Default: sessions on, 5-minute threshold.

3. **Sleep window.** Explain the waking-gap concept — "Drift tracks both your longest overall gap and your longest *waking* gap, since most overnight gaps don't really feel like progress." Inline bedtime + wake-up hour pickers. Default: 23 / 6.

4. **Notifications.** Explain the three types in one short paragraph each (immediate confirmation, beating-your-average, beating-your-record) and the overnight hedge in one line. Master toggle to request the system permission; if approved, expose the three per-type toggles. Default suggestion: all three on.

5. **Logging a hit.** Explain that one tap or one Action Button press logs a hit, and the app updates everything. Show **how to bind the Action Button to "Log a hit in Drift"** — ideally with a button that deep-links into iOS Settings → Action Button. If the deep link isn't reliably available, fall back to a clear screenshot/illustration of the path through Settings. Secondary: an "add a Control Center shortcut" suggestion (the iOS 18+ Control Center custom controls picker) and "or run from Shortcuts" mention.

6. **Meet the spirit.** A working mini-preview, not a description. The spirit + a small sparkle field render in the card; a slider or auto-advancing animation walks through ratio states from baseline-sad → wide-eyed → fully revealed with sparkles. Caption explains the rule once: "the longer it's been since your last hit, the bigger the spirit's eyes get and the more sparkles fill the sky." No numbers, no thresholds.

7. **Conclusion.** "Happy drifting." One closing line covering privacy + the tip jar — something like: "Everything stays on your device. Drift is free and ad-free; you can support it from Settings if you'd like." Then a single CTA that closes the carousel, sets `drift.onboarding.complete`, and drops the user on Home.

### Implementation considerations

- **Carousel container:** SwiftUI `TabView(.page)` with hidden index dots and a custom progress indicator that matches the app's tone (a soft dot row, not "1 of 7"). Forward swipe always available; backward swipe optional.
- **Spirit at top:** the existing `SpiritView` can live in the onboarding container, sized smaller than home (~120pt), with its `ratio` driven either by a static value per card or — on card 6 — animated through a range.
- **Gating:** `@AppStorage("drift.onboarding.complete")` flag, default false. `DriftApp` shows `OnboardingView` until set. Existing installs with logged hits get the flag flipped true on first launch of the new build so they don't re-onboard.
- **Action Button deep link:** iOS has historically gated direct deep links to Settings pages (`App-prefs:` URL schemes are unreliable on recent iOS). Implement the deep-link button, but design the card to work without it (clear written/illustrated path through Settings).
- **Notifications permission:** request via `UNUserNotificationCenter.requestAuthorization` only when the user toggles the master switch on card 4 — not at app launch, not before they've seen what the notifications do.
- **Reset for testing:** the existing Settings → Data → Reset all data should also clear `drift.onboarding.complete` so a reset re-runs onboarding. (Confirm this is the current behavior — `HitStore.resetEverything` may need a small change.)
- **No skip affordance.** Every card has working defaults, and the carousel is swipe-driven — the user can move through fast if they want without an explicit skip control. Keeping it skip-free fits the tone better than adding a "skip setup" link.
- **Existing-hits users skip onboarding.** On first launch of the build that introduces onboarding, if `HitStore.hits` is non-empty, flip `drift.onboarding.complete = true` immediately so users restoring from backup (or coming from the pre-onboarding build) don't get a setup carousel for an app they already know.

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

- [x] **Sync iCloud** — **always on, no in-app toggle.** The container uses CloudKit `.automatic` (the user's own private CloudKit DB — privacy-preserving, we never receive a copy; matches how Apple's apps behave), with a local fallback if container creation throws. Users disable it per-app in iOS Settings → iCloud. `Hit` got default values for CloudKit compat (no migration — defaults don't change the store schema); iCloud/CloudKit capability + `remote-notification` background mode added. Verified syncing on device. (Started as a Settings toggle defaulting off + "applies next launch" alert, but SwiftData fixes CloudKit at container creation so a live toggle isn't possible and the disclaimer felt off; always-on is the platform norm and fixes the "second device sits empty" case — an empty device pulls existing records down, CloudKit merges and never overwrites.)
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
