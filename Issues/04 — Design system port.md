---
status: done
priority: high
tags: [foundation]
---

# Design system port

Port the prototype's design tokens to a SwiftUI design system. Source of truth: [[Design system]].

## Tasks

- [x] `Color+Drift.swift` — `Color(hex:)` helper + every named token. Mirrored on `ShapeStyle where Self == Color` so `.foregroundStyle(.driftInk)` works. Dropped `driftPeachDeep` (too close to coral; folded into coral's role).
- [x] `LinearGradient` constants — `.driftSky` (4-stop body gradient) and `.driftSunHaze` (top overlay)
- [x] Card style as a `ViewModifier` (`.driftCard()`) — padding, ultra-thin material under tinted cream, white inner border, layered shadows
- [x] `Font+Drift.swift` — `.driftDisplay` (80), `.driftStatNum` (52), `.driftBestNum` (22), `.driftCardTitle` (Caveat 24), `.driftLabel` (13), `.driftSub` (12). Tracking applied at call site via `.tracking()` on `Text`.
- [x] Bundled Quicksand + Caveat as variable fonts; registered at runtime in `DriftApp.init()` via `CTFontManagerRegisterFontsForURL` (no Info.plist surgery needed against auto-generated plist).
- [x] `DesignSystemShowcase.swift` — visual spec sheet wired into `ContentView`; doubles as case-study artifact.
- [ ] Milestone glow modifiers (`.wakingGlow`, `.overallGlow`) — **deferred to Issue 14** (need the milestone state and the targets they apply to)
- [ ] Bar-chart corner-rounding helper — **deferred to Issues 09/10** (need the actual `Chart` surface)

## Tests

Snapshot a small "design system showcase" screen showing every color, font size, and card style. This is the spec sheet, and useful in the case study screenshots.

## Out of scope

- Dark mode (the design is a light sky; dark mode is v1.1)
- Dynamic Type at extreme sizes (clamp at .accessibility1)
