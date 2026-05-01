---
status: done
priority: medium
tags: [feature, data, v1]
---

> **Implementation:** `HistoryView` reachable from the bottom-leading list-icon
> button on the dashboard. Sessions grouped by waking day with chevron-toggle
> expansion to individual hits. Swipe a hit for Edit / Delete. + button in the
> toolbar opens an Add-hit sheet (date picker + "5 / 15 min ago / 1 hour ago"
> presets). Edit + Add reject future timestamps. Delete confirms with an alert.
> `HitStore` gains `addPast`, `editHit`, and `recomputeRecords` so the persisted
> longestGap / longestWakingGap rebuild from current sessions after any edit
> rather than relying on the simple-append rule. Multi-select / bulk delete and
> the achievement-immutability rules deferred to v1.x (achievement system isn't
> in yet).

# Hit history — view, add, edit, delete

A view of every logged hit, with the ability to add hits the user forgot to log and remove accidental ones. Pure data management — no aggregation, no visualization. Just: here are your hits, in order, edit at will.

## Why

Two real failure modes the prototype doesn't address:

1. **Accidental logs.** The Action Button or Lock Screen widget can fire from a pocket-tap or fat-finger. Without delete, the data slowly accumulates noise.
2. **Forgotten logs.** User has a session without their phone, remembers later, wants to backfill. Without retroactive add, the data slowly accumulates gaps.

Both erode trust in the metrics. Trust in the data is everything for a tracker.

## UI shape

A **History screen** accessed from a small button in the top-right of the dashboard hero (or via Settings).

Layout: scrollable list grouped by day, newest first. Sessions are visible as the unit (per [[Issues/16 — Sessions vs individual hits]]):

```
Today
├── 2:14p · session of 3 hits
├── 11:08a · solo hit
└── 9:23a · session of 5 hits  ✿ new waking record

Yesterday
├── 9:47p · session of 2 hits
└── ...
```

Each session row is tappable → expands to show individual hits with their times. Long-press or swipe → action menu: **Edit time**, **Delete**, **Cancel**.

A **+ button** in the top-right of the History screen → "Add forgotten hit" flow.

## Add forgotten hit

Modal sheet with:
- Date/time picker (`DatePicker(.dateAndTime)`)
- Quick presets: *5 min ago, 15 min ago, 1 hour ago*
- "Add" button

On confirm, insert into the hits array at the right chronological position. Recompute derived metrics. If the new hit creates a new longest-waking record, the dashboard reflects it next render — but **no notification** (silent, consistent with the achievement system).

## Delete accidental hit

Tap → confirmation alert showing timestamp + which session it was part of. Confirm → remove. Recompute.

Bulk delete: multi-select mode via long-press, select multiple, "Delete N hits" confirmation, single recompute after batch completes.

## Edit existing hit

Long-press → "Edit time." `DatePicker` defaults to current value. Save → update timestamp, recompute metrics.

Useful for: "I logged at 3pm but I actually hit at 2:55pm." Minor adjustments mostly.

## Records and edits — what survives

**Personal records (ratchets):** recompute from data. If you delete the hit that set your longest-waking record, the record drops to whatever the next-longest gap is in remaining data. Correct behavior — the record describes what's true now, not what was once true.

**One-time milestone unlocks:** **immutable.** Once unlocked, the achievement persists in the `Achievement` SwiftData store with its `unlockedAt` timestamp, regardless of subsequent edits. You never lose an achievement.

Reasoning: the moment happened. Editing data can't unwind history. This makes data cleanup feel safe — users can prune accidents without worrying about losing milestones.

**Don't notify** when a record drops. That's a punishment-shaped event we don't want.

## Edge cases

- **Editing crosses a waking-day cutoff.** Recompute waking-day buckets; the hit ends up in a different bucket. Records and stats update accordingly.
- **Editing joins/splits a session.** Sessions are always derived from current data, so this is automatic — no special handling.
- **Adding a forgotten hit far in the past** (e.g. last week). Allowed. The past is mutable.
- **Adding a hit in the future.** Reject with a friendly alert: *"Can't add hits in the future."* Future-dated entries break too many assumptions.
- **Editing during a live session.** If the user has an active session and edits a recent hit, the spirit's `lastSessionEnd` recomputes — the spirit may visibly shift state. Acceptable.

## Trust note

The same edit/delete tools that allow legitimate cleanup also allow gaming the system (e.g. delete an unflattering hit, set a fake longest-waking). Drift trusts the user. There's no need to fight this — the data is for them, not us. We're not policing.

## Implementation notes

- `HitStore.delete(hit)`, `HitStore.edit(hit, newDate:)`, `HitStore.add(at: Date)` — all update the SwiftData store and recompute cached metrics
- History screen: `List` with sections grouped by waking-day key, expanded sessions render hits as a nested list
- Modal sheets for add/edit use `DatePicker(.dateAndTime)`
- Confirmation alerts via SwiftUI `.alert`
- Multi-select via `EditMode` on the `List`

## Out of scope for v1

- **CSV import / export.** Maybe v1.x, not now.
- **Undo with snackbar.** Nice but adds complexity. Confirmation alerts cover the main risk for v1.
- **Edit audit log.** "Show me what I edited last week" — not needed.
- **Per-hit notes / tags** (stress / social / boredom). Separate scope, see [[Plan]] open questions.

## Sequencing

**v1.** A tracker without edit/delete feels incomplete. Pairs naturally with the Logging phase as the read/write/delete counterpart of "log a hit." If absolutely time-pressed, *delete* alone could ship in v1 and *add forgotten* could slip to v1.1, but the additional UI for add is small and worth doing together.
