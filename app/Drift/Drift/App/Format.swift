import Foundation

/// Splits elapsed time into a big-number string + small unit suffix, mirroring
/// the prototype's `fmtElapsed`. Used by the widget where space is tight and a
/// flat (number, unit) pair is enough.
/// - Under 60s → ("X", "s")
/// - Under 60m → ("X", "m")
/// - Else      → ("Xh Y", "m")
func formatElapsed(_ seconds: TimeInterval) -> (number: String, unit: String) {
    let s = max(0, Int(seconds))
    if s < 60 { return ("\(s)", "s") }
    if s < 3600 { return ("\(s / 60)", "m") }
    let h = s / 3600
    let m = (s % 3600) / 60
    return ("\(h)h \(m)", "m")
}

/// Same content as `formatElapsed` but split into number/unit parts so the hero
/// timer can render every unit ("h", "m", "s") with the same small font instead
/// of having an embedded "h" rendered at the big bold weight.
enum ElapsedPart {
    case number(String)
    case unit(String)
}

func formatElapsedParts(_ seconds: TimeInterval) -> [ElapsedPart] {
    let s = max(0, Int(seconds))
    if s < 60 { return [.number("\(s)"), .unit("s")] }
    if s < 3600 { return [.number("\(s / 60)"), .unit("m")] }
    let h = s / 3600
    let m = (s % 3600) / 60
    return [.number("\(h)"), .unit("h "), .number("\(m)"), .unit("m")]
}

/// Same as `formatGap` but split into number/unit parts so stat cards can render
/// the units smaller than the big number.
func formatGapParts(_ seconds: TimeInterval) -> [ElapsedPart] {
    formatElapsedParts(seconds)
}

/// Compact gap string for inline / bests display: `Xs` / `Ym` / `Xh Ym` /
/// `Xd Yh`. The day form keeps the all-time-longest-gap record readable once
/// long stretches push it past a day (otherwise it read as e.g. "768h 0m").
func formatGap(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m" }
    if s < 86_400 {
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
    let d = (s / 86_400).formatted(.number.grouping(.automatic))
    let h = (s % 86_400) / 3600
    return h > 0 ? "\(d)d \(h)h" : "\(d)d"
}

// MARK: - Long-stretch formatting

private let secPerDay = 86_400
private let secPerWeek = 7 * 86_400
private let secPerMonth = 30 * 86_400   // calm approximation; long-stretch copy only
private let secPerYear = 365 * 86_400

/// Calm "dominant unit + single remainder" presentation for long drifts, split
/// into number/unit parts so the long-stretch hero renders the dominant number
/// big and the unit + remainder small (mirrors `formatElapsedParts`). Below a
/// day it falls back to `formatElapsedParts` (h/m/s). Never a deep cascade —
/// at most two units, so it stays scannable at day/week/month scale.
func formatElapsedLongParts(_ seconds: TimeInterval) -> [ElapsedPart] {
    let s = max(0, Int(seconds))
    if s < secPerDay { return formatElapsedParts(seconds) }
    // Days + hours is precise, always includes the live hours, and matches how
    // people actually count a long stretch ("Day 32"). Weeks/months live on as
    // milestone labels, not as the running number. The day count gets a grouping
    // separator once it reaches the thousands ("1,825d").
    let days = (s / secPerDay).formatted(.number.grouping(.automatic))
    return [.number(days), .unit("d "), .number("\((s % secPerDay) / 3600)"), .unit("h")]
}

/// Humane sentence fragment picking the largest natural unit, singular/plural
/// aware: "9 days", "1 week", "3 weeks", "1 month", "2 months", "1 year". Used
/// by the longest-yet line, milestone labels, and the relapse acknowledgment.
func formatDurationHuman(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    func unit(_ n: Int, _ name: String) -> String { "\(n) \(name)\(n == 1 ? "" : "s")" }
    if s >= secPerYear { return unit(s / secPerYear, "year") }
    if s >= secPerMonth { return unit(s / secPerMonth, "month") }
    if s >= secPerWeek { return unit(s / secPerWeek, "week") }
    if s >= secPerDay { return unit(s / secPerDay, "day") }
    if s >= 3600 { return unit(s / 3600, "hour") }
    if s >= 60 { return unit(s / 60, "minute") }
    return unit(s, "second")
}
