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
    static let driftTimerUnit = Font.custom("Quicksand-Light", size: 32)
    static let driftCardTitle = Font.custom("Caveat", size: 24).weight(.semibold)
    static let driftHeroLabel = Font.custom("Caveat", size: 26).weight(.semibold)
    static let driftBestLabel = Font.custom("Caveat", size: 16).weight(.semibold)
    static let driftLabel     = Font.custom("Quicksand-Medium", size: 13)
    static let driftSub       = Font.custom("Quicksand-Medium", size: 12)
}

extension Text {
    // Caveat's cursive overshoots extend past its typographic advance, so SwiftUI
    // clips trailing swashes against the Text frame. Padding can't fix it (Text
    // frame is set by content), so wrap the string with em-space on both sides —
    // both gives the swash room AND keeps the rendered string visually centered.
    // Apply a Caveat font yourself after — e.g. Text.caveat("today").font(.driftCardTitle)
    static func caveat(_ content: String) -> Text {
        Text("\u{2003}" + content + "\u{2003}")
    }
}
