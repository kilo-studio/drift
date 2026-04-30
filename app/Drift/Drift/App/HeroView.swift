import SwiftUI

/// Top-of-dashboard "free for X" block. Left-aligned so the spirit can sit to its right.
struct HeroPrimaryView: View {
    let lastHitDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text.caveatLeading("free for")
                .font(.driftHeroLabel)
                .foregroundStyle(.driftInkSoft)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                timer(elapsed: lastHitDate.map { ctx.date.timeIntervalSince($0) } ?? 0)
            }
        }
    }

    private func timer(elapsed: TimeInterval) -> some View {
        let parts = formatElapsed(elapsed)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(parts.number)
                .font(.driftDisplay)
                .tracking(-1.5)
                .foregroundStyle(.driftInk)
            Text(parts.unit)
                .font(.driftTimerUnit)
                .foregroundStyle(.driftInkSoft)
        }
    }
}

/// Two stacked, left-aligned bests rows.
/// Top: longest gap while awake. Below: all-time longest gap.
struct HeroBestsView: View {
    let longestWakingGapSec: TimeInterval
    let longestGapSec: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bestRow(label: "longest gap while awake", value: longestWakingGapSec)
            bestRow(label: "all time longest gap", value: longestGapSec)
        }
    }

    private func bestRow(label: String, value: TimeInterval) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value > 0 ? formatGap(value) : "—")
                .font(.driftBestNum)
                .tracking(-0.2)
                .foregroundStyle(.driftInk)
            Text.caveatLeading(label)
                .font(.driftBestLabel)
                .foregroundStyle(.driftInkSoft)
        }
    }
}
