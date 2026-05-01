import SwiftUI

/// The cloud spirit — the visual centerpiece. ViewBox 100×100, drawn in a 96×96 Canvas
/// inside a TimelineView(.animation) so float / blink / milestone state recompute every
/// frame. Eye radius is logarithmically driven by `ratio` (time-since-last-session over
/// rolling waking-gap average) and bottom-anchored at y=52.9 so eyes only grow upward.
struct SpiritView: View {
    let lastSessionEnd: Date?
    let wakingAvgSec: TimeInterval?
    let longestWakingGapSec: TimeInterval
    let longestGapSec: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // ~30fps — the float curve and blink don't benefit from 120Hz updates
        // and keeping it low keeps the device from heating up when the spirit
        // is rendered globally across both tabs.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let frame = SpiritFrame(
                now: context.date,
                lastSessionEnd: lastSessionEnd,
                wakingAvgSec: wakingAvgSec,
                longestWakingGapSec: longestWakingGapSec,
                longestGapSec: longestGapSec,
                reduceMotion: reduceMotion
            )

            Canvas { ctx, size in
                drawSpirit(ctx: ctx, size: size, frame: frame)
            }
            .frame(width: 96, height: 96)
        }
    }
}

// MARK: - Per-frame snapshot

private struct SpiritFrame {
    let ratio: Double
    let wakingActive: Bool
    let overallActive: Bool
    let elapsed: Double
    let floatY: Double
    let reduceMotion: Bool

    init(
        now: Date,
        lastSessionEnd: Date?,
        wakingAvgSec: TimeInterval?,
        longestWakingGapSec: TimeInterval,
        longestGapSec: TimeInterval,
        reduceMotion: Bool
    ) {
        let secSince = lastSessionEnd.map { now.timeIntervalSince($0) } ?? 0
        let avg = wakingAvgSec ?? 0
        let r = avg > 0 ? max(0.001, secSince / avg) : 1.0
        let wA = longestWakingGapSec > 0 && secSince >= longestWakingGapSec
        let oA = longestGapSec > 0 && secSince >= longestGapSec
        let e = now.timeIntervalSinceReferenceDate

        let amplitude: Double
        let period: Double
        if reduceMotion {
            amplitude = 0
            period = 0
        } else if oA {
            amplitude = 4   // wobble at overall — visually softer than waking
            period = 3.0
        } else if wA {
            amplitude = 5
            period = 3.6
        } else {
            amplitude = 3
            period = 5.0
        }

        self.ratio = r
        self.wakingActive = wA
        self.overallActive = oA
        self.elapsed = e
        self.reduceMotion = reduceMotion
        self.floatY = period > 0 ? sin(e * 2 * .pi / period) * amplitude : 0
    }

    /// Eyes blink in unison every ~6.5s; right eye is offset by 0.04s for life.
    func isBlinking(offset: Double) -> Bool {
        guard !reduceMotion else { return false }
        let phase = (elapsed - offset).truncatingRemainder(dividingBy: 6.5)
        return phase >= 0 && phase < 0.1
    }
}

// MARK: - Drawing

private let pupilColor = Color(hex: 0x3A332C)
private let shineColor = Color(hex: 0xFAF3E7)
private let cheekBase = Color(hex: 0xF4B393)

private func drawSpirit(ctx: GraphicsContext, size: CGSize, frame: SpiritFrame) {
    var ctx = ctx
    let scale = size.width / 100
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: frame.floatY)

    drawSideWisps(ctx: &ctx)
    drawBody(ctx: &ctx)
    drawCheeks(ctx: &ctx, frame: frame)
    drawEyes(ctx: &ctx, frame: frame)
    drawSmile(ctx: &ctx)
}

private func drawSideWisps(ctx: inout GraphicsContext) {
    let gradient = bodyGradient
    for cx in [14.0, 86.0] {
        let path = Path(ellipseIn: CGRect(x: cx - 9, y: 58 - 6.5, width: 18, height: 13))
        ctx.opacity = 0.7
        ctx.fill(path, with: .radialGradient(
            gradient,
            center: CGPoint(x: cx - 9 + 6.84, y: 58 - 6.5 + 4.16),
            startRadius: 0,
            endRadius: 18
        ))
    }
    ctx.opacity = 1.0
}

private func drawBody(ctx: inout GraphicsContext) {
    let body = Path(ellipseIn: CGRect(x: 16, y: 22, width: 68, height: 60))
    // Radial gradient center at 38%/32% of bbox: (16+25.84, 22+19.2) ≈ (42, 41)
    ctx.fill(body, with: .radialGradient(
        bodyGradient,
        center: CGPoint(x: 42, y: 41),
        startRadius: 0,
        endRadius: 50
    ))
}

private var bodyGradient: Gradient {
    Gradient(stops: [
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0xFBF5EC), location: 0.65),
        .init(color: Color(hex: 0xEDDFC8), location: 1.0),
    ])
}

private func drawCheeks(ctx: inout GraphicsContext, frame: SpiritFrame) {
    let (color, opacity): (Color, Double)
    if frame.overallActive {
        color = Color.driftCoral
        opacity = 0.85
    } else if frame.wakingActive {
        color = cheekBase
        opacity = 0.7
    } else {
        color = cheekBase
        opacity = 0.45
    }
    for cx in [34.0, 66.0] {
        let path = Path(ellipseIn: CGRect(x: cx - 5.5, y: 58 - 3.5, width: 11, height: 7))
        ctx.fill(path, with: .color(color.opacity(opacity)))
    }
}

private func drawEyes(ctx: inout GraphicsContext, frame: SpiritFrame) {
    let lr = log(max(0.001, frame.ratio))
    let pupilR = min(8.0, max(2.4, 2.4 + lr * 2.5))
    let pupilCy = 52.9 - pupilR
    let shineR = pupilR * 0.27
    let shineCy = 52.9 - pupilR * 1.375

    let eyes: [(cx: Double, blinkOffset: Double)] = [
        (42, 0),
        (58, 0.04),
    ]

    for eye in eyes {
        let blinking = frame.isBlinking(offset: eye.blinkOffset)
        let pupilRy = blinking ? pupilR * 0.12 : pupilR

        let pupil = Path(ellipseIn: CGRect(
            x: eye.cx - pupilR,
            y: pupilCy - pupilRy,
            width: pupilR * 2,
            height: pupilRy * 2
        ))
        ctx.fill(pupil, with: .color(pupilColor))

        if !blinking {
            let shine = Path(ellipseIn: CGRect(
                x: eye.cx + 0.7 - shineR,
                y: shineCy - shineR,
                width: shineR * 2,
                height: shineR * 2
            ))
            ctx.fill(shine, with: .color(shineColor.opacity(0.9)))
        }
    }
}

private func drawSmile(ctx: inout GraphicsContext) {
    var smile = Path()
    smile.move(to: CGPoint(x: 47.5, y: 58.5))
    smile.addQuadCurve(to: CGPoint(x: 52.5, y: 58.5), control: CGPoint(x: 50, y: 60.5))
    ctx.stroke(
        smile,
        with: .color(pupilColor),
        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
    )
}
