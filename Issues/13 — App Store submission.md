---
status: todo
priority: high
tags: [launch]
---

# App Store submission

Everything required to ship. Don't start until v1 features are locked.

## Metadata

- [x] **App name**: Drift
- [x] **Subtitle** (30 chars): **"Calmly cut back"** (15)
- [x] **Promotional text** (170 chars): below
- [x] **Description**: below
- [x] **Keywords** (100 chars): vape/nicotine terms included for discoverability (keywords aren't shown publicly, so lower review-risk than the name/screenshots)
- [x] **Category**: Lifestyle (primary), Health & Fitness (secondary)
- [ ] **Age rating**: probably 17+ given the substance-tracking nature; verify with the rating questionnaire
- [x] **Support URL**: `https://github.com/kilo-studio/drift/issues`
- [x] **Marketing URL**: `https://github.com/kilo-studio/drift` (no Pages site — Issue 02)
- [x] **Privacy policy URL**: `https://github.com/kilo-studio/drift/blob/main/Privacy.md`

### Final copy (locked 2026-05-24)

**Subtitle:** Calmly cut back

**Promotional text:**
> A calm, Ghibli-inspired companion for noticing the time between hits and gently stretching it. No streaks, no shame, and nothing ever leaves your device.

**Description:**
> Drift is a small, gentle companion for noticing the time between hits — and slowly stretching it.
>
> At its heart is a little cloud spirit. The longer it's been since your last hit, the brighter and happier it grows, and the more the sky fills with sparkles. A running "free for" timer counts the time since your last hit, and when you go a long while — a day, a week, a month — Drift quietly reframes around that, celebrating how far you've drifted.
>
> There are no streaks to break and no shame when you slip. Drift never says "quit." It just shows you, honestly and in the present tense, what's actually happening: how long it's been, how your days compare, when your cravings tend to hit. Progress here is something you notice, not something you're scored on.
>
> Everything stays private. Your data lives on your device and syncs only through your own iCloud — we never see it. No ads, no tracking, no accounts. Drift is completely free.

**Keywords:**
`vape,vaping,nicotine,quit,craving,habit,tracker,smoking,cigarette,puff,wean,reduce,mindful,calm`

## Privacy nutrition labels

- [ ] All categories: **Data Not Collected**

## Screenshots

For 6.7" + 6.5" + 5.5" iPhone (and iPad if shipping iPad-first):

1. Hero with timer + spirit at low ratio (calm)
2. Hero with spirit at high ratio (sparkles, glowing eyes)
3. Hero at longest-overall milestone (full gold treatment)
4. Stat cards
5. Charts
6. Logging via Lock Screen

Screenshots can use real personal data with hits redacted, or seeded fixture data for cleaner numbers.

## Build + ship

- [ ] Switch to Kilo studio team for signing
- [ ] Increment build number, archive, validate
- [ ] Upload to App Store Connect
- [ ] TestFlight: invite a small group of testers (10-ish friends). Run for at least a week.
- [ ] Address feedback
- [ ] Submit for review with the v1 build

## App Store review risk

Apple has rejected some vape-tracking apps. Mitigations:
- Name avoids "vape" entirely (Drift is abstract)
- Description leads with mindfulness / harm-reduction framing, not consumption tracking
- No facilitation of purchase, no e-cig hardware integration
- Screenshots show calming aesthetic, not branded content

If rejected: appeal with the harm-reduction framing, link to the open-source code, emphasize privacy.

## Pricing

Free. No IAP. No ads.
