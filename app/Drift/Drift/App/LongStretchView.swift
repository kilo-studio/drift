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

/// Progress donut toward the next time milestone, full-width, laid out to
/// mirror `StatCard` (centered title → content → label).
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
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInk)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.driftSageDeep)
                }
            }
            .frame(width: 132, height: 132)
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
                        MilestoneBadge(milestone: item.value, index: item.index)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .driftCard()
        }
    }
}

/// A single milestone "badge": a rounded regular polygon whose side count grows
/// with the milestone (1 day = rounded square → 1 year ≈ 12-gon, nearly round),
/// so a longer drift visibly earns a more elaborate, "more complete" medallion.
/// Green fill + a soft darker stroke so it reads as a struck badge; duration
/// centered on it.
struct MilestoneBadge: View {
    let milestone: TimeInterval
    let index: Int

    /// 1 day → 4 sides, climbing one per milestone toward a near-circle. High-
    /// side polygons converge visually, so magnitude is *also* encoded as a
    /// deepening green (short = light sage, long = deep forest) — the two
    /// signals together keep every badge distinct.
    private var sides: Int { index + 4 }
    private var t: Double {
        let total = driftMilestones.count
        return total > 1 ? Double(index) / Double(total - 1) : 0
    }

    var body: some View {
        ZStack {
            let shape = RoundedPolygon(sides: sides)
            shape.fill(
                LinearGradient(
                    colors: [
                        lerpRGB((0.659, 0.737, 0.576), (0.36, 0.46, 0.31), t),   // sage → forest (top)
                        lerpRGB((0.494, 0.580, 0.463), (0.22, 0.31, 0.20), t),   // sageDeep → deep forest (bottom)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.stroke(.white.opacity(0.25), lineWidth: 1.5)

            Text(formatDurationHuman(milestone))
                .font(.driftCardTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(height: 116)
    }

    private func lerpRGB(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
}

/// A regular polygon with softly rounded corners (radially symmetric). More
/// `sides` = rounder, so milestone magnitude reads as shape complexity.
struct RoundedPolygon: Shape {
    var sides: Int
    /// Fraction of each edge taken up by the corner round (0 = sharp, ~0.5 = max).
    var cornerFraction: CGFloat = 0.4

    func path(in rect: CGRect) -> Path {
        let n = max(3, sides)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let verts = (0..<n).map { i -> CGPoint in
            let a = Double(i) / Double(n) * 2 * .pi - .pi / 2   // first vertex at top
            return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        }

        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        var path = Path()
        for i in 0..<n {
            let curr = verts[i]
            let prev = verts[(i - 1 + n) % n]
            let next = verts[(i + 1) % n]
            let entering = lerp(curr, prev, cornerFraction)
            let leaving = lerp(curr, next, cornerFraction)
            if i == 0 { path.move(to: entering) } else { path.addLine(to: entering) }
            path.addQuadCurve(to: leaving, control: curr)
        }
        path.closeSubpath()
        return path
    }
}
