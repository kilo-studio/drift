# Design philosophy

## What Drift is

A small, gentle iOS app for noticing the gaps between hits. It rewards time spent *not* reaching for the thing, without ever shaming you for the times you do. The visual language is Ghibli — soft skies, drifting clouds, a small floating cloud spirit who gets visibly happier the longer you've drifted.

## What Drift is not

- Not a quit-app. No streaks, no shame, no daily targets, no progress meter that resets when you fail.
- Not a tracker that asks you to journal triggers or feelings.
- Not a quantified-self dashboard. The numbers are there but the spirit is the headline.
- Not social. No accounts, no sharing, no leaderboards.

## Principles

### Privacy as a feature

All data lives on-device by default. Optional iCloud sync via CloudKit (your iCloud, no servers we run). No analytics that include hit data. No third-party SDKs. Privacy nutrition labels say "Data Not Collected" honestly.

### One number, one feeling

The hero is "free for X." Everything else — the spirit's expression, sparkle density, color of the timer — is a derivative of that one quantity. The user shouldn't have to interpret a dashboard to feel how they're doing.

### Continuous, not gamified

There are no levels, badges, or unlocks. The spirit's eyes scale continuously with `ratio = ms / avgMs`. The sparkles reveal continuously. There are two milestones (longest waking, longest overall) and they're styled as warmth, not as tokens.

### Honest celebrations

When the spirit celebrates, the celebration should be earned. The notification overnight hedge is the canonical example: if we can't tell whether the user was actually awake when they "beat" the record, we soften the wording. False praise is worse than no praise.

### Soft, not flat

The aesthetic is hand-painted Ghibli, not iOS-default flat. Warm cream backgrounds with sky-blue gradients. Handwritten Caveat for labels. Drifting cloud SVGs. Soft shadows. The numbers are big and confident but the surrounding chrome is gentle.

## Why a spirit

The headline number is meaningful but abstract. A character makes the meaning emotional. When the spirit's eyes are small and tired, you've just hit. When they're huge and the sky is full of sparkles, you've gone way past your typical interval. You feel it before you read the number.

The spirit was originally trying to do too much (friends, rainbows, confetti, hats — see [[Issues]] for the iteration history). Stripping it back to *just* eye scaling + sparkles + milestone glow made it feel honest. The spirit doesn't need to perform; it just needs to react.

## Source of the aesthetic

Direct lineage: Studio Ghibli's atmospheric backgrounds (My Neighbor Totoro, Spirited Away). Indirect: small iOS apps in the "calm tech" tradition (Dot, Streaks) that respect the user's attention.
