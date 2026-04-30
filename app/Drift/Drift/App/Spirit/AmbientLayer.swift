import SwiftUI

/// Atmospheric layer behind the dashboard. A pool of cloud "tracks" each drift
/// fully right→left across the screen on their own period and phase, so 0–3 are
/// usually visible. Light mode = cream clouds; dark mode = dark silhouettes plus
/// ~150 tiny twinkling stars.
struct AmbientLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                Canvas { gc, size in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    if colorScheme == .dark {
                        // Stars first so clouds occlude any they pass over.
                        drawStars(gc: gc, size: size, time: t)
                        drawDriftingClouds(gc: gc, size: size, time: t, fill: darkCloudFill)
                    } else {
                        drawDriftingClouds(gc: gc, size: size, time: t, fill: lightCloudFill)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Cloud shapes

private struct CloudShape {
    let ellipses: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)]
    let bbox: CGSize
}

/// Prototype's cloud-1 — a wider, lumpier blob (220×90 viewBox).
private let cloud1 = CloudShape(
    ellipses: [
        (55, 58, 42, 22),
        (105, 42, 55, 30),
        (160, 55, 48, 26),
        (85, 62, 28, 14),
        (135, 60, 30, 14),
    ],
    bbox: CGSize(width: 220, height: 90)
)

/// Prototype's cloud-2 — narrower with one tall central peak (200×80 viewBox).
private let cloud2 = CloudShape(
    ellipses: [
        (50, 50, 38, 20),
        (100, 38, 50, 26),
        (150, 48, 42, 22),
        (120, 55, 26, 13),
    ],
    bbox: CGSize(width: 200, height: 80)
)

/// A third variant — smaller, three-bump cloud for variety.
private let cloud3 = CloudShape(
    ellipses: [
        (40, 38, 32, 18),
        (80, 30, 40, 22),
        (120, 38, 35, 18),
    ],
    bbox: CGSize(width: 160, height: 60)
)

// MARK: - Tracks

/// One drifting cloud's stable parameters. Position is derived per frame from
/// `(time + phaseOffset) mod period`.
private struct CloudTrack {
    let shape: CloudShape
    let yPos: CGFloat       // top edge of cloud bbox in pt
    let scale: CGFloat
    let period: Double      // seconds for one full off-right → off-left cycle
    let phaseOffset: Double // seconds; staggers when the cloud first appears
}

/// Mix of widths, scales, vertical positions, periods, and phase offsets so the
/// sky has variety and a realistic 0–3 visible at any time. Periods 90–160s give
/// genuinely slow drift; phase offsets are spread so they don't cluster.
private let cloudTracks: [CloudTrack] = [
    CloudTrack(shape: cloud1, yPos: 70,  scale: 1.0,  period: 110, phaseOffset: 0),
    CloudTrack(shape: cloud2, yPos: 240, scale: 0.85, period: 145, phaseOffset: 55),
    CloudTrack(shape: cloud3, yPos: 140, scale: 1.1,  period: 95,  phaseOffset: 130),
    CloudTrack(shape: cloud2, yPos: 50,  scale: 0.7,  period: 165, phaseOffset: 220),
    CloudTrack(shape: cloud1, yPos: 320, scale: 0.65, period: 125, phaseOffset: 80),
    CloudTrack(shape: cloud3, yPos: 180, scale: 0.55, period: 100, phaseOffset: 290),
]

// MARK: - Cloud fills

private let lightCloudFill = Gradient(stops: [
    .init(color: Color.white,                                                     location: 0),
    .init(color: Color(red: 251/255, green: 246/255, blue: 238/255).opacity(0.95), location: 0.65),
    .init(color: Color(red: 242/255, green: 224/255, blue: 206/255).opacity(0.75), location: 1),
])

