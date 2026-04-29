// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-gray; icon-glyph: magic;
// Vape Stats — Ghibli-inspired dashboard
// File: iCloud Drive/Scriptable/vape-stats.js
// Reads from vape-log.json (same folder)

// Each hit is { t: ISO UTC string, tz: minutes east of UTC at log time }.
// localOf returns a Date whose UTC getters yield the wall-clock time the
// user saw when they logged the hit, regardless of the device's current zone.
function localOf(hit) {
  return new Date(new Date(hit.t).getTime() + hit.tz * 60000)
}
function logLocalDateKey(hit) {
  return localOf(hit).toISOString().slice(0, 10)
}
function deviceLocalDateKey(date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}
function nowHit() {
  const n = new Date()
  return { t: n.toISOString(), tz: -n.getTimezoneOffset() }
}
function migrateHits(rawHits) {
  const currentTz = -new Date().getTimezoneOffset()
  let migrated = false
  const out = rawHits.map(h => {
    if (typeof h === 'string') { migrated = true; return { t: h, tz: currentTz } }
    return h
  })
  return { hits: out, migrated }
}

// Waking-day grouping (4am cutoff) — keeps sleep gaps out of the avg
function wakingDayKey(hit) {
  const d = localOf(hit)
  if (d.getUTCHours() < 4) d.setUTCDate(d.getUTCDate() - 1)
  d.setUTCHours(0, 0, 0, 0)
  return d.toISOString().slice(0, 10)
}

function computeWakingAvgSec(hits) {
  const buckets = {}
  hits.forEach(h => {
    const key = wakingDayKey(h)
    if (!buckets[key]) buckets[key] = []
    buckets[key].push(h)
  })
  let totalSpanMs = 0
  let totalIntervals = 0
  Object.values(buckets).forEach(dayHits => {
    if (dayHits.length < 2) return
    dayHits.sort((a, b) => new Date(a.t) - new Date(b.t))
    totalSpanMs += new Date(dayHits[dayHits.length - 1].t) - new Date(dayHits[0].t)
    totalIntervals += dayHits.length - 1
  })
  if (totalIntervals === 0) return null
  return Math.floor(totalSpanMs / totalIntervals / 1000)
}

// Longest within-day gap — used to backfill data.longestWakingGap if absent.
function computeLongestWakingGapSec(hits) {
  const buckets = {}
  hits.forEach(h => {
    const key = wakingDayKey(h)
    if (!buckets[key]) buckets[key] = []
    buckets[key].push(h)
  })
  let longest = 0
  Object.values(buckets).forEach(dayHits => {
    if (dayHits.length < 2) return
    dayHits.sort((a, b) => new Date(a.t) - new Date(b.t))
    for (let i = 1; i < dayHits.length; i++) {
      const gap = (new Date(dayHits[i].t) - new Date(dayHits[i - 1].t)) / 1000
      if (gap > longest) longest = gap
    }
  })
  return longest
}

// Gaps (in minutes) between consecutive hits within today's waking day,
// labeled by the time-of-day of the later hit in each pair.
function computeTodayStretches(hits) {
  const todayKey = wakingDayKey(nowHit())
  const todayHits = hits
    .filter(h => wakingDayKey(h) === todayKey)
    .sort((a, b) => new Date(a.t) - new Date(b.t))
  const result = []
  for (let i = 1; i < todayHits.length; i++) {
    const gapMin = Math.round((new Date(todayHits[i].t) - new Date(todayHits[i - 1].t)) / 1000 / 60)
    const t = localOf(todayHits[i])
    const h = t.getUTCHours()
    const m = String(t.getUTCMinutes()).padStart(2, "0")
    let label
    if (h === 0) label = `12:${m}a`
    else if (h < 12) label = `${h}:${m}a`
    else if (h === 12) label = `12:${m}p`
    else label = `${h - 12}:${m}p`
    result.push({ label, gapMin })
  }
  return result
}

const fm = FileManager.iCloud()
const path = fm.joinPath(fm.documentsDirectory(), "vape-log.json")

if (!fm.fileExists(path)) {
  const a = new Alert()
  a.title = "No data yet"
  a.message = "Log a hit first to see your dashboard."
  a.addAction("OK")
  await a.presentAlert()
  Script.complete()
  return
}

if (!fm.isFileDownloaded(path)) {
  await fm.downloadFileFromiCloud(path)
}

const data = JSON.parse(fm.readString(path))
const migration = migrateHits(data.hits || [])
const hits = migration.hits.sort((a, b) => new Date(a.t) - new Date(b.t))
if (migration.migrated) {
  data.hits = hits
  fm.writeString(path, JSON.stringify(data, null, 2))
}
const longestGapSec = data.longestGap || 0
const longestWakingGapSec = data.longestWakingGap !== undefined
  ? data.longestWakingGap
  : computeLongestWakingGapSec(hits)

// ---------- Stat computations ----------

function computeDailyCounts(hits, days) {
  const now = new Date()
  const buckets = []
  for (let i = days - 1; i >= 0; i--) {
    const day = new Date(now)
    day.setHours(0, 0, 0, 0)
    day.setDate(day.getDate() - i)
    const key = deviceLocalDateKey(day)
    const count = hits.filter(h => logLocalDateKey(h) === key).length
    const labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    buckets.push({
      label: labels[day.getDay()],
      date: day.getDate(),
      count,
      isToday: i === 0
    })
  }
  return buckets
}

function computeHourlyCounts(hits) {
  const counts = new Array(24).fill(0)
  hits.forEach(h => { counts[localOf(h).getUTCHours()]++ })
  return counts
}

function computeRollingAvg(hits, windowDays = 7) {
  if (hits.length < 2) return []
  const result = []
  const now = new Date()
  const startDate = new Date(hits[0].t)
  startDate.setHours(0, 0, 0, 0)
  for (let day = new Date(startDate); day <= now; day.setDate(day.getDate() + 1)) {
    const windowEnd = new Date(day)
    windowEnd.setHours(23, 59, 59, 999)
    const windowStart = new Date(day)
    windowStart.setDate(windowStart.getDate() - windowDays)
    const windowHits = hits.filter(h => {
      const t = new Date(h.t).getTime()
      return t >= windowStart.getTime() && t <= windowEnd.getTime()
    })
    if (windowHits.length < 2) continue
    const intervals = []
    for (let i = 1; i < windowHits.length; i++) {
      intervals.push((new Date(windowHits[i].t) - new Date(windowHits[i-1].t)) / 1000 / 60)
    }
    const avg = intervals.reduce((a,b) => a+b, 0) / intervals.length
    const monthLabels = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    result.push({
      label: monthLabels[day.getMonth()] + " " + day.getDate(),
      avgMin: Math.round(avg)
    })
  }
  return result
}

