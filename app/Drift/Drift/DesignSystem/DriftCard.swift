import SwiftUI
import UIKit

private let cardCornerRadius: CGFloat = 28

/// Light: warm cream tint over the ultra-thin material.
/// Dark: faint white tint over the (auto-darkened) material — preserves the glass feel.
/// Both pulled down for more transparency on top of the new ambient cloud / star
/// layer so the atmosphere shows through the cards.
private let cardSurface: Color = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.04)
        : UIColor(red: 1.0, green: 251/255, blue: 244/255, alpha: 0.22)
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
            .shadow(color: cardShadow.opacity(0.08), radius: 16, x: 0, y: 12)
            .shadow(color: cardShadow.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func driftCard() -> some View {
        modifier(DriftCardModifier())
    }
}
