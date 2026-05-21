---
status: removed
priority: none
tags: [postmortem]
---

# Achievement system — removed

**Final status:** Built and removed. The full system shipped briefly — `AchievementState` + `MilestoneUnlock` SwiftData models, an `AchievementID` catalog, an evaluation engine that ran after every append/edit/delete + on launch, and an Achievements tab between History and Settings — and then was pulled back out.

## Why we removed it

1. **The spirit already does the visualization.** A ratchet record (e.g. "longest waking gap = 4h 12m") and a spirit gold-halo milestone are the same fact surfaced twice. The spirit wins on immediacy — it shows the present-moment ratio continuously, no need to look at a separate screen for a number.
2. **"Earn this badge" tonally fought the "no streak, no nag" philosophy** the app is built around. Visualization is neutral; achievements judge. Even silently-unlocked, value-only-grows achievements still carry that framing because the user knows the system is grading them.
3. **Parallel tracking added complexity that didn't change what the user felt.** Every metric needed a duplicate persistence path inside a model that touched every store mutation. The spirit + records already did the emotional work; the achievement layer was code without payoff.

## Could it come back?

Maybe, but not without first solving the philosophical tension. The version we removed treated achievements as a separate surface ("go look at your badges"); a future return would probably need to be additive *to* the spirit (an extra ring around the cloud when a record is broken, a one-time gentle bloom of sparkles at first-time ratio milestones) rather than a discrete achievements screen. Don't reintroduce the old shape.

If the design tension *is* solved, the highest-leverage single addition was always **lowest rolling-30d sessions/day ever** — an honest, one-number ratchet that pairs naturally with the existing waking-gap card.
