---
status: todo
priority: medium
tags: [polish]
---

# Onboarding, settings, app icon

Polish layer. Pre-launch.

## Onboarding

A single screen on first launch:

1. **The hero**: a static spirit at low ratio, small "Drift" wordmark, subtitle: "Notice the gaps."
2. **One paragraph**: what it does. "Tap once to log a hit. Drift shows you the time between, the average, and your records. The cloud spirit gets happier the longer you've gone." Or similar — keep it human.
3. **Privacy line**: "Everything stays on your device. iCloud sync is off by default."
4. **Two buttons**: "Enable notifications" (requests permission), "Get started" (skip notifications, can enable later in settings).

Skip onboarding entirely on subsequent launches.

## Settings screen

- [ ] **Sync iCloud** — toggle, default off. Toggling on triggers CloudKit setup.
- [ ] **Rolling window length** — picker: 7 / 14 / 30 / 60 days, default 30
- [ ] **Sleep window** — two `DatePicker(.hourAndMinute)` fields, default 23:00 and 06:00
- [ ] **Notifications** — master toggle + per-type toggles
- [ ] **About** — link to privacy policy (Safari), GitHub repo, app version
- [ ] **Reset data** — destructive button with confirmation. Deletes all hits.

## App icon

- [ ] Design icon: stylized cloud spirit on warm cream / sky-blue background. Soft, recognizable at 60×60.
- [ ] Tinted icon variant (iOS 18) — monochrome silhouette
- [ ] Dark icon variant — same spirit on a deep-blue night sky maybe
- [ ] All 14 required sizes via Asset Catalog

## Out of scope

- Multiple themes (just the Ghibli sky)
- Custom app icons
- Tutorial / hand-holding beyond the one onboarding screen
