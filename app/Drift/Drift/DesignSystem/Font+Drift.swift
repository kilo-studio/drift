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
    static let driftStatNum     = Font.custom("Quicksand-SemiBold", size: 52)
    static let driftStatNumUnit = Font.custom("Quicksand-SemiBold", size: 22)
    static let driftBestNum   = Font.custom("Quicksand-SemiBold", size: 22)
    static let driftTimerUnit = Font.custom("Quicksand-SemiBold", size: 32)
    static let driftCardTitle = Font.custom("Caveat", size: 24).weight(.semibold)
    static let driftHeroLabel = Font.custom("Caveat", size: 26).weight(.semibold)
    /// Hero "bests" row labels ("longest gap while awake", "all time longest gap").
    /// Uses Quicksand instead of Caveat — the handwritten face read as decorative
    /// when sat next to the big number, hurting scanability of what's actually a
    /// utility label. 15pt is one notch above `driftLabel` so it carries weight
    /// against the 22pt `driftBestNum` it sits beside.
    static let driftBestLabel = Font.custom("Quicksand-Medium", size: 15)
    static let driftLabel     = Font.custom("Quicksand-Medium", size: 13)
    static let driftSub       = Font.custom("Quicksand-Medium", size: 12)

    /// Settings-style row label — clearer, more prominent than `driftLabel`.
    static let driftRowLabel       = Font.custom("Quicksand-SemiBold", size: 16)
    /// Settings-style row description — sits below the label, readable but subordinate.
    static let driftRowDescription = Font.custom("Quicksand-Medium", size: 14)
}

extension Text {
    // Caveat's cursive overshoots extend past its typographic advance, so SwiftUI
    // clips trailing swashes against the Text frame. Padding can't fix it (Text
    // frame is set by content), so wrap the string with thin-space (1/5 em ≈ 5pt
    // at 24pt size) on both sides — just enough for the swash, narrow enough that
    // it doesn't visibly skew centering the way em-space (24pt) did.
    // Apply a Caveat font yourself after — e.g. Text.caveat("today").font(.driftCardTitle)
    static func caveat(_ content: String) -> Text {
        Text("\u{2009}" + content + "\u{2009}")
    }

    /// Like `caveat` but only pads the trailing swash — use for left-aligned text
    /// where any leading whitespace would read as indentation.
    static func caveatLeading(_ content: String) -> Text {
        Text(content + "\u{2009}")
    }
}
