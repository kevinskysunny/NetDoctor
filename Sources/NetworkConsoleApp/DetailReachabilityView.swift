import Charts
import NetworkCore
import SwiftUI

struct ReachabilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let report = model.report, !report.reachabilitySummaries.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Swift Charts 延迟图表
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.text("reachability.chart.title"))
                                .font(.headline)

                            Chart {
                                ForEach(chartData(report)) { item in
                                    BarMark(
                                        x: .value("Endpoint", item.name),
                                        y: .value("P50 Latency", item.p50)
                                    )
                                    .foregroundStyle(item.color.gradient)
                                    .cornerRadius(6)

                                    if let p90 = item.p90 {
                                        RuleMark(
                                            xStart: .value("Endpoint", item.name),
                                            xEnd: .value("Endpoint", item.name),
                                            y: .value("P90 Latency", p90)
                                        )
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .foregroundStyle(Color.orange.opacity(0.8))
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 180)
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }

                        // 详细端点列表
                        VStack(spacing: 10) {
                            ForEach(report.reachabilitySummaries) { summary in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(summary.endpointName)
                                            .font(.headline)
                                        Spacer()
                                        Text(model.text("reachability.successCount", summary.successCount, summary.attempts))
                                            .font(.callout)
                                            .foregroundStyle(summary.failureCount == 0 ? Color.green : Color.orange)
                                    }

                                    HStack(spacing: 12) {
                                        MetricLine(title: model.text("reachability.loss"), value: summary.lossRate.formatted(.percent.precision(.fractionLength(0))))
                                        MetricLine(title: "P50", value: Self.format(summary.percentiles.p50))
                                        MetricLine(title: "P90", value: Self.format(summary.percentiles.p90))
                                        MetricLine(title: "P95", value: Self.format(summary.percentiles.p95))
                                    }
                                }
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    model.text("reachability.empty.title"),
                    systemImage: "globe",
                    description: Text(model.text("reachability.empty.message"))
                )
            }
        }
        .navigationTitle(model.text("detail.tab.reachability"))
    }

    private struct ChartEndpointItem: Identifiable {
        let id: String
        let name: String
        let p50: Double
        let p90: Double?
        let color: Color
    }

    private func chartData(_ report: DiagnosisReport) -> [ChartEndpointItem] {
        report.reachabilitySummaries.compactMap { summary in
            guard let p50 = summary.percentiles.p50 else { return nil }
            let color: Color = summary.failureCount == 0
                ? (p50 > 300 ? Color.orange : Color(red: 0.2, green: 0.8, blue: 0.5))
                : Color.red
            return ChartEndpointItem(
                id: summary.endpointID,
                name: summary.endpointName,
                p50: p50,
                p90: summary.percentiles.p90,
                color: color
            )
        }
    }

    private static func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) ms"
    }
}