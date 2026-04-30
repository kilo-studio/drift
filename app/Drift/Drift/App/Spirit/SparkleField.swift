import SwiftUI

/// 200-particle viewport-fill halo. Each sparkle has a `revealAt` threshold along
/// a power curve so the closest sparkles unlock around ratio ≥ 1× (just past your
/// average) and the farthest unlock around ratio ≥ 20× (extreme territory).
/// Drift + twinkle animate continuously via a single Canvas inside TimelineView.
enum SparkleLayer {
    /// Behind the cards. Full count + size so the spirit halo reads cleanly.
    case back
    /// In front of the cards. Smaller, sparser, slightly translucent — adds
    /// depth without obscuring readable content.
    case front
}

struct SparkleField: View {
    let lastSessionEnd: Date?
    let wakingAvgSec: TimeInterval?

    /// Spirit center in viewport percentage coords (0–100). Sparkles are sorted by
    /// distance from this point, so the halo grows out from the spirit.
    let spiritPercent: CGPoint

    let layer: SparkleLayer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sparkles: [Sparkle]

    init(
        lastSessionEnd: Date?,
        wakingAvgSec: TimeInterval?,
        layer: SparkleLayer = .back,
        spiritPercent: CGPoint = CGPoint(x: 78, y: 14)
    ) {
        self.lastSessionEnd = lastSessionEnd
        self.wakingAvgSec = wakingAvgSec
        self.spiritPercent = spiritPercent
        self.layer = layer
        self._sparkles = State(initialValue: makeSparkles(layer: layer, spiritPercent: spiritPercent))
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                Canvas { gc, size in
                    guard !sparkles.isEmpty else { return }
                    let now = ctx.date
                    let elapsed = now.timeIntervalSinceReferenceDate
                    let ratio = currentRatio(now: now)
                    for s in sparkles {
                        guard ratio >= s.revealAt else { continue }
                        drawSparkle(s, in: gc, size: size, time: elapsed)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func currentRatio(now: Date) -> Double {
        let secSince = lastSessionEnd.map { now.timeIntervalSince($0) } ?? 0
        let avg = wakingAvgSec ?? 0
        return avg > 0 ? max(0.001, secSince / avg) : 1.0
    }

    private func drawSparkle(_ s: Sparkle, in ctx: GraphicsContext, size: CGSize, time: Double) {
        let (drift, opacity) = animState(for: s, time: time)
        let cx = (s.xPct / 100) * size.width + drift.x
        let cy = (s.yPct / 100) * size.height + drift.y

        var ctx = ctx
        ctx.translateBy(x: cx, y: cy)
        ctx.opacity = opacity
        ctx.fill(starPath(radius: s.size / 2), with: .color(s.color))
    }

    private func animState(for s: Sparkle, time: Double) -> (drift: CGPoint, opacity: Double) {
        if reduceMotion {
            return (.zero, 1)
        }
        let driftPhase = (time / s.driftDuration + s.driftPhase) * 2 * .pi
        let twinklePhase = (time / s.twinkleDuration + s.twinklePhase) * 2 * .pi
        let drift = CGPoint(
            x: sin(driftPhase) * s.driftAmplitude.x,
            y: cos(driftPhase) * s.driftAmplitude.y
        )
        // sin → -1..1, mapped to 0.35..1
        let opacity = 0.675 + sin(twinklePhase) * 0.325
        return (drift, opacity)
    }
}

// MARK: - Sparkle data

private struct Sparkle {
    let xPct: Double           // 0..100
    let yPct: Double           // 0..100
    let revealAt: Double
    let size: Double           // pt
    let driftAmplitude: CGPoint
    let driftDuration: Double
    let driftPhase: Double     // 0..1
    let twinkleDuration: Double
    let twinklePhase: Double   // 0..1
    let color: Color
}

// Warm palette weighted toward the coral/peach end so sparkles read against both
// light blue and deep navy. Ordering matters here: random pick is uniform, so the
// peachier entries appear ~3/5 of the time, leaving enough gold accents for warmth.
private let palette: [Color] = [
    Color(hex: 0xE8836B),  // driftCoral
    Color(hex: 0xF4B393),  // driftPeach
    Color(hex: 0xF0A07C),  // peach-coral mid
    Color(hex: 0xE8B86B),  // warm gold
    Color(hex: 0xFFD08C),  // light gold accent
]

private func makeSparkles(layer: SparkleLayer, spiritPercent: CGPoint) -> [Sparkle] {
    let total: Int
    let sizeRange: (small: ClosedRange<Double>, large: ClosedRange<Double>)
    switch layer {
    case .back:
        total = 200
        sizeRange = (6...10, 10...16)
    case .front:
        // Always-visible decorative atmosphere — sparser + smaller than the back
        // halo, but not ratio-gated so they shimmer continuously over the cards.
        total = 50
        sizeRange = (3...5, 5...7)
    }
    var generator = SystemRandomNumberGenerator()

    struct Raw {
        let x: Double
        let y: Double
        let dist: Double
    }

    // 1. Random positions across the viewport.
    var raws: [Raw] = []
    raws.reserveCapacity(total)
    for _ in 0..<total {
        let x = Double.random(in: 0...100, using: &generator)
        let y = Double.random(in: 0...100, using: &generator)
        let dx = x - spiritPercent.x
        // Weight vertical distance more lightly so the halo doesn't only fill
        // horizontally first when the viewport is taller than wide.
        let dy = (y - spiritPercent.y) * 0.85
        raws.append(Raw(x: x, y: y, dist: hypot(dx, dy)))
    }

    // 2. Closest-to-spirit first.
    raws.sort { $0.dist < $1.dist }

    // 3. revealAt power curve. Front layer is decorative — always visible
    //    regardless of ratio, so set revealAt = 0 there.
    return raws.enumerated().map { (i, p) in
        let revealAt: Double = layer == .front
            ? 0
            : 1 + pow(Double(i) / Double(total - 1), 1.5) * 19
        let big = Double.random(in: 0...1, using: &generator) < 0.18
        let size = big
            ? Double.random(in: sizeRange.large, using: &generator)
            : Double.random(in: sizeRange.small, using: &generator)
        let driftAmp = CGPoint(
            x: Double.random(in: -15...15, using: &generator),
            y: Double.random(in: -15...15, using: &generator)
        )
        let driftDur = 4.5 + Double.random(in: 0...5, using: &generator)
        let twinkleDur = 2.4 + Double.random(in: 0...1.6, using: &generator)
        return Sparkle(
            xPct: p.x,
            yPct: p.y,
            revealAt: revealAt,
            size: size,
            driftAmplitude: driftAmp,
            driftDuration: driftDur,
            driftPhase: Double.random(in: 0...1, using: &generator),
            twinkleDuration: twinkleDur,
            twinklePhase: Double.random(in: 0...1, using: &generator),
            color: palette.randomElement(using: &generator)!
        )
    }
}

// MARK: - Star path

/// 4-point star matching the prototype's path: tight inner radius (0.23 × outer)
/// gives the pinched-corner look.
private func starPath(radius r: CGFloat) -> Path {
    let inner = r * 0.23
    var p = Path()
    p.move(to: CGPoint(x: 0, y: -r))
    p.addLine(to: CGPoint(x: inner, y: -inner))
    p.addLine(to: CGPoint(x: r, y: 0))
    p.addLine(to: CGPoint(x: inner, y: inner))
    p.addLine(to: CGPoint(x: 0, y: r))
    p.addLine(to: CGPoint(x: -inner, y: inner))
    p.addLine(to: CGPoint(x: -r, y: 0))
    p.addLine(to: CGPoint(x: -inner, y: -inner))
    p.closeSubpath()
    return p
}
