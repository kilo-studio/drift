---
status: done
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
- [x] **Privacy policy text** lives in `Privacy.md` at repo root
- [x] **Hosting** — no Pages site. Repo is public (flipped 2026-05-23), so `Privacy.md` is served directly by GitHub at https://github.com/kilo-studio/drift/blob/main/Privacy.md. GitHub Pages + the `docs/` site (landing + privacy + css) were briefly set up then torn down to keep surfaces minimal — the only things to maintain are the repo (README + Privacy.md) and the app.
- [x] **Update `SettingsView` privacy URL** — now `https://github.com/kilo-studio/drift/blob/main/Privacy.md` (change is in the uncommitted SettingsView edits; commits with the rest of the settings work)
- [x] **Policy describes iCloud sync** — the CloudKit section in `Privacy.md` matches the shipped behavior: **always-on private-iCloud sync, no in-app toggle** (disable per-app in iOS Settings → iCloud); only hits sync, derived metrics recompute per device; data never reaches a server we run, so **"Data Not Collected" still holds** (private CloudKit ≠ developer collection). Updated 2026-05-24 from the earlier "off by default, in Settings" framing when sync went always-on (Issue 12).

## Pre-public history scrub (2026-05-23)

Before flipping `kilo-studio/drift` public, rewrote history with `git filter-repo`
to remove files that should never be public but were in old commits:
- `prototype/vape-log.json` — real personal hit log (~385 timestamps). Now gitignored.
- `CLAUDE.md`, `Plan.md`, `Case study.md` — internal/assistant docs (already
  removed from the tip in `940006b`, but lingered in history).

All local copies were preserved (the rewrite only touches committed history). A
fresh clone of origin was audited clean afterward. All commit SHAs changed — the
old pre-scrub tips are orphaned.

## Privacy policy outline

1. We collect nothing. The app stores your hit timestamps on your device.
2. If you turn on iCloud sync, the data syncs through your iCloud account using CloudKit. We never see it.
3. No analytics, no crash reporting that includes user data, no third-party services.
4. Notifications are scheduled locally — Apple handles delivery.

Plain language. One page. Link from settings + App Store description.

## Out of scope

- HealthKit integration (adds review friction without much user benefit)
- Export/import features (v1.1 maybe)
