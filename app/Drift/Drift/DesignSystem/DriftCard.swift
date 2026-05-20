import SwiftUI
import UIKit

private let cardCornerRadius: CGFloat = 28

/// iOS 26 Liquid Glass via `.glassEffect(.regular.tint(...))` tinted to the
/// dashboard's sky background. The tint pulls cards toward the same color family
/// as the bg so they feel like a lifted region of the sky rather than a separate
/// bright panel — the `.clear` variant on its own read as too bright.
///
/// `driftSkyLowerMid` already adapts (pale blue in light, deep navy in dark), so
/// tinting with it at low alpha gives the right cast in both modes for free.
/// One offscreen pass per card.
///
/// Card design history:
/// 1. Original — `.ultraThinMaterial` + cream-tint fill + stroke + two shadows
///    = five offscreen passes per card. Instruments measured 170–370 passes/frame
///    on Home with continuous TimelineView animations; scrolling unusable.
/// 2. Stroke-only — zero passes but cards felt too floaty.
/// 3. Material + stroke — two passes; system vibrancy gave a bluish cast in light
///    and a gray-panel feel in dark.
/// 4. Material + flat tint + stroke — three passes; right look but extra cost.
/// 5. `.glassEffect(.regular.tint(white/black @ 0.05))` — one pass; too neutral.
/// 6. `.glassEffect(.clear)` — one pass; cards read too bright.
/// 7. This — `.glassEffect(.regular.tint(.driftSkyLowerMid))` — cards lean the
///    same color family as the sky behind them.
struct DriftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .glassEffect(
                .regular.tint(.driftSkyLowerMid.opacity(0.4)),
                in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            )
    }
}

extension View {
    func driftCard() -> some View {
        modifier(DriftCardModifier())
    }
}
