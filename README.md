# Drift

A small, gentle iOS app for noticing the gaps between hits.

> Free for **2h 33m**. The cloud spirit's eyes get bigger and the sky fills with sparkles the longer you've drifted. No shame, no streaks, no nag — just a gentle visual reward for the time you didn't reach for it.

Drift is an iOS app for tracking vaping (or any small repeated habit you'd like to notice more clearly). It started as a personal Scriptable prototype and is being rebuilt as a native SwiftUI app for iOS 26.

## What it is

A Ghibli-inspired tracker that visualizes the **time between hits** as a cloud spirit. Log a hit and the spirit drops to baseline-sad. The longer the gap, the bigger the spirit's eyes get and the more sparkles fill the sky around it. There are no streaks to break, no fire emojis counting up, no shame for logging. It's a present-tense, neutral view of right now — the kind of mirror you'd want from a kindly friend, not a fitness app.

The design tries hard to celebrate without judging. False praise is worse than no praise, so the notifications soften their tone overnight (we can't tell whether you were awake when the trigger fired). The spirit's growth is continuous, not stepwise — no plateaus, no levels, no "earn this badge." Just real-time visualization of one ratio: current gap ÷ rolling average gap.

## Features

- **One-tap logging.** Bind the Action Button to "Log a hit in Drift" — silent, works on the Lock Screen, lands the hit and updates the widget in under a second. Also works from Shortcuts, Siri, Spotlight, and the trailing **+** tab.
- **Dashboard.** Today's sessions, average gap, longest stretches, when cravings tend to hit, a 30-day rolling average of how the gaps are stretching.
- **History.** Month calendar with donut day cells. Tap a day to see per-day stats and individual hits. Edit or delete any hit.
- **Notifications.** Local-only, three kinds (immediate confirmation, beating-your-average, beating-your-record), each with its own toggle and timing offset. The overnight hedge softens wording when we can't tell if you're awake.
- **Cloud sky.** Drifting clouds in light mode, twinkling stars + a dark cloud in dark mode. The ambient layer runs underneath the dashboard so the surface always feels alive.
- **Export your data.** Settings → Data → "export hits" writes every logged hit to a JSON file. Save it anywhere — Files, iCloud Drive, email — and own your data outright.
- **Sessions or individual hits.** Toggleable. Sessions collapse rapid hits within a configurable threshold; off treats every tap as its own event.

## Privacy

Drift declares **"Data Not Collected"** on the App Store, and that's accurate.

- All hit data lives on your device via SwiftData.
- No analytics SDKs, no third-party crash reporting, no servers we operate.
- Notifications are scheduled locally and delivered by Apple's notification system.
- Optional iCloud sync (planned, not yet shipped) will route through your own iCloud account via CloudKit — never anywhere we can see.

Full policy: [Privacy.md](Privacy.md).

## Status

Native iOS rebuild is feature-complete for v1's core; the Scriptable prototype is still in daily personal use as the system continues to bake. What's left before App Store submission:

- Empty-state polish for the home dashboard
- First-launch onboarding carousel that walks through key settings and explains the spirit
- iCloud sync toggle
- Polish punch list: sparkle-field render performance at high ratio, the add-hit sheet's visual treatment, the icon's Tinted appearance variant
- App Store metadata, screenshots, TestFlight, submission

See [Issues/](Issues/) for individual work items.

## Built with

- **SwiftUI + SwiftData** on iOS 26
- **App Intents** for the Action Button / Lock Screen / Shortcuts logging surface
- **WidgetKit** for the Home Screen widget
- **Charts** for the dashboard's stretching/rolling-average plots
- **Canvas + TimelineView** for the spirit, sparkle field, and ambient cloud/star layer

iOS 26 is the deployment floor. Lower targets aren't planned.

## Building from source

```bash
git clone https://github.com/kilo-studio/drift.git
cd drift
open app/Drift/Drift.xcodeproj
```

Then in Xcode:

- Scheme: **Drift**
- Destination: an iOS 26 simulator (e.g. iPhone 17 Pro) or a real device on iOS 26+
- ⌘R

The widget extension is set up but only renders a display-only timeline for now; silent tap-to-log from the widget is deferred. Signing uses your personal team for development. App Group `group.studio.kilo.drift` is required for the widget bridge — Xcode handles this automatically with automatic signing in most cases.

The prototype-data import bundle (`Resources/vape-log-bundle.json`) is gitignored; the app no-ops `PrototypeMigration` if it isn't present, so first-launch on a clean clone just gives you an empty store.

## Project structure

```
Drift/
├── README.md                 ← you are here
├── Privacy.md                ← privacy policy
├── LICENSE                   ← MIT
├── Design/                   ← philosophy, the spirit, design system
├── Engineering/              ← architecture, data model, notifications, migration
├── Issues/                   ← per-feature work items with status frontmatter
├── prototype/                ← Scriptable prototype source + docs
├── docs/                     ← GitHub Pages landing + privacy page
└── app/Drift/                ← Xcode project
    └── Drift/
        ├── App/              ← SwiftUI views, LogHitIntent, NotificationScheduler
        ├── Data/             ← Hit, Records, HitStore, metrics, migration plan
        ├── DesignSystem/     ← colors, fonts, gradients, the driftCard primitive
        ├── Fonts/            ← bundled Quicksand + Caveat variable fonts
        ├── Drift.icon        ← Icon Composer bundle
        └── Spirit/           ← SpiritView, SparkleField, AmbientLayer
```

## Design philosophy

If you're curious about the why behind the visual language, three docs are worth reading in order:

- [Design/Philosophy.md](Design/Philosophy.md) — what Drift is and isn't, the streaks vs achievements vs visualization distinction
- [Design/Spirit.md](Design/Spirit.md) — the cloud character: continuous ratio model, eye scaling, sparkle field, milestones
- [Design/Design system.md](Design/Design%20system.md) — colors, type, color logic

## Contributing

This is a solo project right now and primarily a personal portfolio piece, but bug reports and small fixes are welcome. Big feature ideas are best discussed in an issue first since the app's quiet/no-nag stance means some kinds of features are explicitly out of scope (streak counters, social comparison, gamification).

When opening issues or PRs, please:

- Use the existing issue file naming convention (`NN — Title.md` with frontmatter) for proposals that match the project's planning style, or open a regular GitHub issue for bugs/questions.
- Match the existing code conventions — `"hits"` (never `"puffs"`) for the unit, Drift's color tokens for any UI, no third-party dependencies without discussion.

## License

[MIT](LICENSE) © Griffin Mullins.

## Acknowledgments

- The cloud spirit's character draws from Studio Ghibli — soft, present, watchful, never judgmental.
- The "no streak, no nag" stance was shaped by a lot of frustration with habit-tracker apps that turn every relapse into a graphic failure.
- Built with [Claude Code](https://claude.com/claude-code) as a pair-programming collaborator on the SwiftUI rebuild.

## Contact

Email: [griffin@kilo.studio](mailto:griffin@kilo.studio)
