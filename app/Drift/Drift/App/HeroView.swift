import SwiftUI

struct HeroView: View {
    let lastHitDate: Date?
    let longestWakingGapSec: TimeInterval
    let longestGapSec: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text.caveat("free for")
                    .font(.driftHeroLabel)
                    .foregroundStyle(.driftInkSoft)

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    timer(elapsed: lastHitDate.map { ctx.date.timeIntervalSince($0) } ?? 0)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 12)

            HStack(spacing: 36) {
                bestColumn(label: "longest waking", value: longestWakingGapSec)
                bestColumn(label: "longest overall", value: longestGapSec)
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

    private func bestColumn(label: String, value: TimeInterval) -> some View {
        VStack(spacing: 4) {
            Text(value > 0 ? formatGap(value) : "—")
                .font(.driftBestNum)
                .tracking(-0.2)
                .foregroundStyle(.driftInk)
            Text.caveat(label)
                .font(.driftBestLabel)
                .foregroundStyle(.driftInkSoft)
        }
    }
}
