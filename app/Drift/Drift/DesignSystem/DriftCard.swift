import SwiftUI

private let cardCornerRadius: CGFloat = 28
private let cardSurface = Color(hex: 0xFFFBF4).opacity(0.75)
private let cardShadow = Color(hex: 0x4B3C2D)

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
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: cardShadow.opacity(0.18), radius: 16, x: 0, y: 12)
            .shadow(color: cardShadow.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func driftCard() -> some View {
        modifier(DriftCardModifier())
    }
}
