import Foundation

let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

/// UserDefaults keys for the user-configurable sleep window. Read via
/// `driftSleepStartHour()` / `driftSleepEndHour()` so the date-key helpers can
/// stay free functions without taking HitStore as a dependency.
let driftSleepStartHourKey = "drift.sleep.startHour"
let driftSleepEndHourKey = "drift.sleep.endHour"

/// Hour 0–23 the user typically goes to sleep. Drives the notification overnight
/// hedge. Default 23 (matches Issue 12 spec).
func driftSleepStartHour() -> Int {
    (UserDefaults.standard.object(forKey: driftSleepStartHourKey) as? Int) ?? 23
}

/// Hour 0–23 the user typically wakes. Drives both the waking-day cutoff (hits
/// before this hour roll back to the previous day's bucket) and the notification
/// overnight hedge. Default 6 (matches Issue 12 spec).
func driftSleepEndHour() -> Int {
    (UserDefaults.standard.object(forKey: driftSleepEndHourKey) as? Int) ?? 6
}

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

    /// "yyyy-MM-dd" with a sleep-end cutoff (default 6am, configurable in
    /// settings): hits before that hour roll back to the previous day. Keeps
    /// overnight sleep gaps out of within-day calculations.
    var wakingDayKey: String {
        var d = local
        let hour = utcCalendar.component(.hour, from: d)
        if hour < driftSleepEndHour() {
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

/// Waking-day key for the device's current time. Uses the configurable sleep-end
/// cutoff (default 6) in device-local zone — hits before that hour roll back.
func currentWakingDayKey(_ date: Date = .now) -> String {
    let cal = Calendar(identifier: .gregorian)
    let hour = cal.component(.hour, from: date)
    let d = hour < driftSleepEndHour() ? cal.date(byAdding: .day, value: -1, to: date)! : date
    let comps = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

/// Sleep-end cutoff (default 6am, configurable) that ends the waking day
/// containing `date` (device-local). Returns the next cutoff after `date` (or
/// today's cutoff if `date` is before it).
func endOfWakingDay(_ date: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)
    let cutoffHour = driftSleepEndHour()
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
    let hour = comps.hour ?? 0
    comps.hour = cutoffHour
    comps.minute = 0
    comps.second = 0
    if hour < cutoffHour {
        return cal.date(from: comps)!
    } else {
        let todayCutoff = cal.date(from: comps)!
        return cal.date(byAdding: .day, value: 1, to: todayCutoff)!
    }
}
