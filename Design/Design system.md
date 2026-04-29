# Design system

## Color palette

### Surfaces

| Token | Hex | Use |
|---|---|---|
| `--cream` | `#FAF3E7` | Card surface (75% opacity over sky) |
| `--cream-warm` | `#F5EAD8` | Body gradient bottom |

### Sky

| Token | Hex | Use |
|---|---|---|
| Sky top | `#7FA7BD` | Body gradient 0% |
| Sky upper-mid | `#A8C6D5` | Body gradient 30% |
| Sky lower-mid | `#C8DDE4` | Body gradient 65% |
| Sky horizon | `#DCE5DA` | Body gradient 100% |
| Sun haze | `rgba(255, 220, 150, 0.45)` | Vertical overlay, fades to transparent by 25% down |

### Data

| Token | Hex | Used for |
|---|---|---|
| `--coral` | `#E8836B` | **Today / current** — today's count, today's bar in fortnight chart, today's stretches line |
| `--peach` | `#F4B393` | **Past data points** — non-today bars in fortnight chart |
| `--peach-deep` | `#E18B66` | Deeper accent (cheeks at overall milestone) |
| `--sage` | `#A8BC93` | **Aggregates light** — chart fills, hour-bar gradients |
| `--sage-deep` | `#7E9476` | **Aggregates strong** — average per day, waking gap stat numbers, rolling-avg line |

### Text

| Token | Hex | Use |
|---|---|---|
| `--ink` | `#4A453F` | Primary text, big numbers |
| `--ink-soft` | `#6B635A` | Secondary text, stat labels |
| `--ink-fade` | `#9A9082` | Tertiary text, axis labels, signature |

### Milestone glows (text-shadow halos, not text colors)

| State | Glow |
|---|---|
| Longest waking | `0 0 18px rgba(244, 179, 147, 0.7)` (peach) |
| Longest overall | `0 0 24px rgba(232, 184, 107, 0.85)` (gold), animated breathing |

## Color logic

The system to internalize:

> **Coral = today / current. Peach = past data. Sage = anything averaged.**

Examples:
- "Today" stat → coral (a current count)
- "Average per day" stat → sage (an aggregate)
- "Waking gap" stat → sage (an aggregate)
- Today's bar in fortnight chart → coral (highlights the current day)
- Other bars in fortnight chart → peach (raw past data)
- Rolling-avg line in "stretching the gaps" → sage (averaged data)
- Hour distribution bars → sage (aggregated across days)

The one wrinkle: hour distribution bars are technically per-hour data points, not averages, but they're aggregated across many days so they feel like a distribution. Sage fits.

## Type system

| Family | Weight | Use |
|---|---|---|
| **Quicksand** | 600 | All big numbers — timer (80px), stat-num (52px), best-num (22px) |
| **Quicksand** | 400–500 | Body text, stat labels, chart subtitles |
| **Caveat** | 500–600 | Card titles ("today", "average", "the last fortnight"), hero label ("free for"), best-record labels ("longest waking") |
| **Fraunces** | — | Reserved; was originally the display face but read poorly at scale. Kept loaded but only used in small functional spots like the debug panel readout. |

Sizes:
- Hero timer: 80px / weight 600 / `letter-spacing: -1.5px`
- Stat number: 52px / weight 600 / `letter-spacing: -1px`
- Best-record number: 22px / weight 600 / `letter-spacing: -0.2px`
- Card title (Caveat): 24px
- Card subtitle: 12px / weight 500 / `var(--ink-fade)` / centered, sits directly under title
- Stat label: 13px / weight 500 / `var(--ink-soft)`

## Layout

### Cards

```
border-radius: 28px
padding: 22px 20px 24px
background: rgba(255, 251, 244, 0.75)
backdrop-filter: blur(8px)
border: 1px solid rgba(255, 255, 255, 0.6)
box-shadow: 0 12px 32px -16px rgba(75, 60, 45, 0.18),
            0 2px 8px -4px rgba(75, 60, 45, 0.08)
```

### Card title alignment

All card titles centered. Stat-card titles always had this; chart cards now match. Card subtitles also centered, sit directly below the title (margin-bottom on title is 4px in chart cards, 12px in stat cards).

### Bar charts

Both bar charts: **rounded top, flat bottom**. 8px radius for the daily fortnight chart (Chart.js, `borderRadius: 8` with default `borderSkipped: 'start'`). 4px radius for the hour-distribution bars (CSS, `border-radius: 4px 4px 0 0`).

### Vocabulary

Every user-facing label uses **"hits"** (singular: "hit"), never "puffs". Verb forms like "when the cravings hit" use "hit" in its other sense and are fine.

## Spacing rhythm

The hero has a lot of vertical breathing room:
- Spirit pad-top: 36px (so the character isn't crammed against the safe area)
- Spirit min-height: 138px
- Hero pad: 12px top, 32px bottom
- Bests row: 26px top margin, 36px column gap

Cards get 16px vertical margin between them.
