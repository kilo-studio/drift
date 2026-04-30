import SwiftUI
import Charts

struct TodayStretchesChart: View {
    let stretches: [(Date, TimeInterval)]

    private struct Point: Identifiable {
        let id = UUID()
        let index: Int
        let date: Date
        let minutes: Double
    }

    private var points: [Point] {
        stretches.enumerated().map { i, s in
            Point(index: i, date: s.0, minutes: s.1 / 60)
        }
    }

    var body: some View {
        if points.isEmpty {
            ChartEmptyState()
        } else {
            chart
        }
    }

    private var chart: some View {
        // Pick ~4 indices evenly across the data so the time labels don't crowd.
        let labelStride = max(1, points.count / 4)
        let labelIndices = stride(from: 0, to: points.count, by: labelStride).map { $0 }

        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mma"
            f.amSymbol = "a"
            f.pmSymbol = "p"
            return f
        }()

        return Chart(points) { p in
            AreaMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(LinearGradient(
                colors: [Color.driftCoral.opacity(0.35), Color.driftCoral.opacity(0.04)],
                startPoint: .top, endPoint: .bottom
            ))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftCoral)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftCoral)
            .symbolSize(60)
        }
        .chartXAxis {
            AxisMarks(values: labelIndices) { value in
                AxisValueLabel {
                    if let i = value.as(Int.self), i < points.count {
                        Text(formatter.string(from: points[i].date).lowercased())
                            .font(.driftSub)
                            .foregroundStyle(.driftInkSoft)
                    }
                }
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
