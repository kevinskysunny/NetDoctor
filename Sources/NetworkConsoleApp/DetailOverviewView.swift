import Charts
import NetworkCore
import SwiftUI

/// 活动接口卡片口径计算（internal 纯函数，无视图依赖，可无渲染直测）。
enum OverviewActivity {
    static func compute(_ interfaces: [InterfaceInfo]) -> (count: Int, names: [String], degraded: Bool) {
        let physical = LocalMacSelector.physicalActive(interfaces)
        let degraded = physical.isEmpty && interfaces.contains { $0.kind == .other }
        return (physical.count, physical.map(\.name), degraded)
    }
}

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
                        let activity = OverviewActivity.compute(report.interfaces)
                        MetricCard(
                            title: model.text("overview.activeInterfaces"),
                            value: "\(activity.count)",
                            detail: activity.names.joined(separator: ", "),
                            systemImage: "network",
                            accentColor: activity.degraded ? .orange : .blue
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
                                let actions = AdviceActions.items(for: advice.code)
                                ViewThatFits(in: .horizontal) {
                                    // 优先单行展示：左侧信息 + 右侧直达按钮（符合用户手绘标注）
                                    HStack(alignment: .center, spacing: 12) {
                                        adviceContent(advice)
                                        if !actions.isEmpty {
                                            Spacer(minLength: 16)
                                            HStack(spacing: 8) {
                                                ForEach(actions) { action in
                                                    adviceActionButton(action)
                                                }
                                            }
                                        }
                                    }

                                    // 窄屏自适应：下方折行展示直达按钮，保证文案与按钮不截断
                                    VStack(alignment: .leading, spacing: 10) {
                                        adviceContent(advice)
                                        if !actions.isEmpty {
                                            HStack(spacing: 8) {
                                                Spacer()
                                                ForEach(actions) { action in
                                                    adviceActionButton(action)
                                                }
                                            }
                                        }
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

    @ViewBuilder
    private func adviceContent(_ advice: DiagnosticAdvice) -> some View {
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
    }

    @ViewBuilder
    private func adviceActionButton(_ action: AdviceActionItem) -> some View {
        Button {
            SystemSettingsNavigator.open(action.pane)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(model.text(action.titleKey))
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(model.text(action.titleKey))
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

/// 排查建议直达系统设置操作项
public struct AdviceActionItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let titleKey: String
    public let systemImage: String
    public let pane: SystemSettingsPane

    public init(id: String, titleKey: String, systemImage: String, pane: SystemSettingsPane) {
        self.id = id
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.pane = pane
    }
}

public enum AdviceActions {
    public static func items(for code: AdviceCode) -> [AdviceActionItem] {
        switch code {
        case .enableInterface:
            return [
                AdviceActionItem(id: "ethernet", titleKey: "action.openSettings.ethernet", systemImage: "cable.connector", pane: .ethernet),
                AdviceActionItem(id: "wifi", titleKey: "action.openSettings.wifi", systemImage: "wifi", pane: .wifi)
            ]
        case .checkDNS:
            return [
                AdviceActionItem(id: "dns", titleKey: "action.openSettings.dns", systemImage: "server.rack", pane: .dns)
            ]
        case .confirmConnection:
            return [
                AdviceActionItem(id: "wifi", titleKey: "action.openSettings.wifi", systemImage: "wifi", pane: .wifi),
                AdviceActionItem(id: "network", titleKey: "action.openSettings.network", systemImage: "gearshape", pane: .network)
            ]
        case .checkRoute, .unreachable, .partialUnreachable, .constrained, .highLatency:
            return [
                AdviceActionItem(id: "network", titleKey: "action.openSettings.network", systemImage: "gearshape", pane: .network)
            ]
        case .healthy, .unknown:
            return []
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