/// Bg navy is roughly rgb(15, 26, 36). For "dark cloud" silhouettes we go DARKER
/// than the sky so they read as occluding mass.
private let darkCloudFill = Gradient(stops: [
    .init(color: Color(red: 6/255, green: 12/255, blue: 20/255).opacity(0.95), location: 0),
    .init(color: Color(red: 4/255, green: 8/255,  blue: 15/255).opacity(0.85), location: 0.65),
    .init(color: Color(red: 2/255, green: 5/255,  blue: 10/255).opacity(0.55), location: 1),
])

// MARK: - Drift drawing

private func drawDriftingClouds(gc: GraphicsContext, size: CGSize, time: Double, fill: Gradient) {
    for track in cloudTracks {
        drawTrack(track, gc: gc, size: size, time: time, fill: fill)
    }
}

private func drawTrack(
    _ track: CloudTrack,
    gc: GraphicsContext,
    size: CGSize,
    time: Double,
    fill: Gradient
) {
    let cloudWidth = track.shape.bbox.width * track.scale
    // Total travel distance: from off-right (cloud's left edge at size.width) to
    // off-left (cloud's right edge at 0), with a buffer so it briefly disappears
    // before respawning rather than wrapping instantly.
    let travelDistance = size.width + cloudWidth + 80
    let phase = ((time + track.phaseOffset) / track.period).truncatingRemainder(dividingBy: 1)
    // x = right offscreen → left offscreen
    let originX = size.width + 40 - phase * travelDistance

    var ctx = gc
    // Slightly per-track opacity variation so they don't feel uniform.
    ctx.opacity = 0.78 + Double(track.scale.truncatingRemainder(dividingBy: 0.3))
    ctx.addFilter(.blur(radius: 5 * track.scale))
    ctx.translateBy(x: originX, y: track.yPos)
    ctx.scaleBy(x: track.scale, y: track.scale)

    // Per-ellipse radial gradient (matches SVG objectBoundingBox semantics).
    for e in track.shape.ellipses {
        let rect = CGRect(x: e.cx - e.rx, y: e.cy - e.ry, width: e.rx * 2, height: e.ry * 2)
        let center = CGPoint(x: e.cx - e.rx + e.rx * 2 * 0.45,
                             y: e.cy - e.ry + e.ry * 2 * 0.35)
        let endRadius = max(e.rx, e.ry)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(fill, center: center, startRadius: 0, endRadius: endRadius)
        )
    }
}

// MARK: - Stars (dark mode)

private struct Star {
    let xPct: Double
    let yPct: Double
    let size: Double
    let twinkleDuration: Double
    let twinklePhase: Double
}

private let stars: [Star] = makeStars(count: 150)

private func makeStars(count: Int) -> [Star] {
    var rng = SystemRandomNumberGenerator()
    var result: [Star] = []
    result.reserveCapacity(count)
    for _ in 0..<count {
        result.append(Star(
            xPct: Double.random(in: 0...100, using: &rng),
            yPct: Double.random(in: 0...100, using: &rng),
            size: Double.random(in: 0...1, using: &rng) < 0.85
                ? Double.random(in: 0.4...0.9, using: &rng)
                : Double.random(in: 1.0...1.5, using: &rng),
            twinkleDuration: 2.0 + Double.random(in: 0...3, using: &rng),
            twinklePhase: Double.random(in: 0...1, using: &rng)
        ))
    }
    return result
}

private func drawStars(gc: GraphicsContext, size: CGSize, time: Double) {
    let starFill = Color(red: 240/255, green: 232/255, blue: 213/255)
    for s in stars {
        let phase = (time / s.twinkleDuration + s.twinklePhase) * 2 * .pi
        let opacity = 0.7 + sin(phase) * 0.3
        var ctx = gc
        ctx.opacity = opacity
        let cx = (s.xPct / 100) * size.width
        let cy = (s.yPct / 100) * size.height
        let rect = CGRect(x: cx - s.size, y: cy - s.size, width: s.size * 2, height: s.size * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(starFill))
    }
}
