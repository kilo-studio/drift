import SwiftUI

/// Standard stat card: centered Caveat title, big Quicksand number (color-tagged),
/// then a small label. Used by today / average / waking-gap.
struct StatCard: View {
    let title: String
    let bigNumberParts: [ElapsedPart]
    let bigNumberColor: Color
    let label: String

    /// Plain-string init for cards whose big number is just a number ("17", "5.8").
    init(title: String, bigNumber: String, bigNumberColor: Color, label: String) {
        self.title = title
        self.bigNumberParts = [.number(bigNumber)]
        self.bigNumberColor = bigNumberColor
        self.label = label
    }

    /// Parts init for cards whose big number includes unit suffixes ("2h 37m") so
    /// the units render at a smaller size than the digits.
    init(title: String, bigNumberParts: [ElapsedPart], bigNumberColor: Color, label: String) {
        self.title = title
        self.bigNumberParts = bigNumberParts
        self.bigNumberColor = bigNumberColor
        self.label = label
    }

    var body: some View {
        VStack(spacing: 0) {
            Text.caveat(title)
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(bigNumberParts.indices, id: \.self) { i in
                    switch bigNumberParts[i] {
                    case .number(let s):
                        Text(s).font(.driftStatNum).tracking(-1)
                    case .unit(let s):
                        Text(s).font(.driftStatNumUnit)
                    }
                }
            }
            .foregroundStyle(bigNumberColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.bottom, 4)

            Text(label)
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
        }
        // maxHeight so paired cards in an HStack match the taller one's height.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .driftCard()
    }
}

/// Card wrapping a chart: centered title, centered subtitle, then the chart content.
struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let chartHeight: CGFloat
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String, chartHeight: CGFloat = 180, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.chartHeight = chartHeight
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Text.caveat(title)
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .padding(.bottom, 4)

            Text(subtitle)
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            content()
                .frame(height: chartHeight)
        }
        .frame(maxWidth: .infinity)
        .driftCard()
    }
}

/// Avg formatter mirroring the prototype: round to int once value ≥ 10, else 1 decimal.
func formatAvg(_ value: Double) -> String {
    value >= 10 ? "\(Int(value.rounded()))" : String(format: "%.1f", value)
}

/// Placeholder for charts when there's no data — Charts framework crashes if
/// asked to compute axes over empty domains.
struct ChartEmptyState: View {
    var body: some View {
        Text("—")
            .font(.driftLabel)
            .foregroundStyle(.driftInkFade)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
