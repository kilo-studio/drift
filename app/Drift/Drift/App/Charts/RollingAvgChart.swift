import SwiftUI
import Charts

struct RollingAvgChart: View {
    let series: [(Date, TimeInterval)]

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private var points: [Point] {
        series.map { Point(date: $0.0, minutes: $0.1 / 60) }
    }

    var body: some View {
        if points.isEmpty {
            ChartEmptyState()
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(points) { p in
            AreaMark(
                x: .value("day", p.date),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(LinearGradient(
                colors: [Color.driftSage.opacity(0.4), Color.driftSage.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            ))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("day", p.date),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftSageDeep)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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
