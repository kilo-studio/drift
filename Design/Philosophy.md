# Design philosophy

## What Drift is

A small, gentle iOS app for noticing the gaps between hits. It rewards time spent *not* reaching for the thing, without ever shaming you for the times you do. The visual language is Ghibli — soft skies, drifting clouds, a small floating cloud spirit who gets visibly happier the longer you've drifted.

## What Drift is not

- Not a quit-app. No shame, no daily targets, no failure-resetting streaks. A counter that drops to zero on a bad day is the thing being avoided.
- Not a tracker that asks you to journal triggers or feelings.
- Not a quantified-self dashboard. The numbers are there but the spirit is the headline.
- Not social. No accounts, no sharing, no leaderboards.

## Principles

### Privacy as a feature

All data lives on-device by default. Optional iCloud sync via CloudKit (your iCloud, no servers we run). No analytics that include hit data. No third-party SDKs. Privacy nutrition labels say "Data Not Collected" honestly.

### One number, one feeling

The hero is "free for X." Everything else — the spirit's expression, sparkle density, color of the timer — is a derivative of that one quantity. The user shouldn't have to interpret a dashboard to feel how they're doing.

### Streaks vs visualization — drawing the line

Two concepts that look similar from outside but are different in kind. Drift draws a sharp line:

- **Streaks** describe your behavior over time and *judge* it. A counter that drops to zero on a bad day implicitly frames that day as a failure. ❌ Out.
- **Visualization** describes a *present-moment quantity*, neutrally. The cloud spirit is `ratio = ms / avgMs` drawn as a creature with feelings. When the eyes shrink after a hit, nothing was "lost" — the variable being measured just changed value, the way a clock face changes when time passes. ✅ Always fine.

The cleanest test: **a streak describes *you*; the spirit describes *time*.** The spirit isn't a streak even though it visibly grows and shrinks. It's not narrating your behavior at all — it's a clock with feelings.

Why streaks specifically are the failure mode being avoided:

- They shame bad days, which can trigger the very behavior they're trying to discourage.
- They bias toward dishonest logging — users skip hits to preserve the streak, polluting the data.
- They frame data as morality. A hit becomes a "failure" instead of a thing that happened.

There was a third concept on this list at one point — **achievements** (personal records that ratchet, milestone unlocks, cumulative counters that only grow). The thinking was that since they only grow, they don't have the failure-mode of streaks. An achievement system was actually built and shipped briefly before being pulled. Why: the spirit already does the visualization in real time (a "longest waking gap" record and the spirit's gold-halo milestone are the same fact surfaced twice), and the "earn this badge" tone tugs the app away from the gentleness it's built around. The decision: visualization is enough. See [[Issues/15 — Achievement system]] for the postmortem.

### Honest celebrations

When the spirit celebrates, the celebration should be earned. The notification overnight hedge is the canonical example: if we can't tell whether the user was actually awake when they "beat" the record, we soften the wording. False praise is worse than no praise.

### Soft, not flat

The aesthetic is hand-painted Ghibli, not iOS-default flat. Warm cream backgrounds with sky-blue gradients. Handwritten Caveat for labels. Drifting cloud SVGs. Soft shadows. The numbers are big and confident but the surrounding chrome is gentle.

## Why a spirit

The headline number is meaningful but abstract. A character makes the meaning emotional. When the spirit's eyes are small and tired, you've just hit. When they're huge and the sky is full of sparkles, you've gone way past your typical interval. You feel it before you read the number.

The spirit was originally trying to do too much (friends, rainbows, confetti, hats — see [[Issues]] for the iteration history). Stripping it back to *just* eye scaling + sparkles + milestone glow made it feel honest. The spirit doesn't need to perform; it just needs to react.

## Source of the aesthetic

Direct lineage: Studio Ghibli's atmospheric backgrounds (My Neighbor Totoro, Spirited Away). Indirect: small iOS apps in the "calm tech" tradition (Dot, Streaks) that respect the user's attention.
