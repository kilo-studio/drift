---
status: todo
priority: low
tags: [feature, dashboard, v1.x]
---

# Achievement system

A small, growing collection of personal records and cumulative milestones. Designed around a single rule: **every achievement only grows, none reset on a bad day**. The framing is positive reinforcement, never "you broke it."

## Philosophy fit

[[Philosophy]] previously read "no streaks." The intent was no *failure-resetting* counters, which read as shame mechanics. A clarification has been added to Philosophy.md separating that from cumulative achievements that only accumulate.

The two-line rule:
- ✅ Achievements that only grow / unlock once and stay
- ❌ Counters that drop to zero when you have a bad day

## Two axes

Once we adopt the session model from [[Issues/16 — Sessions vs individual hits]], there are two real axes of progress and the achievement system should track both:

- **Frequency** — how often you have a session. Captured by gaps between sessions, longest waking, average per day.
- **Intensity** — how much you hit per session. Captured by avg hits-per-session, biggest session of the day, runs of solo-hit sessions.

Frequency is what the spirit visualizes (time since last session). Intensity is invisible to the spirit on purpose — it's a looking-back dimension that lives entirely in achievements.

## Achievement types

### Personal records — ratchets that only improve

**Frequency axis:**
- [x] Longest waking gap (already in hero)
- [x] Longest overall gap (already in hero)
- [ ] **Lowest rolling-7d sessions/day ever** — track in `HitStore`. Update when current 7d sessions-per-day is below the persisted record.
- [ ] **Lowest rolling-30d sessions/day ever** — same shape, longer window.
- [ ] **Lowest single-day session count ever** — fewest sessions in any complete day. Updated nightly at the 4am cutoff. Show with date.

**Intensity axis:**
- [ ] **Lowest rolling-30d avg hits-per-session ever** — the headline intensity metric. Watching this number drift downward over months is the long-form reward.
- [ ] **Smallest "biggest session of the day" record** — your worst session today had N hits, and your record-low for "biggest session of any day" is X.
- [ ] **Most consecutive solo-hit sessions** — sessions of length 1 in a row, all-time record.

### One-time milestone unlocks

Each unlocks once and persists forever. The first time you cross a threshold — that moment becomes part of your record.

**Frequency axis:**
- [ ] First time `ratio >= 1` (matched your average)
- [ ] First time `ratio >= 5` (5× your average — meaningful)
- [ ] First time `ratio >= 10` (10× — rare for typical users)
- [ ] First time you logged fewer than half your typical-day session count in a complete day
- [ ] First time your rolling-7d sessions/day dropped below your all-time average
- [ ] Set a new longest-waking record (1st time, 5th time, 10th time …)

**Intensity axis:**
- [ ] First time you ended a session at exactly 1 hit (a solo-hit session)
- [ ] First time your daily avg hits-per-session dropped below 3
- [ ] First time your daily avg hits-per-session dropped below 2
- [ ] First time you held a session to fewer hits than your previous rolling-30d avg

### Cumulative counters — only grow, never decrease

- [ ] **Days drifted under average** — count of days whose session count was below the rolling-30d average. Lifetime total.
- [ ] **Total time drifted** — sum of every inter-session gap that was ≥ 1× your waking average. A big satisfying number that always grows.
- [ ] **Total solo-hit sessions** — lifetime count of sessions of length 1.

### Optional: soft "current run"

If we want a single streak-shaped thing, frame it as a record:

- [ ] **Best run of days under average** — store all-time best, optionally show current. Current can drop to zero but the framing is "best: 12 days" prominently with "current: 3 days" smaller and dimmer. The reset isn't a failure event, just data.

I'd skip this for v1.x. Cumulative counters cover the same emotional space without any reset moment.

## UI placement

Two options:

1. **Achievements card** at the bottom of the dashboard, with recently-unlocked milestones and a "see all" link.
2. **Dedicated Achievements screen** accessed via a small icon in the top-right of the hero.

**Lean option 2.** Keeps the dashboard focused on the spirit + current state. Achievements are something you visit when you want to look back, not something you check obsessively.

Visual style: soft cream cards, gentle painted-style icons. Avoid badge-grid game aesthetic. Each achievement could be its own small "sticker" with the Ghibli warmth — a flower for waking-related, a moon for overnight, a sparkle for ratio milestones.

## Notification policy

Achievements unlock **silently** — no notifications. The user discovers them on next dashboard visit. We've already been careful about notification trust ([[Notifications]] hedges, baseline gates) — adding achievement notifications would undo that work.

If wanted: optional toggle "notify me when I unlock an achievement," default off.

A subtle in-app indicator is fine: a coral dot on the Achievements icon when there are new unlocks since last visit. Tap to dismiss.

## Out of scope

- **Levels / XP / point system.** Quantification of "how good you are" is exactly the framing we avoid.
- **Sharing / social.** Out of scope, ever.
- **Rewards that unlock app features.** No paywall, no "unlock a new spirit color." The spirit is the spirit.

## Implementation notes

- New SwiftData model: `Achievement { id, type, unlockedAt, value? }`
- Evaluation hook on every `HitStore.append` for "first time" conditions
- Nightly background task (or first-launch-of-day eval) for daily/weekly ratchets
- Persistent records (`lowest7dAvg`, etc.) update when the metric is recomputed
- Achievements screen: SwiftUI `List` grouped by category, each item shows icon + title + unlock date + (for ratchets) the current value

## Sequencing

**v1.x, not v1.** v1 ships the spirit + dashboard + logging + notifications first. Achievements are additive — nothing about the v1 design depends on them.

If we want exactly one achievement-style thing in v1, the highest-leverage choice is **lowest rolling-30d sessions/day ever**. It's the most honest measure of "are you actually drifting more than you used to" and it pairs naturally with the existing waking-gap card. Could even be displayed inline: "30d avg: X sessions/day · best ever: Y".

A close second is **lowest rolling-30d avg hits-per-session ever** — captures the intensity axis, which the spirit can't show, with the same one-number-pair display: "30d avg: 4.2 hits/session · best ever: 3.1".
