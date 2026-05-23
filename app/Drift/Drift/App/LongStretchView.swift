import SwiftUI

/// Pieces of the home screen's long-stretch mode (active when "free for" ≥ ~a
/// day). This mode reframes the screen around the one metric that stays
/// meaningful at this scale — the "free for X" timer — plus a longest-yet
/// record line and a gentle milestone trail. The frequency cards/charts are
/// intentionally absent (they go to zero/stale); see `HomeView`'s mode branch.
///
/// Philosophy: "free for X" and "your longest drift" are *visualization* — they
/// describe time and persisted data, never judge you. No "quit", no streaks
/// that reset, no badges. The record survives a relapse; the trail reads as a
/// journey, not a trophy shelf.

/// Big centered "free for X" timer that scales hours → days → weeks → months.
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
                    Text(s)
                        .font(.driftDisplay)
                        .tracking(-1.5)
                        .foregroundStyle(.driftInk)
                case .unit(let s):
                    Text(s)
                        .font(.driftTimerUnit)
                        .foregroundStyle(.driftInkSoft)
                }
            }
        }
    }
}

/// "Your longest drift" reference line. When the current stretch passes the
/// all-time record it shifts — softly, in word + color, never with a trophy or
/// "!" — to "a new longest drift", showing the live value. The crossing is
/// computed live (the persisted record only bumps on the next logged hit), so
/// the user watches themselves pass their own record in real time.
struct LongStretchRecord: View {
    let freeForSec: TimeInterval
    let longestGapSec: TimeInterval

    private var surpassed: Bool { longestGapSec > 0 && freeForSec > longestGapSec }

    var body: some View {
        Group {
            if longestGapSec <= 0 {
                // No record yet (e.g. baseline skipped with little data) — the
                // live timer above is implicitly the longest so far.
                Text("your longest drift, so far")
                    .font(.driftBestLabel)
                    .foregroundStyle(.driftInkSoft)
            } else if surpassed {
                recordLine(value: freeForSec, label: "a new longest drift", color: .driftSageDeep)
            } else {
                recordLine(value: longestGapSec, label: "your longest drift", color: .driftInk)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: surpassed)
    }

    private func recordLine(value: TimeInterval, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(formatDurationHuman(value))
                .font(.driftBestNum)
                .foregroundStyle(color)
            Text(label)
                .font(.driftBestLabel)
                .foregroundStyle(label == "a new longest drift" ? .driftSageDeep : .driftInkSoft)
        }
    }
}

/// A soft trail of milestones (1 day → 1 year). Passed markers are lit; the
/// next one ahead sits dim on the horizon. A windowed slice keeps it gentle and
/// uncluttered for very long drifts. Reads as a journey, not a trophy shelf.
struct MilestoneTrail: View {
    let freeForSec: TimeInterval

    private static let milestones: [TimeInterval] = [
        86_400,        // 1 day
        3 * 86_400,    // 3 days
        7 * 86_400,    // 1 week
        14 * 86_400,   // 2 weeks
        30 * 86_400,   // 1 month
        60 * 86_400,   // 2 months
        90 * 86_400,   // 3 months
        180 * 86_400,  // 6 months
        365 * 86_400,  // 1 year
    ]

    var body: some View {
        // Show the last two passed + the next two ahead, so the trail always
        // frames "where you are" without listing the whole ladder.
        let passed = Self.milestones.filter { freeForSec >= $0 }.count
        let lower = max(0, passed - 2)
        let upper = min(Self.milestones.count, max(passed + 2, lower + 4))
        let slice = Array(Self.milestones.enumerated())[lower..<min(upper, Self.milestones.count)]

        ZStack(alignment: .top) {
            // Faint connecting path behind the markers (single fill layer).
            Capsule()
                .fill(Color.driftInkFade.opacity(0.2))
                .frame(height: 2)
                .padding(.horizontal, 28)
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 0) {
                ForEach(slice, id: \.offset) { _, m in
                    marker(m)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func marker(_ m: TimeInterval) -> some View {
        let isPassed = freeForSec >= m
        return VStack(spacing: 6) {
            Circle()
                .fill(isPassed ? Color.driftSage : Color.driftInkFade.opacity(0.35))
                .frame(width: isPassed ? 13 : 10, height: isPassed ? 13 : 10)
            Text(formatDurationHuman(m))
                .font(.driftSub)
                .foregroundStyle(isPassed ? .driftInk : .driftInkFade)
        }
    }
}
