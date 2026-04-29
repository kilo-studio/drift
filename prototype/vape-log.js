// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: red; icon-glyph: magic;
// Vape Log — logs a hit and computes stats
// File: iCloud Drive/Scriptable/vape-log.json
// Trigger from Shortcuts via "Run Script" action (script: vape-log)

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

// Group hits into "waking days" using a 4am cutoff so sleep gaps don't
// pollute the average. A hit at 2am Wed belongs to Tue's bucket.
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

// Longest interval between two consecutive hits within a single waking day.
// Sleep gaps are excluded because cross-bucket pairs aren't compared.
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

// Next 4am-cutoff after `date` — i.e., when the current waking day ends.
function endOfWakingDay(date) {
  const d = new Date(date)
  if (d.getHours() < 4) {
    d.setHours(4, 0, 0, 0)
  } else {
    d.setDate(d.getDate() + 1)
    d.setHours(4, 0, 0, 0)
  }
  return d
}

const fm = FileManager.iCloud()
const path = fm.joinPath(fm.documentsDirectory(), "vape-log.json")

// Load or initialize
let data
if (fm.fileExists(path)) {
  if (!fm.isFileDownloaded(path)) {
    await fm.downloadFileFromiCloud(path)
  }
  data = JSON.parse(fm.readString(path))
  // Migrate string-format hits to {t, tz} objects (assumes current device tz
  // for hits logged before timezone tracking was added).
  const m = migrateHits(data.hits || [])
  data.hits = m.hits
  // Backfill waking-longest from existing hits for users upgrading.
  if (data.longestWakingGap === undefined) {
    data.longestWakingGap = computeLongestWakingGapSec(data.hits)
  }
} else {
  data = { hits: [], longestGap: 0, longestWakingGap: 0 }
}

const now = new Date()
const newHit = nowHit()
let notifBody
let avgIntervalSec = null

if (data.hits.length === 0) {
  // First hit ever
  data.hits.push(newHit)
  notifBody = "First hit logged. Building baseline."
} else {
  const lastHit = data.hits[data.hits.length - 1]
  const lastHitTime = new Date(lastHit.t)
  const deltaSec = Math.floor((now - lastHitTime) / 1000)
  const deltaMin = Math.floor(deltaSec / 60)

  // Update longest overall gap (sleep included — display only).
  if (deltaSec > data.longestGap) {
    data.longestGap = deltaSec
  }

  // Update longest waking gap — only counts when both hits share a waking day.
  let isNewWakingBest = false
  if (
    wakingDayKey(lastHit) === wakingDayKey(newHit) &&
    deltaSec > data.longestWakingGap
  ) {
    data.longestWakingGap = deltaSec
    isNewWakingBest = true
  }

  // Append current hit
  data.hits.push(newHit)

  // Average interval based on waking-hours grouping (4am-to-4am buckets),
  // computed over the rolling 30-day window. Includes today — this average is
  // about intervals between hits, not counts per day, so a partial day's
  // intervals are still real and should count.
  const ROLLING_WINDOW_DAYS = 30
  const windowEnd = new Date(deviceLocalDateKey(now) + 'T12:00:00Z')
  const windowStart = new Date(windowEnd)
  windowStart.setUTCDate(windowStart.getUTCDate() - ROLLING_WINDOW_DAYS)
  const windowStartKey = windowStart.toISOString().slice(0, 10)
  const hitsInWindow = data.hits.filter(h => logLocalDateKey(h) >= windowStartKey)
  avgIntervalSec = computeWakingAvgSec(hitsInWindow)

  // Fallback to all-time average if the window has no day with 2+ hits yet
  if (avgIntervalSec === null) {
    const firstHitTime = new Date(data.hits[0].t)
    const totalSpan = (now - firstHitTime) / 1000
    avgIntervalSec = Math.floor(totalSpan / (data.hits.length - 1))
  }
  const avgMin = Math.floor(avgIntervalSec / 60)

  // Notification body
  if (data.hits.length < 10) {
    notifBody = `${deltaMin}m since last hit · ${data.hits.length}/10 baseline`
  } else {
    notifBody = `⏱ ${deltaMin}m since last hit · avg ${avgMin}m`
    if (isNewWakingBest) notifBody += " · 🥇 new waking best"
  }
}

// Save updated data
fm.writeString(path, JSON.stringify(data, null, 2))

// Cancel any pending notifications for beating average or best
await Notification.removePending(["vape-beat-average", "vape-beat-record"])

// Show immediate notification
const n = new Notification()
n.title = "Vape Log"
n.body = notifBody
await n.schedule()

// Schedule the "beat your average" notification (only once baseline is complete)
if (avgIntervalSec !== null && data.hits.length >= 10) {
  const triggerDate = new Date(now.getTime() + (avgIntervalSec + 1) * 1000)
  const avgMinForBody = Math.floor(avgIntervalSec / 60)
  // Same overnight hedge as the record notif: if the trigger lands in typical
  // sleep hours, soften the wording since we can't tell if you were awake.
  const triggerHour = triggerDate.getHours()
  const overnight = triggerHour >= 23 || triggerHour < 6
  const next = new Notification()
  next.identifier = "vape-beat-average"
  next.title = "👏 You're beating your average"
  next.body = overnight
    ? `If you're still awake, you're past your average of ${avgMinForBody}m`
    : `Don't hit it — you're past your average of ${avgMinForBody}m`
  next.setTriggerDate(triggerDate)
  await next.schedule()
}

// Schedule notification for when current gap surpasses longest waking stretch.
// Cap the trigger to the end of the current waking day — sleep gaps shouldn't
// be celebrated as a "waking best."
if (data.longestWakingGap > 0 && data.hits.length >= 2) {
  const triggerDate = new Date(now.getTime() + (data.longestWakingGap + 1) * 1000)
  if (triggerDate <= endOfWakingDay(now)) {
    const bestForBody = Math.floor(data.longestWakingGap / 60)
    // If the trigger lands in the typical sleep window (23:00–06:00 local),
    // hedge the body — we can't tell from a scheduled notif whether the user
    // was actually awake the whole time.
    const triggerHour = triggerDate.getHours()
    const overnight = triggerHour >= 23 || triggerHour < 6
    const recordNotif = new Notification()
    recordNotif.identifier = "vape-beat-record"
    recordNotif.title = "🥇 new waking best"
    recordNotif.body = overnight
      ? `If you're still awake, you just beat your longest waking stretch of ${bestForBody}m. Keep drifting.`
      : `You just beat your longest waking stretch of ${bestForBody}m. Keep drifting.`
    recordNotif.setTriggerDate(triggerDate)
    await recordNotif.schedule()
  }
}

Script.complete()
