import SwiftUI
import CoreText

enum DriftFonts {
    private static let bundledFonts = [
        "Quicksand-VariableFont_wght",
        "Caveat-VariableFont_wght",
    ]

    static func register() {
        for name in bundledFonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static let driftDisplay   = Font.custom("Quicksand-SemiBold", size: 80)
    static let driftStatNum   = Font.custom("Quicksand-SemiBold", size: 52)
    static let driftBestNum   = Font.custom("Quicksand-SemiBold", size: 22)
    static let driftCardTitle = Font.custom("Caveat", size: 24).weight(.semibold)
    static let driftLabel     = Font.custom("Quicksand-Medium", size: 13)
    static let driftSub       = Font.custom("Quicksand-Medium", size: 12)
}
