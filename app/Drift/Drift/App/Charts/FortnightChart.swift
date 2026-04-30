import SwiftUI
import Charts

struct FortnightChart: View {
    let counts: [DailyCount]

    var body: some View {
        if counts.allSatisfy({ $0.count == 0 }) {
            ChartEmptyState()
        } else {
            chart
        }
    }

    // Mirrors the cravings chart's bar styling — two-color gradient with opacity at
    // the bottom, no explicit width, cornerRadius 4. That combination avoids the
    // default drop-shadow Charts paints behind bars on iOS 26.
    private func barFill(today: Bool) -> LinearGradient {
        let top = today ? Color.driftCoral : Color.driftPeach
        return LinearGradient(
            colors: [top, top.opacity(0.7)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var chart: some View {
        Chart(counts, id: \.date) { day in
            BarMark(
                x: .value("day", day.date, unit: .day),
                y: .value("count", day.count),
                width: .ratio(0.6)
            )
            .foregroundStyle(barFill(today: day.isToday))
            .cornerRadius(12)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .font(.driftSub)
                    .foregroundStyle(.driftInkSoft)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.driftInkFade.opacity(0.15))
                AxisValueLabel()
                    .font(.driftSub)
                    .foregroundStyle(.driftInkSoft)
            }
        }
    }
}
