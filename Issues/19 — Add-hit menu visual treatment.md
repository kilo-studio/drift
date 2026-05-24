---
status: done
priority: medium
tags: [design, polish, design-system]
---

> **Done.** `AddHitSheet` was rewritten from a Form to the Drift sheet
> vocabulary (sky `ZStack` background, Caveat hero label, `SettingsCard`s,
> solid-coral CTA — matching Notifications / Settings), and now opens at a
> half-height `.medium` detent (draggable to `.large`) with a grabber.

# Add-hit menu visual treatment

The menu / sheet that appears when tapping the trailing **+** tab feels system-default — sharp edges, system fonts, default backgrounds — instead of carrying the Drift design vocabulary (Quicksand + Caveat, sky tints, `driftCard` glass, the soft ink palette). It reads as a different app.

## Where it lives

- Trigger: `app/Drift/Drift/ContentView.swift` — tapping `Tab(role: .search)` flips `showAddSheet = true`, presenting `AddHitSheet`.
- Sheet definition: `app/Drift/Drift/App/HistoryView.swift` — `AddHitSheet` lives here (groomed with the "add forgotten hit" flow that History also surfaces).
- Reference for the Drift sheet vocabulary: `NotificationsView` (presented from Settings) — same sky background via `.presentationBackground(.driftSkyLowerMid)`, `Text.caveat` page title, `SettingsCard`-style rows.

## What "match the app" means concretely

- **Background.** `.presentationBackground(.driftSkyLowerMid)` so the sheet reads as a continuation of the surface, like the Notifications sheet does.
- **Title.** `Text.caveat("add hit")` (or whatever the page is called) styled with `.driftHeroLabel`, left-aligned with the same top padding as Settings.
- **Cards over plain rows.** Wrap groups of controls in `SettingsCard` (or the new equivalent) so the look matches Settings / History day cards.
- **Typography.** Labels in `.driftRowLabel`, descriptions in `.driftRowDescription`, primary destructive / commit actions in `.driftCoral` when they're a "do it" CTA, neutral `.driftInk` for non-destructive.
- **Buttons.** Match the visual rhythm of Settings buttons — no system blue tinted buttons; either tap-the-whole-row patterns (`.buttonStyle(.plain)`) or a single coral-tinted primary action at the bottom.
- **Pickers.** If we still expose a date/time picker for adding a past hit, style it consistent with how `SettingsPickerRow` presents its menu — same row chrome, same divider treatment.
- **Ambient layer.** Consider whether the add sheet should show the same drifting clouds / stars background as the main app surfaces. Probably yes for the full-screen sheet, no for a compact bottom-anchored one. Decide once we pick a layout.

## Open question — layout

Two reasonable directions, pick during design:

1. **Bottom sheet with `.presentationDetents([.medium])`** — single-step "tap to log now" plus a small "log at a different time" affordance that expands into a date picker. Fast, tap-and-dismiss.
2. **Full-screen sheet** with the same ambient layer + spirit positioning as Home, more breathing room. Heavier but more on-brand.

The current implementation is closer to (1) but the styling makes it feel like neither.

## Acceptance

- Open the add sheet, compare side-by-side with Settings and Notifications sheets — same colors, same typography, same card chrome.
- Nothing in the sheet reads as a system default (no SF Pro labels, no system blue buttons, no white background, no system date picker without surrounding card chrome).

## Out of scope

- Changing what the sheet does (it logs hits — past and now). This is purely visual treatment.
- Reworking the trailing + tab slot itself; that already matches via `Tab(role: .search)` styling.
