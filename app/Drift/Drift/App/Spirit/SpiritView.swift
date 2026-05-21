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
    /// Suppress the state-driven float amplitude/period change at record
    /// thresholds. Used in onboarding's spirit-preview where the ratio cycles
    /// through thresholds repeatedly — without this, the sin-wave frequency
    /// shifts every crossing and the spirit visibly "jumps" because the wave's
    /// value at that moment changes discontinuously. Cheek color still
    /// transitions at thresholds; only the float behavior is stabilized.
    var stableFloat: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// When `lastSessionEnd` jumps forward (hit logged / interval closed), the
    /// raw ratio drops to ~0 instantly and the spirit pops back to baseline in
    /// a single frame. To smooth that, we capture the ratio at the moment of
    /// the reset and ease-out blend down to the new real ratio over 1.5s.
    @State private var snapStartedAt: Date? = nil
    @State private var preSnapRatio: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            let frame = SpiritFrame(
                now: context.date,
                lastSessionEnd: lastSessionEnd,
                wakingAvgSec: wakingAvgSec,
                longestWakingGapSec: longestWakingGapSec,
                longestGapSec: longestGapSec,
                reduceMotion: reduceMotion,
                stableFloat: stableFloat,
                snapStartedAt: snapStartedAt,
                preSnapRatio: preSnapRatio
            )

            Canvas { ctx, size in
                drawSpirit(ctx: ctx, size: size, frame: frame)
            }
            .frame(width: 96, height: 96)
        }
        .onChange(of: lastSessionEnd) { oldValue, newValue in
            // Trigger on either a forward jump (anchor moved later — hit
            // logged) or anchor cleared. Both read as "reset to baseline."
            // Backward edits (e.g. editing a hit to be earlier) shouldn't.
            guard !reduceMotion, let old = oldValue else { return }
            if let new = newValue, new <= old { return }
            let avg = wakingAvgSec ?? 0
            let now = Date.now
            preSnapRatio = avg > 0 ? now.timeIntervalSince(old) / avg : 0
            snapStartedAt = now
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
        reduceMotion: Bool,
        stableFloat: Bool,
        snapStartedAt: Date?,
        preSnapRatio: Double
    ) {
        let secSince = lastSessionEnd.map { now.timeIntervalSince($0) } ?? 0
        let avg = wakingAvgSec ?? 0
        let realRatio = avg > 0 ? max(0.001, secSince / avg) : 1.0

        // If a reset just happened, blend from the pre-snap ratio down to
        // the real ratio over ~1.5s using ease-out cubic. After the window
        // we're on the real ratio.
        let r: Double
        if let snapStart = snapStartedAt {
            let elapsed = now.timeIntervalSince(snapStart)
            let snapDuration: Double = 1.5
            if elapsed < snapDuration {
                let t = elapsed / snapDuration
                let easedT = 1 - pow(1 - t, 3)
                r = preSnapRatio * (1 - easedT) + realRatio * easedT
            } else {
                r = realRatio
            }
        } else {
            r = realRatio
        }

        let wA = longestWakingGapSec > 0 && secSince >= longestWakingGapSec
        let oA = longestGapSec > 0 && secSince >= longestGapSec
        let e = now.timeIntervalSinceReferenceDate

        let amplitude: Double
        let period: Double
        if reduceMotion {
            amplitude = 0
            period = 0
        } else if stableFloat {
            // Stable float: same baseline regardless of state. Used in the
            // onboarding preview where rapid threshold crossings would otherwise
            // shift the sin frequency mid-wave and snap the spirit's Y position.
            amplitude = 3
            period = 5.0
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
    // Each wisp has its own radial gradient with its own bright center,
    // so the spirit reads as three distinct cloud shapes (body + two
    // wisps) rather than a single elongated silhouette.
    let gradient = bodyGradient
    for cx in [14.0, 86.0] {
        let path = Path(ellipseIn: CGRect(x: cx - 9, y: 58 - 6.5, width: 18, height: 13))
        ctx.fill(path, with: .radialGradient(
            gradient,
            center: CGPoint(x: cx - 9 + 6.84, y: 58 - 6.5 + 4.16),
            startRadius: 0,
            endRadius: 18
        ))
    }
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
