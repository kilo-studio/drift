---
status: todo
priority: high
tags: [foundation]
---

# Design system port

Port the prototype's design tokens to a SwiftUI design system. Source of truth: [[Design system]].

## Tasks

- [ ] `Color+Drift.swift` — extension on `Color` for every named token (`.driftCoral`, `.driftPeach`, `.driftSage`, `.driftSageDeep`, `.driftInk`, `.driftInkSoft`, `.driftInkFade`, `.driftCream`, `.driftCreamWarm`, sky stops). Use `Color(hex:)` helper.
- [ ] `LinearGradient` constants for the body sky gradient and the sun-haze overlay
- [ ] `Font+Drift.swift` — `.driftDisplay`, `.driftStatNum`, `.driftBestNum`, `.driftCardTitle` (Caveat), `.driftLabel`, `.driftSub`. All concrete sizes baked in.
- [ ] Bundle Quicksand 500/600 and Caveat 500/600 as TTFs in the app — don't depend on Google Fonts at runtime
- [ ] Card style as a `ViewModifier` (`.driftCard()`) — handles padding, blur background, border, shadow
- [ ] Milestone glow modifiers: `.wakingGlow(on: Bool)` and `.overallGlow(on: Bool)` that apply the right `.shadow` or `.background` for text-shadow halos
- [ ] Bar-chart corner-rounding helper (rounded top, flat bottom) — use `Chart` with `.cornerRadius` and `RoundedRectangle` clip if needed

## Tests

Snapshot a small "design system showcase" screen showing every color, font size, and card style. This is the spec sheet, and useful in the case study screenshots.

## Out of scope

- Dark mode (the design is a light sky; dark mode is v1.1)
- Dynamic Type at extreme sizes (clamp at .accessibility1)
