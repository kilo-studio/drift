---
status: done
priority: high
tags: [launch]
---

# App Store submission

Everything required to ship. Don't start until v1 features are locked.

> **Live on the App Store** — v1.0 build 1, iPhone-only. Submitted 2026-05-24,
> approved + released 2026-05-28. App Store name "Drift - Calmly cut back",
> subtitle "Wean off vaping", Lifestyle (primary) + Health & Fitness
> (secondary), Free, Data Not Collected, age rating 17+, copyright "2026 Kilo".
> The final promotional text + description as actually submitted are under
> "Final copy" below (reworded from the earlier drafts at submission time).

## Metadata

- [x] **App Store name**: **"Drift - Calmly cut back"** (23) — plain "Drift" was already taken on the App Store. Home-screen name (`CFBundleDisplayName`) stays just **"Drift"**, independent of the store name.
- [x] **Subtitle** (30 chars): **"Wean off vaping"** (15) — matches the onboarding subtitle. Note: puts "vaping" on a visible store surface, which slightly raises review risk (see "App Store review risk" below); swapping it later needs no binary resubmit.
- [x] **Promotional text** (170 chars): below
- [x] **Description**: below
- [x] **Keywords** (100 chars): vape/nicotine terms included for discoverability (keywords aren't shown publicly, so lower review-risk than the name/screenshots)
- [x] **Category**: Lifestyle (primary), Health & Fitness (secondary)
- [ ] **Age rating**: probably 17+ given the substance-tracking nature; verify with the rating questionnaire
- [x] **Support URL**: `https://github.com/kilo-studio/drift/issues`
- [x] **Marketing URL**: `https://github.com/kilo-studio/drift` (no Pages site — Issue 02)
- [x] **Privacy policy URL**: `https://github.com/kilo-studio/drift/blob/main/Privacy.md`

### Final copy (locked 2026-05-24)

**App Store name:** Drift - Calmly cut back

**Subtitle:** Wean off vaping

**Promotional text:** (as submitted 2026-05-24)
> A calm companion for noticing the time between hits and gently stretching it. No ads, no tracking, no accounts, no in-app purchases.

**Description:** (as submitted 2026-05-24)
> At its heart is your spirit. Drift past your average time between hits to make your spirit happy. The longer between hits, the happier your spirit. After you're notified you've gone longer than average between hits, wait as long as you can before your next one. You'll be drifting!
>
> There's no shame when you slip, Drift just shows you, honestly and in the present tense, what's actually happening. See how long it's been, how your days compare, and when your cravings tend to hit. Progress is up to you. Drift just helps you track and celebrate it.
>
> Everything stays private. Your data lives on your device and syncs only through your own iCloud, so we never see it. No ads, no tracking, no accounts, no in-app purchases.

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
