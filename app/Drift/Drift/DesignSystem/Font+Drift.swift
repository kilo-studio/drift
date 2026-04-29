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

extension Text {
    // Caveat's cursive overshoots extend past its typographic advance, so SwiftUI's
    // Text frame clips trailing swashes. Padding can't fix it (Text frame is set by
    // content), so append a hair-space to widen the underlying string.
    static func driftCardTitle(_ content: String) -> Text {
        Text(content + "\u{2003}").font(.driftCardTitle)
    }
}
