import Charts
import NetworkCore
import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel
    var isTabActive: Bool = true
    var onSelectPipelineNode: ((NetworkPipelineView.PipelineNodeType) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 顶部首屏：健康分仪表盘 + 拓扑管线
                HStack(alignment: .center, spacing: 24) {
                    HealthScoreGaugeView(
                        score: model.score,
                        grade: model.report?.health ?? (model.isChecking ? .checking : .healthy),
                        verdict: model.verdictText,
                        size: 136,
                        lineWidth: 10,
                        showVerdict: true,
                        gradeTitle: model.text(for: model.report?.health ?? (model.isChecking ? .checking : .healthy)),
                        scoreSuffix: model.text("gauge.scoreSuffix")
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.text("overview.title"))
                            .font(.title2.bold())

                        Text(model.summaryText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // 4 节点拓扑流光链路（仅在 Overview 活跃时渲染）
                        if isTabActive {
                            NetworkPipelineView(
                                report: model.report,
                                isChecking: model.isChecking,
                                isVisible: isTabActive,
                                onSelectNode: onSelectPipelineNode,
                                nodeTitles: [
                                    .localMac: model.text("pipeline.node.localMac"),
                                    .gateway: model.text("pipeline.node.gateway"),
                                    .dns: model.text("pipeline.node.dns"),
                                    .internet: model.text("pipeline.node.internet")
                                ]
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // 2x2 Bento Box 指标矩阵
                if let report = model.report {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 14)],
                        spacing: 14
                    ) {
                        MetricCard(
                            title: model.text("overview.path"),
                            value: model.text(for: report.path.status),
                            detail: report.path.isConstrained ? model.text("overview.path.detailConstrained") : model.text("overview.path.detailNormal"),
                            systemImage: "point.3.connected.trianglepath.dotted",
                            accentColor: report.path.status == .available ? Color.green : Color.red
                        )
                        MetricCard(
                            title: model.text("overview.activeInterfaces"),
                            value: "\(report.interfaces.filter { $0.isActive }.count)",
                            detail: report.interfaces.filter { $0.isActive }.map(\.name).joined(separator: ", "),
                            systemImage: "network",
                            accentColor: .blue
                        )
                        MetricCard(
                            title: model.text("overview.dnsServers"),
                            value: report.dns.servers.first ?? model.text("overview.notAvailable"),
                            detail: report.dns.servers.joined(separator: ", "),
                            systemImage: "server.rack",
                            accentColor: .purple
                        )
                        MetricCard(
                            title: model.text("overview.internet"),
                            value: "\(report.reachability.filter { $0.status == .success }.count)/\(report.reachability.count)",
                            detail: model.text("overview.internet.detail"),
                            systemImage: "globe",
                            accentColor: .cyan
                        )
                    }

                    // 排查建议列表
                    if !report.advice.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.text("overview.advice"))
                                .font(.headline)
                            ForEach(report.advice) { advice in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: advice.severity.symbolName)
                                        .foregroundStyle(adviceColor(advice.severity))
                                        .font(.title3)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(advice.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(advice.message)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        model.text("overview.empty.title"),
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text(model.text("overview.empty.message"))
                    )
                }
            }
            .padding(24)
        }
    }

    private func adviceColor(_ grade: HealthGrade) -> Color {
        switch grade {
        case .healthy: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .warning: return .orange
        case .critical: return .red
        case .checking: return .secondary
        }
    }
}

struct MetricLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}