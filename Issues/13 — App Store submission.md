---
status: todo
priority: high
tags: [launch]
---

# App Store submission

Everything required to ship. Don't start until v1 features are locked.

## Metadata

- [ ] **App name**: Drift
- [ ] **Subtitle** (30 chars): "Notice the gaps."  *or* "A gentler tracker."
- [ ] **Promotional text** (170 chars): one warm sentence about what it is + privacy
- [ ] **Description**: 3–4 paragraphs. Lead with the spirit + "free for X" framing. End with privacy stance.
- [ ] **Keywords**: harm reduction, mindfulness, tracking, habits, hits, gaps, calm. Avoid "vape" if possible.
- [ ] **Category**: Lifestyle (primary), Health & Fitness (secondary)
- [ ] **Age rating**: probably 17+ given the substance-tracking nature; verify with the rating questionnaire
- [ ] **Support URL**: GitHub Issues on the public repo
- [ ] **Marketing URL**: GitHub Pages landing page
- [ ] **Privacy policy URL**: Same domain as marketing

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
