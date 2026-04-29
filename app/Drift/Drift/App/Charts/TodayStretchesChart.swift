import SwiftUI
import Charts

struct TodayStretchesChart: View {
    let stretches: [(Date, TimeInterval)]

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private var points: [Point] {
        stretches.map { Point(date: $0.0, minutes: $0.1 / 60) }
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
                x: .value("time", p.date),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(LinearGradient(
                colors: [Color.driftCoral.opacity(0.35), Color.driftCoral.opacity(0.04)],
                startPoint: .top, endPoint: .bottom
            ))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("time", p.date),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftCoral)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.hour())
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
