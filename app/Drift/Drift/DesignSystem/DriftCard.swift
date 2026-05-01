import SwiftUI
import UIKit

private let cardCornerRadius: CGFloat = 28

/// Light: very faint warm cream tint over the ultra-thin material.
/// Dark: fully clear — ultraThinMaterial alone is enough.
/// Both pulled down further per user — let more of the bg show through.
private let cardSurface: Color = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor.clear
        : UIColor(red: 1.0, green: 251/255, blue: 244/255, alpha: 0.10)
})

/// Light: warm brown for shadow. Dark: black, very subtle (most of the depth comes
/// from the bg/card brightness contrast).
private let cardShadow: Color = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor.black
        : UIColor(red: 75/255, green: 60/255, blue: 45/255, alpha: 1)
})

/// Light: white inner highlight on the rounded edge. Dark: subtle white for glass rim.
private let cardStroke: Color = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.10)
        : UIColor.white.withAlphaComponent(0.6)
})

struct DriftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.top, 22)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(cardSurface)
                    .background(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1)
            }
            // Near-zero shadows — the soft darkening around card edges was the
            // remaining thing that made cards read as opaque "objects" rather
            // than translucent panes. Just enough lift to disambiguate the
            // edge from the bg.
            .shadow(color: cardShadow.opacity(0.025), radius: 12, x: 0, y: 8)
            .shadow(color: cardShadow.opacity(0.015), radius: 3, x: 0, y: 1)
    }
}

extension View {
    func driftCard() -> some View {
        modifier(DriftCardModifier())
    }
}
