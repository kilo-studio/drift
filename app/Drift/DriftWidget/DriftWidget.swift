import WidgetKit
import SwiftUI

struct DriftEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetBridge.Snapshot
}

struct DriftProvider: TimelineProvider {
    func placeholder(in context: Context) -> DriftEntry {
        DriftEntry(date: .now, snapshot: WidgetBridge.read())
    }

    func getSnapshot(in context: Context, completion: @escaping (DriftEntry) -> Void) {
        completion(DriftEntry(date: .now, snapshot: WidgetBridge.read()))
    }

    /// Refresh every 5 minutes — the widget is showing time-since-last-hit which
    /// the system can update from the timer view, but a periodic timeline refresh
    /// keeps `wakingAvgSec` and the bests in sync after a hit lands elsewhere.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DriftEntry>) -> Void) {
        let now = Date()
        let snap = WidgetBridge.read()
        let entries: [DriftEntry] = (0..<6).map { offset in
            DriftEntry(
                date: Calendar.current.date(byAdding: .minute, value: offset * 5, to: now)!,
                snapshot: snap
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private let pupilColor = Color(red: 58/255, green: 51/255, blue: 44/255)
private let inkColor   = Color(red: 74/255, green: 69/255, blue: 63/255)
private let inkSoft    = Color(red: 107/255, green: 99/255, blue: 90/255)
private let surface    = Color(red: 255/255, green: 251/255, blue: 244/255)

struct DriftWidgetEntryView: View {
    var entry: DriftProvider.Entry

    var body: some View {
        let elapsed = entry.snapshot.lastHit.map { entry.date.timeIntervalSince($0) } ?? 0
        let parts = formatElapsed(elapsed)

        VStack(spacing: 4) {
            Text("free for")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(parts.number)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(inkColor)
                Text(parts.unit)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(inkSoft)
            }
            Text("tap to log")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(inkSoft)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(surface, for: .widget)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> (number: String, unit: String) {
        let s = max(0, Int(seconds))
        if s < 60 { return ("\(s)", "s") }
        if s < 3600 { return ("\(s / 60)", "m") }
        let h = s / 3600
        let m = (s % 3600) / 60
        return ("\(h)h \(m)", "m")
    }
}

struct DriftWidget: Widget {
    let kind: String = "DriftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DriftProvider()) { entry in
            DriftWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Drift")
        .description("Time since your last hit. Tap to log.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    DriftWidget()
} timeline: {
    DriftEntry(
        date: .now,
        snapshot: WidgetBridge.Snapshot(
            lastHit: Calendar.current.date(byAdding: .minute, value: -23, to: .now),
            wakingAvgSec: 8400,
            longestWakingGapSec: 47340,
            longestGapSec: 83100
        )
    )
}
