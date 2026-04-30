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

/// Compact gap string for inline / bests display: `Xs` / `Ym` / `Xh Ym`.
func formatGap(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return "\(h)h \(m)m"
}
