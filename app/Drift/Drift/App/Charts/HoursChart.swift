import SwiftUI
import Charts

struct HoursChart: View {
    let counts: [Int]  // 24 buckets, 0..23

    private struct Bucket: Identifiable {
        let id: Int  // hour
        let count: Int
    }

    private var buckets: [Bucket] {
        counts.enumerated().map { Bucket(id: $0.offset, count: $0.element) }
    }

    var body: some View {
        if counts.allSatisfy({ $0 == 0 }) {
            ChartEmptyState()
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(buckets) { b in
            BarMark(
                x: .value("hour", b.id),
                y: .value("count", b.count)
            )
            .foregroundStyle(LinearGradient(
                colors: [Color.driftSage, Color.driftSageDeep.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            ))
            .cornerRadius(4)
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) {
                        Text(hourLabel(h))
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

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 6: return "6a"
        case 12: return "noon"
        case 18: return "6p"
        default: return ""
        }
    }
}
