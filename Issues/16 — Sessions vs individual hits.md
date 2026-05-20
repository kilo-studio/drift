---
status: done
priority: medium
tags: [foundation, data, design]
---

> **Implementation status:** session derivation, threshold gating in `HitStore.append`,
> and session-aware metric semantics landed alongside the Issue 05 data layer.
> Spirit's ratio uses session-end as drift anchor (Issue 10). Threshold picker and
> the "Use sessions" master toggle are wired in settings (see [[Issues/12 — Onboarding, settings, app icon|Issue 12]]) — the toggle works via `HitStore.useSessions` + `effectiveSessionThreshold`, which routes every metric through `threshold: 0` when off so `sessions(threshold: 0)` yields one-hit sessions. Records recompute on toggle flip; HomeView and HistoryView labels branch on `store.useSessions` (sessions/hits, between sessions/between hits, etc.).

# Sessions vs individual hits

How does Drift model "I just took 5 hits in a row" vs "I took one hit just now"? Real design decision that affects the data model, every metric, and how the spirit feels.

## The problem

A vape user often takes multiple hits in close succession — a *session*, e.g. 5 hits over 2 minutes. The prototype currently logs each tap as one timestamp. That has three problems:

**1. Polluted gap math.** Intra-session gaps of ~10 seconds drag down the rolling waking-gap average. The spirit's average might end up at 45s because half the data is intra-session noise. "Past your average" then triggers after a single minute. The metric stops being meaningful.

**2. Misleading spirit.** The spirit reacts to `ms / avgMs`. If you just took a session of 5 puffs, the spirit shows "5 seconds since last hit" — but you actually just spent 2 minutes hitting. The visual mismatches the experience.

**3. Tedious logging fidelity.** Tapping 5 times for one session is friction. Users will sometimes tap once and "round," polluting the data the other direction.

## Approaches considered

| # | Approach | Pros | Cons |
|---|---|---|---|
| 1 | Don't model sessions; accept noise | Simplest | Drags avg down; spirit triggers too easily |
| 2 | Explicit sessions (long-press to start, end button) | User control | Adds friction; breaks "tap once, done" |
| 3 | Single tap = single event regardless of puff count | Simple data | Loses fidelity; user has to remember |
| 4 | **Implicit session detection** (recommended) | No UX change, clean math | Threshold tuning, slight complexity |

## Recommendation: implicit session detection

Every tap still stores a single hit timestamp — **no UX change**. When computing metrics, group consecutive hits with no inter-hit gap longer than a *session threshold* into derived "sessions." All meaningful metrics operate on sessions, not raw hits.

The user's mental model stays simple: "I tap when I hit." Sessions emerge from the data automatically.

### Session definition

A **session** is a maximal cluster of consecutive hits where no inter-hit gap exceeds the **session threshold**. Configurable, **default 5 minutes**. A solo hit is a session of length 1. A session has a start time (first hit) and an end time (last hit).

### What changes

| Metric | Before | After |
|---|---|---|
| `wakingAvgSec` | Avg gap between hits | Avg gap between **sessions** |
| `longestWakingGap` | Longest intra-day gap between hits | Longest intra-day gap between **sessions** |
| `longestGap` | Longest gap, sleep included | Longest gap between sessions, sleep included |
| Spirit's `ratio` | `(now - lastHit) / wakingAvgMs` | `(now - lastSessionEnd) / wakingAvgMs` |
| Today's count card | "X hits today" | "X sessions today" (small "Y hits" subtitle) |
| Daily fortnight chart | Hits per day | Sessions per day |
| Hour distribution | Hits by hour | Sessions by hour (start time of session) |
| Today's stretches chart | Gaps between hits | Gaps between sessions |

### What stays the same

- **Logging UX** — single tap = single hit, always
- **Raw data** — every hit still stored as `{t, tz}`. Sessions are derived on read, not persisted
- **App Intent / Widget / Lock Screen** — all log a single hit per tap, no awareness of sessions

### Two axes of progress

Once sessions exist as a derived concept, the data has two real axes of progress:

- **Frequency** — how often you have a session. Captured by inter-session gaps, sessions-per-day, longest waking gap. **This is what the spirit visualizes.**
- **Intensity** — how much you hit per session (avg hits-per-session, biggest session of the day). **This is invisible to the spirit on purpose — it's a looking-back metric that lives in achievements.**

A user who chains 5 hits per session 5×/day looks identical (5 sessions/day) to a user who solo-hits 5×/day at the frequency layer. The intensity axis is what distinguishes them, and improving on either axis is real progress. See [[Issues/15 — Achievement system]] for the personal records and milestone unlocks that capture the intensity axis.

Why the spirit only reflects frequency: the spirit is a *present-moment visualization* (per [[Philosophy]]), and the only meaningful present-moment quantity is "time since last session ended." Intensity is a looking-back property — you can only know your average hits-per-session by aggregating over time, which is achievement territory. Trying to encode both axes in one creature dilutes the "one number, one feeling" principle.

### Settings

