import SwiftUI

/// Pieces of the home screen's long-stretch mode (active when "free for" ≥ ~a
/// day). Reframes around the durable "free for X" timer + cards describing this
/// stretch. Cards reuse `StatCard` / `driftCard()` so they stay in step with
/// the regular dashboard's card language.
///
/// Everything is *derived from the current free-for duration* — achieved
/// milestones are simply `freeFor ≥ milestone`. On a logged hit free-for resets
/// and the mode falls away, so nothing is shamefully "lost"; the durable record
/// lives on the History → Records sheet. Visualization-of-time, not a streak.

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

/// Big centered "free for X" timer — days + hours past a day, with the start date.
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

/// "Longest drift" record card — reuses `StatCard` so it matches the dashboard.
/// Label adapts: "all-time longest drift" while you're under it, "previous
/// longest drift" once the current stretch passes it. Dates sit in the label.
struct LongestDriftCard: View {
    let gapSec: TimeInterval
    let from: Date?
    let to: Date?
    let surpassed: Bool

    var body: some View {
        StatCard(
            title: surpassed ? "previous longest drift" : "all-time longest drift",
            bigNumberParts: formatElapsedLongParts(gapSec),
            bigNumberColor: .driftInk,
            label: datesLabel
        )
    }

    private var datesLabel: String {
        guard let from, let to else { return " " }
        return "\(driftShortDate.string(from: from)) → \(driftShortDate.string(from: to))"
    }
}

/// Progress donut toward the next time milestone, laid out to mirror `StatCard`
/// (centered title → content → label) so it sits flush beside the longest-drift
/// card at matching height.
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
        VStack(spacing: 0) {
            Text.caveat("next milestone")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .padding(.bottom, 10)

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
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.driftSageDeep)
                }
            }
            .frame(width: 92, height: 92)
            .padding(.bottom, 10)

            Text(next.map { "\(formatGap($0 - freeForSec)) to go" } ?? "all drifted past")
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .driftCard()
    }
}

/// Milestones reached *this stretch*, as a 2-column grid of green "blob" badges
/// — each milestone gets its own organic shape (seeded by its index) so they
/// feel distinct, with the duration in the middle. Derived from free-for, so it
/// grows live and clears when the stretch ends.
struct MilestonesReachedCard: View {
    let freeForSec: TimeInterval

    private var reached: [(index: Int, value: TimeInterval)] {
        driftMilestones.enumerated()
            .filter { freeForSec >= $0.element }
            .map { (index: $0.offset, value: $0.element) }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        if reached.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Text.caveat("milestones reached")
                    .font(.driftCardTitle)
                    .foregroundStyle(.driftInk)
                    .padding(.bottom, 16)

                LazyVGrid(columns: columns, spacing: 14) {
                    // Most recent (largest) first.
                    ForEach(reached.reversed(), id: \.index) { item in
                        MilestoneBadge(milestone: item.value, seed: item.index)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .driftCard()
        }
    }
}

/// A single milestone "badge": an organic green blob (shape seeded by the
/// milestone index, so each is subtly unique) with the duration centered on it.
struct MilestoneBadge: View {
    let milestone: TimeInterval
    let seed: Int

    var body: some View {
        ZStack {
            BlobShape(seed: seed)
                .fill(
                    LinearGradient(
                        colors: [Color.driftSage, Color.driftSageDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(formatDurationHuman(milestone))
                .font(.driftCardTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(height: 112)
    }
}

/// An organic closed blob. `seed` perturbs the per-vertex radius via layered
/// sines, so each milestone gets a distinct-but-coherent shape. Built as a
/// smooth curve through the midpoints of seeded vertices.
struct BlobShape: Shape {
    var seed: Int
    var vertices: Int = 8

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseR = min(rect.width, rect.height) / 2
        let s = Double(seed)

        func point(_ i: Int) -> CGPoint {
            let angle = Double(i) / Double(vertices) * 2 * .pi - .pi / 2
            let wobble = 0.12 * sin(angle * 2 + s * 1.3)
                       + 0.07 * sin(angle * 3 + s * 2.1 + 1)
                       + 0.05 * sin(angle * 5 + s * 0.7 + 2)
            let r = baseR * (0.86 + CGFloat(wobble))
            return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        }

        let pts = (0..<vertices).map(point)
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        var path = Path()
        path.move(to: mid(pts[vertices - 1], pts[0]))
        for i in 0..<vertices {
            let next = (i + 1) % vertices
            path.addQuadCurve(to: mid(pts[i], pts[next]), control: pts[i])
        }
        path.closeSubpath()
        return path
    }
}
