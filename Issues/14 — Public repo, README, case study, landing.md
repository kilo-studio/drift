---
status: doing
priority: medium
tags: [portfolio]
---

# Public repo, README, case study, landing

The portfolio layer. Half the value of this project lives outside the app.

## Public GitHub repo

- [x] **License: MIT** (`LICENSE` at repo root).
- [x] **README rewritten for public audience** — what the app is, the spirit metaphor, features, privacy stance, status, tech stack, build instructions, project structure, design-philosophy links, contributing notes, license, acknowledgments, contact. Wikilinks replaced with relative markdown links so they resolve on GitHub.
- [x] **Internal docs gitignored** — `CLAUDE.md`, `Plan.md`, `Case study.md` stay locally as planning artifacts but don't ship to public.
- [x] **Repo structure** matches:
  ```
  drift/
  ├── app/Drift/          ← Xcode project
  ├── prototype/          ← Scriptable scripts (the journey)
  ├── Design/             ← philosophy, spirit, design system
  ├── Engineering/        ← architecture, data model, notifications, migration
  ├── Issues/             ← per-feature work items
  ├── docs/               ← GitHub Pages landing + privacy page
  ├── README.md
  ├── Privacy.md
  └── LICENSE
  ```
- [ ] **Flip repo visibility to public** (currently `kilo-studio/drift` is private; GitHub Pages on free plans requires public).
- [ ] **Pin repo Topics**: `swiftui`, `swiftdata`, `ios`, `harm-reduction`, `mindfulness`.
- [ ] **Issues enabled, public** — once repo is public.

## Landing + privacy on GitHub Pages

- [x] `docs/index.html` + `docs/privacy.html` + `docs/styles.css` — Drift-styled supporting docs site under `docs/`. Mirrors the app's design tokens (sky gradient, sun haze, cream cards, Quicksand + Caveat, coral links). Dark mode mirror in CSS.
- [ ] **Enable Pages in repo settings** → Source = `main` / `/docs` (after the visibility flip).
- [ ] **Optional**: custom domain (e.g. `drift.kilo.studio` or `drift.app`) with DNS + Pages settings.
- [ ] **Update `SettingsView`'s hardcoded privacy URL** to the live Pages URL once published.

## README polish

- [ ] **Hero screenshot or recorded GIF** at the top of the README. Currently text-only. The spirit + sparkles scaling with ratio is the visual story.
- [ ] **App Store badge** once shipped (in the Status section).
- [ ] **Screenshots gallery** — 3-4 well-composed shots (hero, history, settings, spirit at high ratio).

## Case study writeup

The long-form portfolio piece lives on the personal portfolio site, not in this repo. Outline + draft stay in the gitignored `Case study.md`. The README links out to it once published.

Highest-leverage stories to tell in the case study:

- The iteration history — the joy-ladder design → continuous ratio model. Best single design story.
- The notification overnight hedge — false praise is worse than no praise. Shows real product thinking, not just code.
- The data-loss incident and the migration plan that came out of it. Engineering-side story.
- The Drift → Linger split — what counted as enough difference to warrant a sibling app.

## Soft launch

- [ ] Post once on personal Twitter/Bluesky linking the case study.
- [ ] Submit to one or two thoughtful indie-app newsletters (Indie iOS Devs, smol-software lists).
- [ ] Don't push it; the portfolio piece is the durable artifact, not the launch moment.
