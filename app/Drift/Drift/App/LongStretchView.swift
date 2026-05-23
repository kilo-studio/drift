import SwiftUI

/// Pieces of the home screen's long-stretch mode (active when "free for" ≥ ~a
/// day). The screen reframes around the durable "free for X" timer + cards that
/// describe this stretch: the longest-drift record, the next time milestone
/// (progress donut), and the milestones reached so far this stretch.
///
/// Everything here is *derived from the current free-for duration* — achieved
/// milestones are simply `freeFor ≥ milestone`. On a logged hit free-for resets
/// to ~0 and the whole mode falls away, so nothing is shamefully "lost"; the
/// durable, never-erased record lives on the History → Records sheet. This
/// keeps it visualization-of-time, not a streak that punishes a bad day.

/// Gentle time markers — a day, a week, a month, onward. Shared by the home
/// milestone cards and the History records sheet.
let driftMilestones: [TimeInterval] = [
    86_400, 3 * 86_400, 7 * 86_400, 14 * 86_400,
    30 * 86_400, 60 * 86_400, 90 * 86_400, 180 * 86_400, 365 * 86_400,
]

let driftShortDate: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

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

            if let start = lastSessionEnd {
                Text("since \(driftShortDate.string(from: start))")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .padding(.top, 2)
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

/// "Longest drift" reference card. Label adapts: while you're under your record
/// it's the "all-time longest drift" (the bar above you); once the current
/// stretch passes it, the shown number is your "previous longest drift". Shows
/// the dates the record spanned — concrete, and a number to drift past.
struct LongestDriftCard: View {
    let gapSec: TimeInterval
    let from: Date?
    let to: Date?
    /// True once the current stretch has passed this record.
    let surpassed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text.caveatLeading(surpassed ? "previous longest drift" : "all-time longest drift")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInkSoft)

            Text(formatGap(gapSec))
                .font(.driftBestNum)
                .foregroundStyle(.driftInk)

            if let from, let to {
                Text("\(driftShortDate.string(from: from)) → \(driftShortDate.string(from: to))")
                    .font(.driftBestLabel)
                    .foregroundStyle(.driftInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }
}

/// Progress donut toward the next time milestone, in a card sized to sit beside
/// the longest-drift card. Fills across the current interval (last passed →
/// next marker). Past the final milestone it settles into a content check.
struct NextMilestoneCard: View {
    let freeForSec: TimeInterval

    private var lastPassed: TimeInterval { driftMilestones.last { freeForSec >= $0 } ?? 0 }
    private var next: TimeInterval? { driftMilestones.first { freeForSec < $0 } }
    private var progress: Double {
        guard let next else { return 1 }
        let lo = lastPassed
        guard next > lo else { return 1 }
        return min(1, max(0, (freeForSec - lo) / (next - lo)))
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.driftInk.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.driftSageDeep, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                if let next {
                    Text.caveat(formatDurationHuman(next))
                        .font(.driftCardTitle)
                        .foregroundStyle(.driftInk)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.driftSageDeep)
                }
            }
            .frame(width: 96, height: 96)

            if let next {
                VStack(spacing: 0) {
                    Text("next milestone")
                        .font(.driftSub)
                        .foregroundStyle(.driftInkSoft)
                    Text("\(formatGap(next - freeForSec)) to go")
                        .font(.driftRowDescription)
                        .foregroundStyle(.driftInk)
                }
            } else {
                Text("every milestone, drifted past")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .driftCard()
    }
}

/// Milestones reached *this stretch*, accumulating as you drift further. One
/// card with check rows (lighter than a card per milestone), most-recent on
/// top. Derived from free-for, so it grows live and clears when the stretch
/// ends. Renders nothing until the first milestone is reached.
struct MilestonesReachedCard: View {
    let freeForSec: TimeInterval

    private var reached: [TimeInterval] { driftMilestones.filter { freeForSec >= $0 } }

    var body: some View {
        if reached.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text.caveatLeading("milestones reached")
                    .font(.driftCardTitle)
                    .foregroundStyle(.driftInkSoft)
                    .padding(.bottom, 10)

                ForEach(Array(reached.reversed().enumerated()), id: \.offset) { idx, m in
                    if idx > 0 { SettingsDivider() }
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.driftSage).frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("\(formatDurationHuman(m)) free")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftInk)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .driftCard()
        }
    }
}
