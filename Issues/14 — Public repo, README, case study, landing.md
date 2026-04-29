---
status: todo
priority: medium
tags: [portfolio]
---

# Public repo, README, case study, landing

The portfolio layer. Half the value of this project lives outside the app.

## Public GitHub repo

- [ ] Make `Drift` repo public — kilo-studio/drift or griffinmullins/drift
- [ ] License: **MIT** (most permissive, signals "feel free to fork")
- [ ] Repo structure:
  ```
  drift/
  ├── app/             ← Swift native source
  ├── prototype/       ← copy of the Scriptable scripts (preserve the journey)
  ├── docs/            ← case study, design notes (extracted from this folder)
  ├── README.md
  └── LICENSE
  ```
- [ ] Pin a couple of repo Topics: `swiftui`, `ios`, `harm-reduction`, `obsidian-friendly` (kidding on the last)
- [ ] Issues enabled, public

## README as designed artifact

This is the front door of the portfolio piece. It's not a quickstart guide — it's a designed page on a public repo.

- [ ] Hero screenshot at the top (spirit + timer in a magical state)
- [ ] One-line tagline
- [ ] 3-paragraph "what + why"
- [ ] Embedded video / GIF of the spirit scaling with ratio (record from simulator at the debug slider)
- [ ] Section: "Design rationale" — link to the deeper case study, summarize the 3–4 most interesting decisions
- [ ] Section: "Architecture" — the SwiftUI shape, native vs WebView decision, the data model in 1 paragraph
- [ ] Section: "The journey from Scriptable" — embed a screenshot of the prototype next to the rebuild
- [ ] App Store badge once shipped
- [ ] Footer: links to landing, case study, personal site

## Case study writeup

A long-form piece on the personal portfolio site. Outline lives in [[Case study]].

- [ ] Convert that outline to a polished post
- [ ] 6–10 carefully selected screenshots, captioned
- [ ] Include the iteration history — the joy ladder → continuous ratio model is the best story
- [ ] Include the notification false-positive bug + fix (the overnight hedge) — shows real product thinking, not just code

## Landing page

GitHub Pages, single HTML file at `kilo.studio/drift` or similar.

- [ ] Hero: large screenshot, name, tagline, App Store badge
- [ ] 3 short feature blurbs with screenshots
- [ ] Privacy section — the same sentence used in the App Store description
- [ ] Footer: links to source, case study, portfolio, support email/issues

## Soft launch

- [ ] Post once on personal Twitter/Bluesky linking the case study
- [ ] Submit to one or two thoughtful indie-app newsletters (Indie iOS Devs, smol-software lists)
- [ ] Don't push it; the portfolio piece is the durable artifact, not the launch
