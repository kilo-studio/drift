import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Color that swaps based on `userInterfaceStyle`. Light/dark hexes are RGB only;
    /// alpha is applied separately via `.opacity()` if needed.
    fileprivate init(lightHex: UInt32, darkHex: UInt32) {
        self.init(uiColor: UIColor { trait in
            let h = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red:   CGFloat((h >> 16) & 0xFF) / 255,
                green: CGFloat((h >> 8) & 0xFF) / 255,
                blue:  CGFloat(h & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    // MARK: - Data colors (same in both modes — readable against light or dark surfaces)
    static let driftCoral      = Color(hex: 0xE8836B)
    static let driftPeach      = Color(hex: 0xF4B393)
    static let driftSage       = Color(hex: 0xA8BC93)
    static let driftSageDeep   = Color(hex: 0x7E9476)

    // MARK: - Text (light: warm browns / dark: warm creams)
    static let driftInk     = Color(lightHex: 0x4A453F, darkHex: 0xE8E2D5)
    static let driftInkSoft = Color(lightHex: 0x6B635A, darkHex: 0xB0A99B)
    static let driftInkFade = Color(lightHex: 0x9A9082, darkHex: 0x807868)

    // MARK: - Surfaces
    static let driftCream      = Color(hex: 0xFAF3E7)
    static let driftCreamWarm  = Color(hex: 0xF5EAD8)

    // MARK: - Sky (skyLowerMid is the home background — deep navy at night)
    static let driftSkyTop      = Color(hex: 0x7FA7BD)
    static let driftSkyUpperMid = Color(hex: 0xA8C6D5)
    static let driftSkyLowerMid = Color(lightHex: 0xC8DDE4, darkHex: 0x0F1A24)
    static let driftSkyHorizon  = Color(hex: 0xDCE5DA)
}

extension ShapeStyle where Self == Color {
    static var driftCoral:      Color { .driftCoral }
    static var driftPeach:      Color { .driftPeach }
    static var driftSage:       Color { .driftSage }
    static var driftSageDeep:   Color { .driftSageDeep }

    static var driftInk:        Color { .driftInk }
    static var driftInkSoft:    Color { .driftInkSoft }
    static var driftInkFade:    Color { .driftInkFade }

    static var driftCream:      Color { .driftCream }
    static var driftCreamWarm:  Color { .driftCreamWarm }

    static var driftSkyTop:      Color { .driftSkyTop }
    static var driftSkyUpperMid: Color { .driftSkyUpperMid }
    static var driftSkyLowerMid: Color { .driftSkyLowerMid }
    static var driftSkyHorizon:  Color { .driftSkyHorizon }
}