- **Use sessions** — master toggle. Default **on**. See [[#The "Use sessions" toggle]] below.
- **Session threshold** — picker: 1 / 3 / 5 / 10 / 15 / 30 minutes. Default 5. Only visible when "Use sessions" is on.
- *(Maybe)* **Show hits alongside sessions** — toggle to show secondary "Y hits" label on the today card. Default on.

### The "Use sessions" toggle

The implicit-session model above is a recommendation, not a forced philosophy. Some users may genuinely want every tap to count as its own event — they're solo-hitters, or they prefer the spirit to react to every input, or they think "session" is a manufactured concept that hides their real behavior. The toggle is the escape hatch.

**When OFF**, every session-aware metric falls back to its hit-based equivalent:

| Metric | Sessions ON | Sessions OFF |
|---|---|---|
| Spirit drift anchor | `now - lastSessionEnd` | `now - lastHit.t` |
| `wakingAvgSec` | Avg gap between sessions in a waking day | Avg gap between hits in a waking day |
| `longestWakingGap` | Longest intra-day gap between sessions | Longest intra-day gap between hits |
| `longestGap` | Longest gap between sessions | Longest gap between hits |
| Today card | "X sessions · Y hits" | "X hits" (no secondary label) |
| Daily fortnight chart | Sessions per day | Hits per day |
| Hours chart | Sessions by hour (start time) | Hits by hour |
| Today's stretches chart | Gaps between sessions | Gaps between hits |
| Rolling avg chart | Avg gap between sessions, rolling window | Avg gap between hits, rolling window |

**Resolved implementation details:**

1. **Records recompute on toggle change.** The persisted `longestGap` / `longestWakingGap` are recomputed from history under the new mode whenever the toggle flips, mirroring how `HitStore.recomputeRecords()` already runs after edit/delete (per [[Issues/17 — Hit history]]). Records always describe what's true *now* in the data.
2. **Persistence.** `drift.useSessions: Bool` in `UserDefaults`, default `true` so existing installs keep current behavior on upgrade.
3. **Threshold visibility.** When sessions are off, the session-threshold row is **hidden entirely** (not disabled). The value is meaningless in hit-mode, so taking up screen space would be misleading.
4. **Notification copy.** Bodies already say "since last hit" — works in both modes. "avg Ym" just reflects the new average. No copy changes needed.

## Open questions

**Spirit driver: "since last hit" or "since end of last session"?**
Recommend **end of last session**. The user's experience is "I finished hitting, now I'm drifting." Showing "5s since last hit" mid-session is confusing; showing "0s since end of session" *while still in the session* is honest — the spirit stays sleepy until the session actually ends, then starts drifting up. That matches reality.

**Today's count: sessions or hits?**
Recommend **sessions, with hits as a small secondary label**. Sessions is the more meaningful unit. "127 hits today" risks reading as overwhelming/shameful for heavy users. "23 sessions · 127 hits" is honest about both layers.

**Default threshold?**
5 minutes is a guess. For someone who takes one puff per session, 5 min is plenty. For someone who chain-puffs across long stretches, 5 min might be too short (one "session" actually splits into 3). Settings handles individual variation. We could revisit the default after usage data.

## Edge cases

- **Long-running session.** A 90-min session of slow-paced puffs (puff every 4 min) is still one session. `longestWakingGap` correctly ignores this — it's the gap *between* sessions, not within.
- **Overnight session crossing 4am cutoff.** A session whose first hit is at 3:45am and last is at 4:15am should belong to the waking-day bucket of the *first* hit. Subsequent hits inherit the bucket regardless of which side of 4am they land on.
- **First hit after a long break.** Last session ended 11pm yesterday, first hit today at 2pm. That's a fresh session start, and the inter-session gap is 15 hours. Counts toward `longestGap` (sleep-inclusive) but not `longestWakingGap` (different waking-day buckets).

## Implementation sketch (Swift)

```swift
struct Session {
    let hits: [Hit]
    var start: Date { hits.first!.t }
    var end:   Date { hits.last!.t }
    var count: Int  { hits.count }
}

extension HitStore {
    func sessions(threshold: TimeInterval = 5 * 60) -> [Session] {
        var result: [Session] = []
        var current: [Hit] = []
        for hit in hits.sorted(by: { $0.t < $1.t }) {
            if let last = current.last,
               hit.t.timeIntervalSince(last.t) > threshold {
                result.append(Session(hits: current))
                current = []
            }
            current.append(hit)
        }
        if !current.isEmpty { result.append(Session(hits: current)) }
        return result
    }
}
```

Cache aggressively. Recompute only when `hits` array changes or threshold setting changes.

## Cross-references

When this lands, update:
- [[Engineering/Data model]] — describe `Session` derivation, update metric formulas
- [[Issues/05 — Data model and metrics]] — add session helpers to the task list
- [[Issues/09 — Stat cards and charts]] — update labels and chart data sources
- [[Issues/10 — Spirit character]] — `ratio` formula uses session end, not last hit
- [[Spirit]] — note that "ratio" is session-based

## Sequencing

**v1, foundation phase.** This affects the data model and every metric. Worth landing before the dashboard is built so we don't have to retrofit. Pairs naturally with [[Issues/05 — Data model and metrics]].