const daily = computeDailyCounts(hits, 14)
const hourly = computeHourlyCounts(hits)
const rolling = computeRollingAvg(hits, 7)
const todayStretches = computeTodayStretches(hits)
const lastHitMs = hits.length ? new Date(hits[hits.length - 1].t).getTime() : Date.now()
const todayCount = daily[daily.length - 1].count

// Rolling 30-day window — keeps both averages reactive to recent behaviour
// rather than dragged toward all-time history.
//
// Two slightly different windows for the two averages:
//   - Per-day average excludes today (today is a partial day; counting it
//     would pull the mean down).
//   - Waking-gap average INCLUDES today. It averages intervals between hits,
//     not counts per day — a partial day's intervals are still real intervals
//     and shouldn't be hidden.
const ROLLING_WINDOW_DAYS = 30
const windowEnd = new Date(deviceLocalDateKey(new Date()) + 'T12:00:00Z')
const windowStart = new Date(windowEnd)
windowStart.setUTCDate(windowStart.getUTCDate() - ROLLING_WINDOW_DAYS)
const windowStartKey = windowStart.toISOString().slice(0, 10)
const windowEndKey = windowEnd.toISOString().slice(0, 10)
// Includes today — used for the waking-gap average + spirit threshold.
const hitsInWindowInclToday = hits.filter(h => logLocalDateKey(h) >= windowStartKey)

// Average hits per day — mean of per-day counts across the rolling window,
// excluding today (partial day).
const counts = {}
hits.forEach(h => {
  const key = logLocalDateKey(h)
  counts[key] = (counts[key] || 0) + 1
})
const dayValues = []
if (hits.length) {
  // Start at the later of (first-hit date) or (window start) so we don't pad
  // averages with zero days from before the user started logging.
  const firstHit = new Date(logLocalDateKey(hits[0]) + 'T12:00:00Z')
  const cur = new Date(Math.max(firstHit.getTime(), windowStart.getTime()))
  while (cur < windowEnd) { // strictly less-than → today excluded
    dayValues.push(counts[cur.toISOString().slice(0, 10)] || 0)
    cur.setUTCDate(cur.getUTCDate() + 1)
  }
}
const avgPerDay = dayValues.length ? dayValues.reduce((a, b) => a + b, 0) / dayValues.length : 0
const avgPerDayStr = avgPerDay >= 10 ? Math.round(avgPerDay).toString() : (Math.round(avgPerDay * 10) / 10).toString()

// Waking-hours average gap between hits (sleep excluded), rolling window
// including today — partial-day intervals are still real intervals.
const wakingAvgSec = computeWakingAvgSec(hitsInWindowInclToday)
const wakingAvgStr = wakingAvgSec === null ? "—" : formatGap(wakingAvgSec)

// ---------- Format helpers (used in template) ----------

function formatGap(sec) {
  if (sec < 60) return sec + "s"
  if (sec < 3600) return Math.floor(sec / 60) + "m"
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  return h + "h " + m + "m"
}

const longestGapStr = formatGap(longestGapSec)
const longestWakingGapStr = longestWakingGapSec > 0 ? formatGap(longestWakingGapSec) : "—"

// ---------- HTML ----------

const payload = JSON.stringify({
  lastHitMs,
  longestGapSec,
  longestGapStr,
  longestWakingGapSec,
  longestWakingGapStr,
  wakingAvgSec,
  todayCount,
  totalHits: hits.length,
  daily,
  hourly,
  rolling,
  todayStretches
})

