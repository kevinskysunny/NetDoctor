import NetworkCore
import SwiftUI

struct QuickCheckView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: model.statusSymbolName)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetworkConsole Lite")
                        .font(.headline)
                    Text(model.statusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(model.summaryText)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if let report = model.report {
                Divider()
                InfoRow(title: "路径", value: report.path.status.displayName, systemImage: "point.3.connected.trianglepath.dotted")
                InfoRow(title: "活动接口", value: "\(report.interfaces.filter { $0.isActive }.count)", systemImage: "network")
                InfoRow(title: "DNS", value: report.dns.servers.first ?? "未获取", systemImage: "server.rack")
                InfoRow(title: "外网", value: reachabilityText(report), systemImage: "globe")

                if let advice = report.advice.first {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: advice.severity.symbolName)
                            .foregroundStyle(adviceColor(advice.severity))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(advice.title)
                                .font(.subheadline.weight(.semibold))
                            Text(advice.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let lastError = model.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("立即检查") {
                    Task {
                        await model.runCheck()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isChecking)

                Button("打开详情") {
                    openWindow(id: "detail")
                }

                Spacer()

                Button("导出支持包") {
                    model.exportSupportPackage()
                }
            }
        }
        .padding(16)
        .frame(width: 380)
        .task {
            model.start()
        }
    }

    private var statusColor: Color {
        switch model.report?.health {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        default:
            return .secondary
        }
    }

    private func reachabilityText(_ report: DiagnosisReport) -> String {
        guard !report.reachability.isEmpty else { return "未探测" }
        let success = report.reachability.filter { $0.status == .success }.count
        return "\(success)/\(report.reachability.count) 成功"
    }

    private func adviceColor(_ grade: HealthGrade) -> Color {
        switch grade {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .checking:
            return .secondary
        }
    }
}
