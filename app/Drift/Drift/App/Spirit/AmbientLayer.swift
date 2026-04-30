import SwiftUI

/// Atmospheric layer behind the dashboard. Light mode: two slow-drifting cream
/// clouds (matches prototype). Dark mode: a sparse field of tiny twinkling stars
/// plus one subtle dark cloud. Sized to fill its parent and ignores safe area.
struct AmbientLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                Canvas { gc, size in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    if colorScheme == .dark {
                        drawDarkCloud(gc: gc, size: size, time: t)
                        drawStars(gc: gc, size: size, time: t)
                    } else {
                        drawLightClouds(gc: gc, size: size, time: t)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Clouds

private struct CloudShape {
    let ellipses: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)]
    let bbox: CGSize
    let driftSeconds: Double
    let driftAmplitude: CGSize
}

/// Prototype's cloud-1 (220×90 viewBox), scaled to pt directly.
private let cloud1 = CloudShape(
    ellipses: [
        (55, 58, 42, 22),
        (105, 42, 55, 30),
        (160, 55, 48, 26),
        (85, 62, 28, 14),
        (135, 60, 30, 14),
    ],
    bbox: CGSize(width: 220, height: 90),
    driftSeconds: 60,
    driftAmplitude: CGSize(width: 40, height: -8)
)

private let cloud2 = CloudShape(
    ellipses: [
        (50, 50, 38, 20),
        (100, 38, 50, 26),
        (150, 48, 42, 22),
        (120, 55, 26, 13),
    ],
    bbox: CGSize(width: 200, height: 80),
    driftSeconds: 75,
    driftAmplitude: CGSize(width: -50, height: 6)
)

private func drawLightClouds(gc: GraphicsContext, size: CGSize, time: Double) {
    let fill = Gradient(stops: [
        .init(color: Color.white,                                       location: 0),
        .init(color: Color(red: 251/255, green: 246/255, blue: 238/255).opacity(0.95), location: 0.65),
        .init(color: Color(red: 242/255, green: 224/255, blue: 206/255).opacity(0.75), location: 1),
    ])

    // cloud-1: anchored top: 420, left: -30
    drawCloud(cloud1,
              originX: -30,
              originY: 420,
              fill: fill,
              opacity: 0.85,
              gc: gc,
              time: time)

    // cloud-2: anchored top: 240, right: -40 (so x = size.width - cloudW + 40)
    drawCloud(cloud2,
              originX: size.width - cloud2.bbox.width + 40,
              originY: 240,
              fill: fill,
              opacity: 0.85,
              gc: gc,
              time: time)
}

private func drawDarkCloud(gc: GraphicsContext, size: CGSize, time: Double) {
    let fill = Gradient(stops: [
        .init(color: Color(red: 80/255, green: 95/255, blue: 110/255).opacity(0.55), location: 0),
        .init(color: Color(red: 50/255, green: 65/255, blue: 80/255).opacity(0.40), location: 0.65),
        .init(color: Color(red: 30/255, green: 40/255, blue: 55/255).opacity(0.20), location: 1),
    ])
    // One slow, low-opacity cloud per the user spec.
    drawCloud(cloud2,
              originX: -40,
              originY: 320,
              fill: fill,
              opacity: 1,
              gc: gc,
              time: time)
}

private func drawCloud(
    _ cloud: CloudShape,
    originX: CGFloat,
    originY: CGFloat,
    fill: Gradient,
    opacity: Double,
    gc: GraphicsContext,
    time: Double
) {
    // 0..1 phase across one full drift period; sin gives -1..1.
    let phase = sin((time / cloud.driftSeconds) * 2 * .pi)
    let dx = cloud.driftAmplitude.width * phase
    let dy = cloud.driftAmplitude.height * phase

    var ctx = gc
    ctx.opacity = opacity
    // Soft blur to match the prototype's feGaussianBlur stdDeviation=2.5
    ctx.addFilter(.blur(radius: 2.5))
    ctx.translateBy(x: originX + dx, y: originY + dy)

    // Single radial gradient anchored at (45%, 35%) of the cloud's bbox — same as
    // prototype. We approximate by filling each ellipse with a radial gradient
    // centered at the cloud bbox anchor, scaled to the largest ellipse radius.
    let anchor = CGPoint(x: cloud.bbox.width * 0.45, y: cloud.bbox.height * 0.35)
    let endRadius = max(cloud.bbox.width, cloud.bbox.height) * 0.7

    for e in cloud.ellipses {
        let rect = CGRect(x: e.cx - e.rx, y: e.cy - e.ry, width: e.rx * 2, height: e.ry * 2)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(fill, center: anchor, startRadius: 0, endRadius: endRadius)
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

private let stars: [Star] = makeStars(count: 70)

private func makeStars(count: Int) -> [Star] {
    var rng = SystemRandomNumberGenerator()
    var result: [Star] = []
    result.reserveCapacity(count)
    for _ in 0..<count {
        result.append(Star(
            xPct: Double.random(in: 0...100, using: &rng),
            yPct: Double.random(in: 0...100, using: &rng),
            // Mostly tiny pinpricks, occasional brighter star
            size: Double.random(in: 0...1, using: &rng) < 0.85
                ? Double.random(in: 1.0...2.2, using: &rng)
                : Double.random(in: 2.4...3.6, using: &rng),
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
        // 0.4..1.0 opacity oscillation
        let opacity = 0.7 + sin(phase) * 0.3
        var ctx = gc
        ctx.opacity = opacity
        let cx = (s.xPct / 100) * size.width
        let cy = (s.yPct / 100) * size.height
        let rect = CGRect(x: cx - s.size, y: cy - s.size, width: s.size * 2, height: s.size * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(starFill))
    }
}
