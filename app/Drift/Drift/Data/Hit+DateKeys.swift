import Foundation

let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

extension Hit {
    /// Date whose UTC components yield the wall-clock the user saw at log time,
    /// regardless of the device's current zone.
    var local: Date {
        t.addingTimeInterval(TimeInterval(tzOffsetMinutes * 60))
    }

    /// "yyyy-MM-dd" in the hit's logged time zone.
    var logLocalDateKey: String {
        ymdKey(from: local)
    }

    /// "yyyy-MM-dd" with a 4am cutoff: hits 0–4am roll back to the previous day.
    /// Keeps overnight sleep gaps out of within-day calculations.
    var wakingDayKey: String {
        var d = local
        let hour = utcCalendar.component(.hour, from: d)
        if hour < 4 {
            d = utcCalendar.date(byAdding: .day, value: -1, to: d)!
        }
        return ymdKey(from: d)
    }
}

/// "yyyy-MM-dd" in the device's current time zone.
func deviceLocalDateKey(_ date: Date = .now) -> String {
    let cal = Calendar(identifier: .gregorian)
    let comps = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

/// "yyyy-MM-dd" given a Date interpreted in UTC components.
private func ymdKey(from date: Date) -> String {
    let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

/// Waking-day key for the device's current time (4am cutoff in device-local zone).
func currentWakingDayKey(_ date: Date = .now) -> String {
    let cal = Calendar(identifier: .gregorian)
    let hour = cal.component(.hour, from: date)
    let d = hour < 4 ? cal.date(byAdding: .day, value: -1, to: date)! : date
    let comps = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

/// 4am cutoff that ends the waking day containing `date` (device-local).
/// Returns the next 4am after `date` (or today's 4am if `date` is before it).
func endOfWakingDay(_ date: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
    let hour = comps.hour ?? 0
    if hour < 4 {
        comps.hour = 4
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps)!
    } else {
        comps.hour = 4
        comps.minute = 0
        comps.second = 0
        let today4am = cal.date(from: comps)!
        return cal.date(byAdding: .day, value: 1, to: today4am)!
    }
}
