import Foundation

/// Splits elapsed time into a big-number string + small unit suffix, mirroring
/// the prototype's `fmtElapsed`.
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

/// Compact gap string for inline / bests display: `Xs` / `Ym` / `Xh Ym`.
func formatGap(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return "\(h)h \(m)m"
}
