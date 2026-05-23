import SwiftUI

/// Pieces of the home screen's long-stretch mode (active when "free for" ≥ ~a
/// day). The screen reframes around the durable "free for X" timer, a progress
/// donut toward the next time milestone, and a "longest drift" reference card —
/// the frequency cards/charts are meaningless at this scale and hidden.
///
/// Philosophy: these all *describe time / persisted data* — never judge you.
/// No "quit", no streaks that reset, no badges. The longest-drift record
/// survives a relapse; the donut visualizes present progress, like the baseline
/// donut does for the establishing period.

/// Big centered "free for X" timer — days + hours past a day.
struct LongStretchHero: View {
    let lastSessionEnd: Date?

    var body: some View {
        VStack(spacing: 6) {
            Text.caveat("free for")
                .font(.driftHeroLabel)
                .foregroundStyle(.driftInkSoft)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                timer(elapsed: lastSessionEnd.map { ctx.date.timeIntervalSince($0) } ?? 0)
            }
        }
    }

    private func timer(elapsed: TimeInterval) -> some View {
        let parts = formatElapsedLongParts(elapsed)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(parts.indices, id: \.self) { i in
                switch parts[i] {
                case .number(let s):
                    Text(s).font(.driftDisplay).tracking(-1.5).foregroundStyle(.driftInk)
                case .unit(let s):
                    Text(s).font(.driftTimerUnit).foregroundStyle(.driftInkSoft)
                }
            }
        }
    }
}

/// Progress ring toward the next time milestone. Fills across the *current*
/// interval (last passed marker → next marker), so it reads as "drifting
/// toward the next one" rather than a near-full bar. Same ring language as the
/// baseline donut. Past the final milestone it settles into a content state.
struct MilestoneDonut: View {
    let freeForSec: TimeInterval

    /// Gentle time markers, not trophies — a day, a week, a month, onward.
    static let milestones: [TimeInterval] = [
        86_400, 3 * 86_400, 7 * 86_400, 14 * 86_400,
        30 * 86_400, 60 * 86_400, 90 * 86_400, 180 * 86_400, 365 * 86_400,
    ]

    private var lastPassed: TimeInterval { Self.milestones.last { freeForSec >= $0 } ?? 0 }
    private var next: TimeInterval? { Self.milestones.first { freeForSec < $0 } }

    private var progress: Double {
        guard let next else { return 1 }
        let lo = lastPassed, hi = next
        guard hi > lo else { return 1 }
        return min(1, max(0, (freeForSec - lo) / (hi - lo)))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.driftInk.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.driftSageDeep, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                if let next {
                    VStack(spacing: 0) {
                        Text("next")
                            .font(.driftRowDescription)
                            .foregroundStyle(.driftInkSoft)
                        Text.caveat(formatDurationHuman(next))
                            .font(.driftCardTitle)
                            .foregroundStyle(.driftInk)
                    }
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.driftSageDeep)
                }
            }
            .frame(width: 150, height: 150)

            if let next {
                Text("\(formatGap(next - freeForSec)) to go")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            } else {
                Text("every milestone, drifted past")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
            }
        }
    }
}

/// "Longest drift" reference card — your best completed stretch with the dates
/// it spanned. Concrete (the live timer can't tell you this) and a number to
/// drift past. Mid-stretch it shows the previous best, since the record only
/// updates on the next logged hit.
struct LongestDriftCard: View {
    let gapSec: TimeInterval
    let from: Date?
    let to: Date?

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text.caveatLeading("longest drift")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInkSoft)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formatGap(gapSec))
                    .font(.driftBestNum)
                    .foregroundStyle(.driftInk)
                if let from, let to {
                    Text("\(Self.dateFmt.string(from: from)) → \(Self.dateFmt.string(from: to))")
                        .font(.driftBestLabel)
                        .foregroundStyle(.driftInkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }
}
