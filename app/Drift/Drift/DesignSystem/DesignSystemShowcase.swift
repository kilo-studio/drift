import SwiftUI

struct DesignSystemShowcase: View {
    var body: some View {
        ZStack {
            LinearGradient.driftSky.ignoresSafeArea()
            LinearGradient.driftSunHaze.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Drift design system")
                        .font(.driftCardTitle)
                        .foregroundStyle(.driftInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    sectionType
                    sectionData
                    sectionText
                    sectionSurface
                    sectionSky
                    sectionCardExample
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    private var sectionType: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Type")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            typeRow("driftDisplay",   "80 / Quicksand SemiBold", Text("12:34").font(.driftDisplay).tracking(-1.5))
            typeRow("driftStatNum",   "52 / Quicksand SemiBold", Text("3").font(.driftStatNum).tracking(-1))
            typeRow("driftBestNum",   "22 / Quicksand SemiBold", Text("4d 12h").font(.driftBestNum).tracking(-0.2))
            typeRow("driftCardTitle", "24 / Caveat SemiBold",    Text("today").font(.driftCardTitle))
            typeRow("driftLabel",     "13 / Quicksand Medium",   Text("STAT LABEL").font(.driftLabel))
            typeRow("driftSub",       "12 / Quicksand Medium",   Text("subtitle text").font(.driftSub))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private var sectionData: some View {
        section(title: "Data") {
            swatch("driftCoral",    "#E8836B", .driftCoral,    note: "today / current / deep accent")
            swatch("driftPeach",    "#F4B393", .driftPeach,    note: "past data")
            swatch("driftSage",     "#A8BC93", .driftSage,     note: "aggregates light")
            swatch("driftSageDeep", "#7E9476", .driftSageDeep, note: "aggregates strong")
        }
    }

    private var sectionText: some View {
        section(title: "Text") {
            swatch("driftInk",     "#4A453F", .driftInk,     note: "primary")
            swatch("driftInkSoft", "#6B635A", .driftInkSoft, note: "secondary")
            swatch("driftInkFade", "#9A9082", .driftInkFade, note: "tertiary")
        }
    }

    private var sectionSurface: some View {
        section(title: "Surface") {
            swatch("driftCream",     "#FAF3E7", .driftCream,     note: "card surface base")
            swatch("driftCreamWarm", "#F5EAD8", .driftCreamWarm, note: "body gradient bottom")
        }
    }

    private var sectionSky: some View {
        section(title: "Sky") {
            swatch("driftSkyTop",      "#7FA7BD", .driftSkyTop,      note: "gradient 0%")
            swatch("driftSkyUpperMid", "#A8C6D5", .driftSkyUpperMid, note: "gradient 30%")
            swatch("driftSkyLowerMid", "#C8DDE4", .driftSkyLowerMid, note: "gradient 65%")
            swatch("driftSkyHorizon",  "#DCE5DA", .driftSkyHorizon,  note: "gradient 100%")
        }
    }

    private var sectionCardExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
            Text("3")
                .font(.driftStatNum)
                .tracking(-1)
                .foregroundStyle(.driftCoral)
            Text("HITS")
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private func section<Content: View>(title: String, @ViewBuilder _ rows: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
            VStack(spacing: 10) {
                rows()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private func swatch(_ name: String, _ hex: String, _ color: Color, note: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.driftLabel)
                    .foregroundStyle(.driftInk)
                Text(note)
                    .font(.driftSub)
                    .foregroundStyle(.driftInkFade)
            }
            Spacer(minLength: 0)
            Text(hex)
                .font(.driftSub.monospaced())
                .foregroundStyle(.driftInkSoft)
        }
    }

    private func typeRow(_ name: String, _ spec: String, _ sample: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sample.foregroundStyle(.driftInk)
            Text(name)
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
            Text(spec)
                .font(.driftSub)
                .foregroundStyle(.driftInkFade)
        }
    }
}

#Preview {
    DesignSystemShowcase()
}
