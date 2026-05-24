---
status: resolved
priority: low
tags: [polish, design-system, icon]
---

# Icon tinted variant + appiconset cleanup

## Resolution (2026-05-24)

**The original diagnosis below was wrong, and the placeholder was a non-issue.**
The Control Center "Open Drift" tile showed a grid placeholder, but the icon and its
tinted variant were fine all along:

- The iOS 26 `.icon` (Icon Composer) format **auto-derives** the Tinted/monochrome
  appearance from the layers. A Debug build's `Assets.car` contains
  `ISAppearanceTintable` (plus `UIAppearanceAny` / `UIAppearanceDark`) renditions even
  though `icon.json` has no explicit `appearances` block.
- The tinted glyph renders correctly in Icon Composer **and** on the device Home Screen
  in tinted appearance mode.
- The Control Center placeholder was purely a **stale Control Center icon cache**.
  Removing the tile and **rebooting the device** cleared it; the cloud glyph then
  rendered correctly. Not related to App Store / TestFlight — these surfaces behave
  identically in development builds.

No icon authoring work is needed. The only optional leftover is the cosmetic widget
appiconset cleanup in the "Secondary cleanup" section below.

---

## Original (incorrect) diagnosis — kept for the record

The home screen icon renders correctly, but adding a "Open Drift" tile in Control Center (and possibly Focus mode, Lock Screen widgets, and Shortcuts thumbnails) shows a generic placeholder instead of the cloud spirit. Cause: `Drift.icon` only authors the default appearance, so iOS has nothing to derive a single-color template glyph from for surfaces that demand one.

## Root cause

`app/Drift/Drift/Drift.icon/icon.json` declares the fill gradient + two layer groups (`spirit.png`, `clouds.png`) and stops there. No `appearances` block, no Tinted layer variants, no Dark variant. iOS 18+ surfaces that render the icon as a flat template (Control Center "Open app X", Focus icon, Action Button picker thumbnail when bound to an app) have no good source to derive from, so they fall back to a placeholder.

## Fix

1. Open `Drift.icon` in Icon Composer (double-click in Finder).
2. Switch to the **Tinted** appearance in the inspector.
3. Supply a flat single-color version — a white cloud silhouette on transparent is the simplest target. The Tinted variant is rendered as a single-color shape that iOS recolors per context, so author it as monochrome.
4. While we're in there, also explicitly author the **Dark** appearance even if the auto-derived one looks fine — explicit > implicit for forward-compat.
5. Rebuild, reinstall, re-add the Control Center "Open Drift" tile (existing tile may have cached the placeholder), verify the glyph renders.

## Secondary cleanup — stale appiconset

**Main app**: already cleaned up. Xcode auto-removed the empty stubs (`AppIcon.appiconset/Contents.json` + `AccentColor.colorset/Contents.json`) during a build on 2026-05-20. Only the Icon Composer `.icon` bundle drives the icon now — the pbxproj's `ASSETCATALOG_COMPILER_APPICON_NAME = Drift` resolves to it via name, not path.

**Widget extension**: `app/Drift/DriftWidget/Assets.xcassets/AppIcon.appiconset/` still has the same kind of empty stubs (no `filename` fields). Once the Tinted variant for the main `.icon` is verified, decide whether the widget target should also point at the same `.icon` bundle (or its own) and remove this directory too.

## Related but separate

The trailing `+` tab and Action Button picker (when bound to "Log a hit in Drift") show the SF Symbol from `LogHitIntent`'s `AppShortcut` declaration:

```swift
systemImageName: "plus.circle.fill"
```

That symbol is what the user sees in Shortcuts thumbnails and Action Button preview rows — independent of the app icon. If that looks wrong too, the fix is a different SF Symbol or an `appIntentImage` parameter, not the `.icon` bundle. Out of scope for this issue.

## Acceptance

- Add "Open Drift" as a Control Center tile via the Add a Control picker → tile renders with the recognizable cloud glyph, not a placeholder.
- Set Drift as the focus icon for a Focus mode → cloud glyph renders.
- Bound to Action Button via the Drift app shortcut → preview row in Settings → Action Button shows a recognizable icon.
- Home screen, App Library, Spotlight, Settings list — all still render the full-color icon correctly (no regressions).