const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,300;9..144,400;9..144,500;9..144,600&family=Quicksand:wght@400;500;600&family=Caveat:wght@500;600&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  :root {
    --sky-top: #FCE5D0;
    --sky-mid: #F4D5BC;
    --sky-bot: #C8DDE6;
    --cream: #FAF3E7;
    --cream-warm: #F5EAD8;
    --sage: #A8BC93;
    --sage-deep: #7E9476;
    --peach: #F4B393;
    --peach-deep: #E18B66;
    --coral: #E8836B;
    --yellow: #F0D88B;
    --ink: #4A453F;
    --ink-soft: #6B635A;
    --ink-fade: #9A9082;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }

  html, body {
    font-family: 'Quicksand', sans-serif;
    color: var(--ink);
    background: var(--cream);
    overflow-x: hidden;
  }

  body {
    background:
      linear-gradient(to bottom, rgba(255, 220, 150, 0.45) 0%, rgba(255, 220, 150, 0.18) 12%, transparent 25%),
      linear-gradient(to bottom, #7FA7BD 0%, #A8C6D5 30%, #C8DDE4 65%, #DCE5DA 100%);
    min-height: 100vh;
    padding: max(env(safe-area-inset-top), 24px) 20px max(env(safe-area-inset-bottom), 32px);
  }

  /* drifting cloud decoration */
  .cloud-layer {
    position: fixed;
    inset: 0;
    overflow: hidden;
    pointer-events: none;
    z-index: 0;
  }
  .cloud {
    position: absolute;
    pointer-events: none;
    opacity: 0.85;
  }
  .cloud-1 { top: 420px; left: -30px; animation: drift1 60s ease-in-out infinite; }
  .cloud-2 { top: 240px; right: -40px; animation: drift2 75s ease-in-out infinite; }

  @keyframes drift1 {
    0%, 100% { transform: translateX(0) translateY(0); }
    50% { transform: translateX(40px) translateY(-8px); }
  }
  @keyframes drift2 {
    0%, 100% { transform: translateX(0) translateY(0); }
    50% { transform: translateX(-50px) translateY(6px); }
  }

  /* spirit at top of page */
  .spirit-wrap {
    text-align: center;
    padding-top: 36px;
    position: relative;
    z-index: 2;
    min-height: 138px;
  }

  .spirit-stage {
    position: relative;
    display: inline-block;
    width: 96px;
    height: 96px;
  }

  .spirit {
    width: 96px;
    height: 96px;
    animation: float 5s ease-in-out infinite;
    position: relative;
    z-index: 3;
  }

  /* full-viewport sparkle field — JS positions each sparkle in viewport
     percentage coords, then toggles .visible based on the current ratio. */
  .sparkle-field {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 1;
    overflow: hidden;
  }
  .sparkle {
    position: absolute;
    pointer-events: none;
    opacity: 0;
    transition: opacity 1.4s ease;
    animation: drift var(--drift-dur, 8s) ease-in-out var(--drift-delay, 0s) infinite;
    will-change: opacity, transform;
  }
  .sparkle.visible {
    opacity: 1;
    animation:
      drift   var(--drift-dur, 8s)   ease-in-out var(--drift-delay, 0s)   infinite,
      twinkle var(--twinkle-dur, 3s) ease-in-out var(--twinkle-delay, 0s) infinite;
  }
  .sparkle svg { width: 100%; height: 100%; display: block; }

  @keyframes float {
    0%, 100% { transform: translateY(0) rotate(-2deg); }
    50%      { transform: translateY(-6px) rotate(2deg); }
  }
  /* drift composes with the static -50% / -50% centering of each absolutely-
     positioned sparkle, so we always include translate(-50%, -50%) and add the
     drift offset on top. */
  @keyframes drift {
    0%, 100% { transform: translate(-50%, -50%); }
    50%      { transform: translate(calc(-50% + var(--dx, 0px)), calc(-50% + var(--dy, 0px))); }
  }
  @keyframes twinkle {
    0%, 100% { opacity: 0.35; }
    50%      { opacity: 1; }
  }
  @keyframes blink {
    0%, 92%, 100% { transform: scaleY(1); }
    94%, 96%      { transform: scaleY(0.12); }
  }

  /* eye blink — gentle natural rhythm */
  .spirit .eye-left,
  .spirit .eye-right {
    transform-box: fill-box;
    transform-origin: center;
    animation: blink 6.5s ease-in-out infinite;
  }
  .spirit .eye-right { animation-delay: 0.04s; }

  /* Eye geometry is fully driven by JS-set CSS variables on the spirit-wrap.
     The bottom of the pupil is anchored at y=52.9, so as r grows cy shrinks —
     eyes scale upward toward the forehead, never down toward the smile. */
  .spirit .eye-pupil {
    r: var(--pupil-r, 2.4px);
    cy: var(--pupil-cy, 50.5px);
    transition: r 1.6s ease, cy 1.6s ease;
  }
  .spirit .eye-shine {
    r: var(--shine-r, 0.65px);
    cy: var(--shine-cy, 49.6px);
    transition: r 1.6s ease, cy 1.6s ease;
  }

  /* cheeks — opacity transitions so milestones can deepen the blush */
  .spirit .cheek { opacity: 0.45; transition: opacity 1.6s ease, fill 1.6s ease; }

  /* ---------- MILESTONES ---------- */
  /* Body-level classes set by JS when the current gap matches/exceeds the
     longest waking and longest overall records. They're additive: hitting
     longest-overall implies longest-waking, so the overall styles layer on top. */

  /* Spirit float baseline + transitions for color/glow shifts */
  .spirit { transition: filter 1.6s ease; }

  @keyframes float-waking {
    0%, 100% { transform: translateY(0) rotate(-3deg); }
    50%      { transform: translateY(-10px) rotate(3deg); }
  }
  @keyframes float-overall {
    0%, 100% { transform: translateY(0) rotate(-4deg); }
    25%      { transform: translateY(-7px) rotate(2deg)  scale(1.015); }
    50%      { transform: translateY(-12px) rotate(4deg); }
    75%      { transform: translateY(-5px) rotate(-1deg) scale(1.015); }
  }
  /* Animated text-shadow "breathing" glow — used on best-num at the longest-
     overall milestone. */
  @keyframes moon-glow {
    0%, 100% { text-shadow: 0 0 4px rgba(232, 184, 107, 0.4); }
    50%      { text-shadow: 0 0 14px rgba(232, 184, 107, 0.95); }
  }

  /* Milestone glows ease in via text-shadow on the numbers themselves. Text
     colors don't change — keeps everything high-contrast against the sky. */
  .timer    { transition: text-shadow 1.6s ease; }
  .best-num { transition: text-shadow 1.6s ease; }

  /* Longest waking — warm */
  body.milestone-waking .spirit {
    animation: float-waking 3.6s ease-in-out infinite;
  }
  body.milestone-waking .spirit .cheek { opacity: 0.7; }
  body.milestone-waking .timer {
    text-shadow: 0 0 18px rgba(244, 179, 147, 0.7);
  }
  body.milestone-waking .best-waking .best-num {
    text-shadow: 0 0 14px rgba(244, 179, 147, 0.75);
  }

  /* Longest overall — gold (additive on top of waking) */
  body.milestone-overall .spirit {
    animation: float-overall 3.0s ease-in-out infinite;
    filter: drop-shadow(0 0 12px rgba(232, 184, 107, 0.55));
  }
  body.milestone-overall .spirit .cheek { opacity: 0.85; fill: #E8836B; }
  body.milestone-overall .timer {
    text-shadow: 0 0 24px rgba(232, 184, 107, 0.85);
  }
  body.milestone-overall .best-overall .best-num {
    animation: moon-glow 3s ease-in-out infinite;
  }

  /* hero */
  .hero {
    position: relative;
    text-align: center;
    padding: 12px 0 32px;
    z-index: 2;
  }

  .hero-label {
    font-family: 'Caveat', cursive;
    font-size: 26px;
    color: var(--ink-soft);
    margin-bottom: 0;
    letter-spacing: 0.5px;
    line-height: 1.2;
  }

  .timer {
    font-family: 'Quicksand', sans-serif;
    font-weight: 600;
    font-size: 80px;
    line-height: 1;
    color: var(--ink);
    letter-spacing: -1.5px;
    margin: 8px 0 4px;
  }

  .timer .unit {
    font-size: 32px;
    font-weight: 300;
    color: var(--ink-soft);
    margin-left: 2px;
    margin-right: 8px;
    letter-spacing: 0;
  }

  /* personal-bests row — two records side by side, each stacks number + label.
     Lives in the hero (no card chrome) so it reads as context for the timer. */
  .bests {
    display: flex;
    justify-content: center;
    gap: 36px;
    margin-top: 26px;
  }
  .best {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .best-num {
    font-family: 'Quicksand', sans-serif;
    font-size: 22px;
    font-weight: 600;
    color: var(--ink);
    line-height: 1;
    display: flex;
    align-items: baseline;
    gap: 6px;
    letter-spacing: -0.2px;
  }
  .best-label {
    font-family: 'Caveat', cursive;
    font-size: 16px;
    color: var(--ink-soft);
    letter-spacing: 0.4px;
    line-height: 1.1;
  }

  /* card */
  .card {
    position: relative;
    background: rgba(255, 251, 244, 0.75);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.6);
    border-radius: 28px;
    padding: 22px 20px 24px;
    margin: 16px 0;
    box-shadow:
      0 1px 0 rgba(255,255,255,0.8) inset,
      0 12px 32px -16px rgba(75, 60, 45, 0.18),
      0 2px 8px -4px rgba(75, 60, 45, 0.08);
    z-index: 2;
  }

  .card-title {
    font-family: 'Caveat', cursive;
    font-size: 24px;
    color: var(--ink);
    margin-bottom: 4px;
    letter-spacing: 0.3px;
    text-align: center;
  }

  /* card subtitle — sits directly under the title, before any chart/content */
  .card-sub {
    font-size: 12px;
    color: var(--ink-fade);
    margin: 0 0 14px;
    font-weight: 500;
    text-align: center;
  }

  /* stat cards (today + average) */
  .stat-row {
    display: flex;
    gap: 12px;
    margin: 16px 0;
  }
  .stat-card {
    flex: 1;
    margin: 0;
    padding: 20px 12px 22px;
    text-align: center;
  }
  .stat-card .card-title {
    margin-bottom: 12px;
  }
  .stat-num {
    font-family: 'Quicksand', sans-serif;
    font-weight: 600;
    font-size: 52px;
    line-height: 1;
    margin-bottom: 8px;
    letter-spacing: -1px;
  }
  .stat-num.coral { color: var(--coral); }
  .stat-num.sage { color: var(--sage-deep); }
  .stat-label {
    font-size: 13px;
    color: var(--ink-soft);
    font-weight: 500;
  }

  /* hour distribution */
  .hours {
    display: grid;
    grid-template-columns: repeat(24, 1fr);
    gap: 3px;
    align-items: end;
    height: 80px;
    padding: 8px 0 4px;
  }
  .hour-bar {
    background: linear-gradient(to top, var(--sage) 0%, var(--sage) 60%, rgba(168, 188, 147, 0.4) 100%);
    border-radius: 4px 4px 0 0;
    min-height: 3px;
    transition: opacity 0.3s;
  }
  .hour-bar.empty {
    background: rgba(168, 188, 147, 0.15);
    min-height: 3px;
  }
  .hours-axis {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    color: var(--ink-fade);
    margin-top: 6px;
    font-weight: 500;
  }

  /* charts */
  .chart-wrap {
    height: 180px;
    position: relative;
    margin-top: 4px;
  }

  /* hand-drawn signature */
  .signature {
    text-align: center;
    font-family: 'Caveat', cursive;
    font-size: 16px;
    color: var(--ink-fade);
    margin-top: 28px;
    margin-bottom: 8px;
    z-index: 2;
    position: relative;
  }
</style>
</head>
<body>

<!-- Full-viewport sparkle field — populated by JS, sparkles toggle .visible
     based on time-since-last-hit relative to the rolling-30d waking average. -->
<div class="sparkle-field" id="sparkleField"></div>

<!-- Drifting clouds (clipped to viewport) -->
<div class="cloud-layer">
  <svg class="cloud cloud-1" width="220" height="90" viewBox="0 0 220 90">
    <defs>
      <filter id="softCloud1" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="2.5"/>
      </filter>
      <radialGradient id="cloudFill1" cx="45%" cy="35%">
        <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
        <stop offset="65%" stop-color="#FBF6EE" stop-opacity="0.95"/>
        <stop offset="100%" stop-color="#F2E0CE" stop-opacity="0.75"/>
      </radialGradient>
    </defs>
    <g filter="url(#softCloud1)">
      <ellipse cx="55" cy="58" rx="42" ry="22" fill="url(#cloudFill1)"/>
      <ellipse cx="105" cy="42" rx="55" ry="30" fill="url(#cloudFill1)"/>
      <ellipse cx="160" cy="55" rx="48" ry="26" fill="url(#cloudFill1)"/>
      <ellipse cx="85" cy="62" rx="28" ry="14" fill="url(#cloudFill1)"/>
      <ellipse cx="135" cy="60" rx="30" ry="14" fill="url(#cloudFill1)"/>
    </g>
  </svg>
  <svg class="cloud cloud-2" width="200" height="80" viewBox="0 0 200 80">
    <defs>
      <filter id="softCloud2" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="2.5"/>
      </filter>
      <radialGradient id="cloudFill2" cx="55%" cy="35%">
        <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
        <stop offset="65%" stop-color="#FBF6EE" stop-opacity="0.95"/>
        <stop offset="100%" stop-color="#F2E0CE" stop-opacity="0.75"/>
      </radialGradient>
    </defs>
    <g filter="url(#softCloud2)">
      <ellipse cx="50" cy="50" rx="38" ry="20" fill="url(#cloudFill2)"/>
      <ellipse cx="100" cy="38" rx="50" ry="26" fill="url(#cloudFill2)"/>
      <ellipse cx="150" cy="48" rx="42" ry="22" fill="url(#cloudFill2)"/>
      <ellipse cx="120" cy="55" rx="26" ry="13" fill="url(#cloudFill2)"/>
    </g>
  </svg>
</div>

<!-- Cloud spirit at top of page -->
<div class="spirit-wrap" id="spiritWrap">
  <div class="spirit-stage">
    <svg class="spirit" viewBox="0 0 100 100">
      <defs>
        <radialGradient id="spiritGrad" cx="38%" cy="32%">
          <stop offset="0%" stop-color="#FFFFFF"/>
          <stop offset="65%" stop-color="#FBF5EC"/>
          <stop offset="100%" stop-color="#EDDFC8"/>
        </radialGradient>
        <filter id="spiritShadow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="0.4"/>
        </filter>
      </defs>
      <!-- soft side wisps -->
      <ellipse cx="14" cy="58" rx="9" ry="6.5" fill="url(#spiritGrad)" opacity="0.7"/>
      <ellipse cx="86" cy="58" rx="9" ry="6.5" fill="url(#spiritGrad)" opacity="0.7"/>
      <!-- main rounded body -->
      <ellipse cx="50" cy="52" rx="34" ry="30" fill="url(#spiritGrad)" filter="url(#spiritShadow)"/>
      <!-- cheeks -->
      <ellipse class="cheek" cx="34" cy="58" rx="5.5" ry="3.5" fill="#F4B393"/>
      <ellipse class="cheek" cx="66" cy="58" rx="5.5" ry="3.5" fill="#F4B393"/>
      <!-- eyes (Ghibli-style soft dots, with gentle blink) — radii are CSS-driven
           so they grow with the joy ladder via --pupil-r / --shine-r -->
      <g class="eye-left">
        <circle class="eye-pupil" cx="42" cy="50.5" fill="#3A332C"/>
        <circle class="eye-shine" cx="42.7" cy="49.6" fill="#FAF3E7" opacity="0.9"/>
      </g>
      <g class="eye-right">
        <circle class="eye-pupil" cx="58" cy="50.5" fill="#3A332C"/>
        <circle class="eye-shine" cx="58.7" cy="49.6" fill="#FAF3E7" opacity="0.9"/>
      </g>
      <!-- soft smile -->
      <path d="M 47.5 58.5 Q 50 60.5 52.5 58.5" stroke="#3A332C" stroke-width="1.4" fill="none" stroke-linecap="round"/>
    </svg>
  </div>
</div>

<div class="hero">
  <div class="hero-label">free for</div>
  <div class="timer" id="timer">—</div>
  <div class="bests">
    <div class="best best-waking">
      <div class="best-num">${longestWakingGapStr}</div>
      <div class="best-label">longest waking</div>
    </div>
    <div class="best best-overall">
      <div class="best-num">${longestGapStr}</div>
      <div class="best-label">longest overall</div>
    </div>
  </div>
</div>

<div class="stat-row">
  <div class="card stat-card">
    <div class="card-title">today</div>
    <div class="stat-num coral">${todayCount}</div>
    <div class="stat-label">${todayCount === 1 ? 'hit' : 'hits'}</div>
  </div>
  <div class="card stat-card">
    <div class="card-title">average</div>
    <div class="stat-num sage">${avgPerDayStr}</div>
    <div class="stat-label">hits per day · 30d</div>
  </div>
</div>

<div class="card stat-card">
  <div class="card-title">waking gap</div>
  <div class="stat-num sage">${wakingAvgStr}</div>
  <div class="stat-label">average between hits · 30d</div>
</div>

<div class="card">
  <div class="card-title">today's stretches</div>
  <div class="card-sub">minutes between hits today</div>
  <div class="chart-wrap"><canvas id="todayChart"></canvas></div>
</div>

<div class="card">
  <div class="card-title">the last fortnight</div>
  <div class="card-sub">hits per day · last 14 days</div>
  <div class="chart-wrap"><canvas id="dailyChart"></canvas></div>
</div>

<div class="card">
  <div class="card-title">when the cravings hit</div>
  <div class="card-sub">hits by hour of day</div>
  <div class="hours" id="hoursContainer"></div>
  <div class="hours-axis">
    <span>12a</span><span>6a</span><span>noon</span><span>6p</span><span>12a</span>
  </div>
</div>

<div class="card">
  <div class="card-title">stretching the gaps</div>
  <div class="card-sub">7-day rolling average · minutes between hits</div>
  <div class="chart-wrap"><canvas id="rollingChart"></canvas></div>
</div>

<div class="signature">— keep drifting —</div>

<script>
const D = ${payload};

// ---- Live timer ----
function fmtElapsed(ms) {
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return [sec, 's'];
  if (sec < 3600) return [Math.floor(sec/60), 'm'];
  const h = Math.floor(sec/3600);
  const m = Math.floor((sec%3600)/60);
  return [h + 'h ' + m, 'm'];
}

function tick() {
  const ms = Date.now() - D.lastHitMs;
  const [val, unit] = fmtElapsed(ms);
  document.getElementById('timer').innerHTML = val + '<span class="unit">' + unit + '</span>';
  updateMood(ms);
}

// ---- Spirit state ----
// Single input: ratio = ms / avgMs (how many "averages" you've been free).
// All visuals are derived continuously from ratio — no joy ladder, no levels.
//   - eyes grow: pupil_r = clamp(2.4 + ln(ratio) * 1.0, 2.4, 8) px
//                pupil_cy = 52.9 - pupil_r (bottom-anchored at y=52.9)
//   - sparkles reveal: each sparkle has a per-element revealAt threshold; if
//     ratio >= revealAt, the sparkle gets the .visible class
const spiritWrap = document.getElementById('spiritWrap');

const avgMs   = (D.wakingAvgSec        || 0) * 1000;
const bestWMs = (D.longestWakingGapSec || 0) * 1000;
const bestOMs = (D.longestGapSec       || 0) * 1000;

// Generate 200 sparkles distributed across the entire viewport. They're sorted
// by distance from the spirit's perceived position (top-center, ~14% down) and
// assigned reveal thresholds along a power curve — so the halo around the
// spirit fills in first and the screen-fill happens at higher ratios.
const SPARKLE_TOTAL = 200;
const SPIRIT_X_PCT  = 50;
const SPIRIT_Y_PCT  = 16;
const SPARKLE_PALETTE = ['#E8B86B', '#F0C57C', '#FFD08C', '#E8836B', '#F4D88B'];
const sparkleEls = []; // [{ el, revealAt }, ...]

(function generateSparkles() {
  const host = document.getElementById('sparkleField');
  if (!host) return;

  // 1. Pick random positions across the viewport
  const positions = [];
  for (let i = 0; i < SPARKLE_TOTAL; i++) {
    const x = Math.random() * 100;
    const y = Math.random() * 100;
    // Weight vertical distance more lightly so the halo doesn't only fill
    // horizontally first when the viewport is taller than wide.
    const dx = x - SPIRIT_X_PCT;
    const dy = (y - SPIRIT_Y_PCT) * 0.85;
    positions.push({ x, y, dist: Math.hypot(dx, dy) });
  }
  // 2. Sort closest-to-spirit first
  positions.sort((a, b) => a.dist - b.dist);

  // 3. Assign reveal thresholds along a power curve — closest sparkles unlock
  //    just past avg (~1×), screen fully filled by ~20×. The exponent biases
  //    reveals toward later sparkles so the early/mid range still has steady
  //    growth without giving everything away too fast.
  positions.forEach((p, i) => {
    p.revealAt = 1 + Math.pow(i / (SPARKLE_TOTAL - 1), 1.5) * 19;
  });

  // 4. Build one DOM element per sparkle with its own drift/twinkle params
  for (const p of positions) {
    const el = document.createElement('div');
    el.className = 'sparkle';

    // size: mostly small, occasional bigger one
    const size = Math.random() < 0.18
      ? 10 + Math.random() * 6   // 10–16
      : 6 + Math.random() * 4;   // 6–10

    el.style.left = p.x.toFixed(2) + '%';
    el.style.top  = p.y.toFixed(2) + '%';
    el.style.width  = size.toFixed(1) + 'px';
    el.style.height = size.toFixed(1) + 'px';

    el.style.setProperty('--dx', ((Math.random() - 0.5) * 30).toFixed(1) + 'px');
    el.style.setProperty('--dy', ((Math.random() - 0.5) * 30).toFixed(1) + 'px');
    const driftDur = (4.5 + Math.random() * 5).toFixed(1);
    el.style.setProperty('--drift-dur',   driftDur + 's');
    el.style.setProperty('--drift-delay', (-Math.random() * driftDur).toFixed(1) + 's');
    const twinkleDur = (2.4 + Math.random() * 1.6).toFixed(1);
    el.style.setProperty('--twinkle-dur',   twinkleDur + 's');
    el.style.setProperty('--twinkle-delay', (-Math.random() * twinkleDur).toFixed(1) + 's');

    const color = SPARKLE_PALETTE[Math.floor(Math.random() * SPARKLE_PALETTE.length)];
    const r = 4.5;
    const inner = (r * 0.23).toFixed(2);
    const path = 'M 0 ' + (-r) + ' L ' + inner + ' ' + (-inner) +
                 ' L ' + r + ' 0 L ' + inner + ' ' + inner +
                 ' L 0 ' + r + ' L ' + (-inner) + ' ' + inner +
                 ' L ' + (-r) + ' 0 L ' + (-inner) + ' ' + (-inner) + ' Z';
    el.innerHTML =
      '<svg viewBox="-5 -5 10 10" preserveAspectRatio="xMidYMid meet">' +
        '<path d="' + path + '" fill="' + color + '"/>' +
      '</svg>';

    host.appendChild(el);
    sparkleEls.push({ el, revealAt: p.revealAt });
  }
})();

// applyState: derive every visual from a single 'ratio' and push to CSS vars
//   ratio < ~1   → at or below average
//   ratio = 1    → exactly at average
//   ratio = 5    → 5× your average gap, eyes noticeably bigger, halo of sparkles
//   ratio = 30+  → eyes near max, sparkles filling the screen
function applyState(ratio) {
  ratio = Math.max(0.001, ratio);
  const lr = Math.log(ratio); // natural log; can be negative below average

  // Eye scaling — bottom-anchored at y=52.9 so eyes grow toward the forehead.
  // Coefficient 2.5 means eyes reach ~3/4 of max growth by ratio 4× and
  // saturate (cap at 8) around ratio 10×.
  const PUPIL_BASE = 2.4;
  const PUPIL_MAX  = 8;
  const pupilR  = Math.min(PUPIL_MAX, Math.max(PUPIL_BASE, PUPIL_BASE + lr * 2.5));
  const pupilCy = 52.9 - pupilR;
  // Shine scales proportionally; its center stays a fixed fraction above pupil center
  const shineR  = pupilR * 0.27;
  const shineCy = 52.9 - pupilR * 1.375;

  spiritWrap.style.setProperty('--pupil-r',  pupilR.toFixed(2)  + 'px');
  spiritWrap.style.setProperty('--pupil-cy', pupilCy.toFixed(2) + 'px');
  spiritWrap.style.setProperty('--shine-r',  shineR.toFixed(2)  + 'px');
  spiritWrap.style.setProperty('--shine-cy', shineCy.toFixed(2) + 'px');

  // Sparkle reveal — toggle .visible on each based on its threshold
  for (const s of sparkleEls) {
    const want = ratio >= s.revealAt;
    if (want !== s.visible) {
      s.el.classList.toggle('visible', want);
      s.visible = want;
    }
  }

  // Milestones — body-level classes so the timer + best-text (outside
  // spirit-wrap) can also style off them. Compute against absolute ms so the
  // debugger slider naturally crosses these thresholds at the right ratios.
  const ms = ratio * avgMs;
  document.body.classList.toggle('milestone-waking',  bestWMs > 0 && ms >= bestWMs);
  document.body.classList.toggle('milestone-overall', bestOMs > 0 && ms >= bestOMs);
}

let lastRatio = -1;
function updateMood(ms) {
  if (window.__spiritDebugLock) return;
  if (avgMs <= 0) {
    applyState(1);
    return;
  }
  const ratio = ms / avgMs;
  // Skip tiny changes to avoid thrash
  if (Math.abs(ratio - lastRatio) < 0.005) return;
  lastRatio = ratio;
  applyState(ratio);
}

// ===========================================================================
// DEBUG: spirit-mood preview overlay. Closed by default; tap "preview spirit"
// in the footer to open. Inside, tap a joy level to lock the spirit into that
// state, "live" to release the lock, or × to dismiss the panel.
// ===========================================================================
(function setupSpiritDebugger() {
  const style = document.createElement('style');
  style.textContent =
    '#moodDebug {' +
    '  position: fixed; bottom: 12px; right: 12px; z-index: 9999;' +
    '  background: rgba(74, 69, 63, 0.94);' +
    '  color: #FAF3E7;' +
    '  padding: 10px 14px 12px;' +
    '  border-radius: 14px;' +
    "  font-family: 'Quicksand', sans-serif; font-size: 11px;" +
    '  width: 260px;' +
    '  box-shadow: 0 12px 28px -10px rgba(0,0,0,0.45);' +
    '  backdrop-filter: blur(6px);' +
    '}' +
    '#moodDebug.hidden { display: none; }' +
    '#moodDebug .dbg-title {' +
    "  font-family: 'Caveat', cursive;" +
    '  font-size: 16px; opacity: 0.85; margin-bottom: 8px;' +
    '  display: flex; justify-content: space-between; align-items: center;' +
    '}' +
    '#moodDebug .dbg-close {' +
    '  background: transparent; border: none; color: #FAF3E7;' +
    '  font-size: 18px; line-height: 1; padding: 0 4px; cursor: pointer; opacity: 0.7;' +
    '  font-family: inherit;' +
    '}' +
    '#moodDebug .dbg-close:active { opacity: 1; }' +
    '#moodDebug .dbg-live {' +
    '  background: rgba(168,188,147,0.25); border: 1px solid rgba(168,188,147,0.5);' +
    '  color: #FAF3E7; padding: 4px 9px; border-radius: 7px;' +
    '  font-size: 11px; font-family: inherit; cursor: pointer;' +
    '  margin-bottom: 8px;' +
    '}' +
    '#moodDebug .dbg-live.active { background: #7E9476; border-color: #7E9476; }' +
    '#moodDebug .dbg-slider {' +
    '  width: 100%; margin: 4px 0 6px;' +
    '  -webkit-appearance: none; appearance: none;' +
    '  height: 4px; background: rgba(250,243,231,0.18); border-radius: 2px; outline: none;' +
    '}' +
    '#moodDebug .dbg-slider::-webkit-slider-thumb {' +
    '  -webkit-appearance: none; appearance: none;' +
    '  width: 16px; height: 16px; border-radius: 50%; background: #E8B86B;' +
    '  cursor: pointer; border: 2px solid #FAF3E7;' +
    '}' +
    '#moodDebug .dbg-readout {' +
    "  font-family: 'Fraunces', serif; font-size: 13px; opacity: 0.92;" +
    '  display: flex; justify-content: space-between; gap: 8px;' +
    '}' +
    '#moodDebug .dbg-readout .ratio { color: #E8B86B; }' +
    '#moodDebug .dbg-readout .time  { opacity: 0.6; }' +
    '#spiritDebugReopen {' +
    '  display: inline-block; margin-left: 10px;' +
    "  font-family: 'Quicksand', sans-serif; font-size: 11px;" +
    '  color: var(--ink-fade); opacity: 0.55;' +
    '  cursor: pointer; text-decoration: underline; text-underline-offset: 2px;' +
    '}' +
    '#spiritDebugReopen:active { opacity: 0.9; }';
  document.head.appendChild(style);

  const panel = document.createElement('div');
  panel.id = 'moodDebug';
  panel.innerHTML =
    '<div class="dbg-title">' +
      '<span>spirit preview</span>' +
      '<button class="dbg-close" type="button" aria-label="close">×</button>' +
    '</div>' +
    '<button class="dbg-live" type="button">live</button>' +
    '<input class="dbg-slider" type="range" min="0" max="100" step="0.5" value="33.3">' +
    '<div class="dbg-readout">' +
      '<span class="ratio">1.0× avg</span>' +
      '<span class="time">~ 0s</span>' +
    '</div>';
  document.body.appendChild(panel);

  const slider     = panel.querySelector('.dbg-slider');
  const liveBtn    = panel.querySelector('.dbg-live');
  const ratioLabel = panel.querySelector('.ratio');
  const timeLabel  = panel.querySelector('.time');

  // Footer reopen link
  const sig = document.querySelector('.signature');
  let reopenLink = null;
  if (sig) {
    reopenLink = document.createElement('a');
    reopenLink.id = 'spiritDebugReopen';
    reopenLink.textContent = 'preview spirit';
    reopenLink.style.display = 'none';
    sig.appendChild(reopenLink);
  }

  // Slider 0..100 maps log-style to ratio 0.1× .. 100×, with 1× at slider=33.3
  function sliderToRatio(v) { return 0.1 * Math.pow(1000, v / 100); }
  function ratioToSlider(r) { return 100 * Math.log(r / 0.1) / Math.log(1000); }

  function fmtTime(ms) {
    const sec = Math.max(0, Math.floor(ms / 1000));
    if (sec < 60)   return '~ ' + sec + 's';
    if (sec < 3600) return '~ ' + Math.floor(sec / 60) + 'm';
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    return '~ ' + h + 'h ' + m + 'm';
  }

  function paintReadout(ratio) {
    ratioLabel.textContent = (ratio < 10 ? ratio.toFixed(2) : Math.round(ratio)) + '× avg';
    timeLabel.textContent  = avgMs > 0 ? fmtTime(ratio * avgMs) : '—';
  }

  function setLocked(ratio) {
    window.__spiritDebugLock = true;
    liveBtn.classList.remove('active');
    applyState(ratio);
    paintReadout(ratio);
  }
  function setLive() {
    window.__spiritDebugLock = false;
    liveBtn.classList.add('active');
    lastRatio = -1; // force re-application on next tick
    const ms = Date.now() - D.lastHitMs;
    const r = avgMs > 0 ? ms / avgMs : 1;
    applyState(r);
    lastRatio = r;
    slider.value = ratioToSlider(Math.max(0.1, Math.min(100, r)));
    paintReadout(r);
  }

  slider.addEventListener('input', () => setLocked(sliderToRatio(+slider.value)));
  liveBtn.addEventListener('click', setLive);

  function openPanel() {
    panel.classList.remove('hidden');
    if (reopenLink) reopenLink.style.display = 'none';
  }
  function closePanel() {
    panel.classList.add('hidden');
    if (reopenLink) reopenLink.style.display = 'inline-block';
  }
  panel.querySelector('.dbg-close').addEventListener('click', closePanel);
  if (reopenLink) reopenLink.addEventListener('click', openPanel);

  setLive();
  closePanel(); // start closed; user opens via the footer link
})();
// === END DEBUG ===

tick();
setInterval(tick, 1000);

// ---- Hour distribution ----
const hoursEl = document.getElementById('hoursContainer');
const maxHour = Math.max(...D.hourly, 1);
D.hourly.forEach((c, i) => {
  const bar = document.createElement('div');
  bar.className = 'hour-bar' + (c === 0 ? ' empty' : '');
  const pct = c === 0 ? 0 : Math.max(0.18, c / maxHour);
  bar.style.height = (pct * 100) + '%';
  bar.title = i + ':00 — ' + c + ' hits';
  hoursEl.appendChild(bar);
});

// ---- Chart.js global config ----
Chart.defaults.font.family = 'Quicksand';
Chart.defaults.font.size = 11;
Chart.defaults.color = '#9A9082';

// ---- Daily bar chart ----
const dailyCtx = document.getElementById('dailyChart').getContext('2d');
const dailyMax = Math.max(...D.daily.map(d => d.count), 1);
const dailyStep = Math.max(1, Math.ceil(dailyMax / 4));
const dailyAxisMax = dailyStep * 5;

const peachGrad = dailyCtx.createLinearGradient(0, 0, 0, 180);
peachGrad.addColorStop(0, '#F4B393');
peachGrad.addColorStop(1, 'rgba(244, 179, 147, 0.4)');

const todayGrad = dailyCtx.createLinearGradient(0, 0, 0, 180);
todayGrad.addColorStop(0, '#E8836B');
todayGrad.addColorStop(1, 'rgba(232, 131, 107, 0.5)');

new Chart(dailyCtx, {
  type: 'bar',
  data: {
    labels: D.daily.map(d => d.label),
    datasets: [{
      data: D.daily.map(d => d.count),
      backgroundColor: D.daily.map(d => d.isToday ? todayGrad : peachGrad),
      // Rounded top, flat bottom — matches the hour-bar style.
      // Default borderSkipped ('start' for vertical bars) leaves the bottom
      // edge unrounded once we drop the explicit borderSkipped: false.
      borderRadius: 8,
      barThickness: 14
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false }, tooltip: {
      backgroundColor: 'rgba(74, 69, 63, 0.92)',
      padding: 8, cornerRadius: 8, displayColors: false,
      titleFont: { family: 'Quicksand', weight: '600' },
      bodyFont: { family: 'Quicksand' }
    }},
    scales: {
      y: { beginAtZero: true, max: dailyAxisMax,
        grid: { color: 'rgba(154, 144, 130, 0.12)', drawBorder: false },
        ticks: { stepSize: dailyStep }
      },
      x: { grid: { display: false, drawBorder: false }, ticks: { font: { size: 10 } } }
    }
  }
});

// ---- Today's stretches line chart ----
const todayCtx = document.getElementById('todayChart').getContext('2d');
const todayGapGrad = todayCtx.createLinearGradient(0, 0, 0, 180);
todayGapGrad.addColorStop(0, 'rgba(232, 131, 107, 0.55)');
todayGapGrad.addColorStop(1, 'rgba(232, 131, 107, 0.05)');

if (D.todayStretches.length === 0) {
  todayCtx.canvas.parentElement.innerHTML = '<div style="text-align:center;color:#9A9082;padding:40px 0;font-family:Caveat;font-size:18px">no stretches yet today...</div>';
} else {
  new Chart(todayCtx, {
    type: 'line',
    data: {
      labels: D.todayStretches.map(s => s.label),
      datasets: [{
        data: D.todayStretches.map(s => s.gapMin),
        borderColor: '#E8836B',
        borderWidth: 2.5,
        backgroundColor: todayGapGrad,
        fill: true,
        tension: 0.35,
        pointRadius: 3,
        pointBackgroundColor: '#E8836B',
        pointBorderColor: '#FFFFFF',
        pointBorderWidth: 1.5,
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false }, tooltip: {
        backgroundColor: 'rgba(74, 69, 63, 0.92)',
        padding: 8, cornerRadius: 8, displayColors: false,
        callbacks: { label: ctx => ctx.parsed.y + ' min stretch' }
      }},
      scales: {
        y: { beginAtZero: true,
          grid: { color: 'rgba(154, 144, 130, 0.12)', drawBorder: false },
          ticks: { callback: v => v + 'm' }
        },
        x: { grid: { display: false, drawBorder: false }, ticks: { maxTicksLimit: 6, font: { size: 10 } } }
      }
    }
  });
}

// ---- Rolling average line chart ----
const rollCtx = document.getElementById('rollingChart').getContext('2d');
const sageGrad = rollCtx.createLinearGradient(0, 0, 0, 180);
sageGrad.addColorStop(0, 'rgba(168, 188, 147, 0.55)');
sageGrad.addColorStop(1, 'rgba(168, 188, 147, 0.05)');

if (D.rolling.length === 0) {
  rollCtx.canvas.parentElement.innerHTML = '<div style="text-align:center;color:#9A9082;font-size:13px;padding:40px 0;font-family:Caveat;font-size:18px">need a few more days of data...</div>';
} else {
  new Chart(rollCtx, {
    type: 'line',
    data: {
      labels: D.rolling.map(r => r.label),
      datasets: [{
        data: D.rolling.map(r => r.avgMin),
        borderColor: '#7E9476',
        borderWidth: 2.5,
        backgroundColor: sageGrad,
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 5,
        pointHoverBackgroundColor: '#7E9476',
        pointHoverBorderColor: '#FFFFFF',
        pointHoverBorderWidth: 2
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false }, tooltip: {
        backgroundColor: 'rgba(74, 69, 63, 0.92)',
        padding: 8, cornerRadius: 8, displayColors: false,
        callbacks: { label: ctx => ctx.parsed.y + ' min avg' }
      }},
      scales: {
        y: { beginAtZero: true,
          grid: { color: 'rgba(154, 144, 130, 0.12)', drawBorder: false },
          ticks: { callback: v => v + 'm' }
        },
        x: { grid: { display: false, drawBorder: false }, ticks: { maxTicksLimit: 6, font: { size: 10 } } }
      }
    }
  });
}
</script>
</body>
</html>`

// ---------- Show ----------
const wv = new WebView()
await wv.loadHTML(html)
await wv.present(true) // fullscreen
Script.complete()
