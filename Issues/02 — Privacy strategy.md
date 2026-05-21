---
status: todo
priority: high
tags: [foundation]
---

# Privacy strategy

Lock in the data and privacy stance before any code. This is a **feature**, not a chore — see [Philosophy](../Design/Philosophy.md).

## Decisions to make

- [x] Data is local-first (SwiftData, on-device)
- [x] Sync via CloudKit, **off by default**, opt-in toggle in settings (toggle not yet shipped — policy reflects shipped state for now)
- [x] No analytics that include hit data
- [x] No third-party SDKs
- [x] Privacy nutrition labels: "Data Not Collected" honestly
- [x] **Privacy policy text drafted** in `Privacy.md` at repo root and as `docs/privacy.html` for GitHub Pages
- [ ] **Host on GitHub Pages** — pending repo visibility flip and Pages enablement (see Issue 14)
- [ ] **Update `SettingsView` privacy URL** from the placeholder to the live Pages URL once published
- [ ] **Update policy when iCloud sync ships** — current text intentionally omits CloudKit details since the toggle isn't live yet

## Privacy policy outline

1. We collect nothing. The app stores your hit timestamps on your device.
2. If you turn on iCloud sync, the data syncs through your iCloud account using CloudKit. We never see it.
3. No analytics, no crash reporting that includes user data, no third-party services.
4. Notifications are scheduled locally — Apple handles delivery.

Plain language. One page. Link from settings + App Store description.

## Out of scope

- HealthKit integration (adds review friction without much user benefit)
- Export/import features (v1.1 maybe)
