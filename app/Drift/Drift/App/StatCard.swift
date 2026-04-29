import SwiftUI

/// Standard stat card: centered Caveat title, big Quicksand number (color-tagged),
/// then a small label. Used by today / average / waking-gap.
struct StatCard: View {
    let title: String
    let bigNumber: String
    let bigNumberColor: Color
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Text.caveat(title)
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Text(bigNumber)
                .font(.driftStatNum)
                .tracking(-1)
                .foregroundStyle(bigNumberColor)
                .padding(.bottom, 4)

            Text(label)
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
        }
        .frame(maxWidth: .infinity)
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
                .font(.driftSub)
                .foregroundStyle(.driftInkFade)
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
