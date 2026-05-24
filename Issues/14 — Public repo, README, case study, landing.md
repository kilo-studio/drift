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
- [x] **Repo public** — flipped 2026-05-23 (`kilo-studio/drift`).
- [x] **Pin repo Topics**: `swiftui`, `swiftdata`, `ios`, `harm-reduction`, `mindfulness` (set 2026-05-24).
- [x] **Issues enabled, public**.

## Landing + privacy on GitHub Pages — **dropped**

The `docs/` Pages site (landing + privacy + css) was built then **torn down** to keep surfaces minimal (see Issue 02). Privacy is served directly from the repo blob (`Privacy.md`), which is what the in-app About link points at. No Pages site, no custom domain. If a landing page is ever wanted, it'd be a fresh decision, not a v1 item.

## README polish

- [x] **Hero** — a centered row of three phone screenshots at the top of the README (dashboard · long-stretch · history).
- [x] **Screenshots gallery** — a 5-shot `## Screenshots` section (onboarding spirit · dashboard · long-stretch · charts · history). Web-sized assets live in `assets/screenshots/` (downscaled to 600px wide).
- [x] **Vocabulary** — README prose uses "drift" to match the shipped in-app labels.
- [ ] **App Store badge** — add the official "Download on the App Store" badge + link in the Status section once Apple approves (currently the Status section says "submitted, awaiting review").

## Case study writeup

The long-form portfolio piece lives on the personal portfolio site, not in this repo. Outline + draft stay in the gitignored `Case study.md`. The README links out to it once published.

Highest-leverage stories to tell in the case study:

- The iteration history — the joy-ladder design → continuous ratio model. Best single design story.
- The overnight notification rule, and its evolution: first we softened the wording ("if you're still awake…"), then realized silence is cleaner and made celebrations simply not fire during sleep. False praise is worse than no praise. Shows real product thinking, not just code.
- The data-loss incident and the migration plan that came out of it. Engineering-side story.
- The Drift → Linger split — what counted as enough difference to warrant a sibling app.

## Soft launch

- [ ] Post once on personal Twitter/Bluesky linking the case study.
- [ ] Submit to one or two thoughtful indie-app newsletters (Indie iOS Devs, smol-software lists).
- [ ] Don't push it; the portfolio piece is the durable artifact, not the launch moment.
