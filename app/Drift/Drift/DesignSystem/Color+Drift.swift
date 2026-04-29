import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static let driftCoral      = Color(hex: 0xE8836B)
    static let driftPeach      = Color(hex: 0xF4B393)
    static let driftSage       = Color(hex: 0xA8BC93)
    static let driftSageDeep   = Color(hex: 0x7E9476)

    static let driftInk        = Color(hex: 0x4A453F)
    static let driftInkSoft    = Color(hex: 0x6B635A)
    static let driftInkFade    = Color(hex: 0x9A9082)

    static let driftCream      = Color(hex: 0xFAF3E7)
    static let driftCreamWarm  = Color(hex: 0xF5EAD8)

    static let driftSkyTop      = Color(hex: 0x7FA7BD)
    static let driftSkyUpperMid = Color(hex: 0xA8C6D5)
    static let driftSkyLowerMid = Color(hex: 0xC8DDE4)
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
