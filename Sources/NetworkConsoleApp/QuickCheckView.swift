import NetworkCore
import SwiftUI

struct QuickCheckView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.text("app.name"))
                        .font(.headline.weight(.semibold))
                    HStack(spacing: 4) {
                        Image(systemName: model.statusSymbolName)
                            .font(.system(size: 10, weight: .bold))
                        Text(model.statusTitle)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12), in: Capsule())
                }
                Spacer()
            }

            Text(model.summaryText)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if let report = model.report {
                Divider()
                InfoRow(title: model.text("quick.path"), value: model.text(for: report.path.status), systemImage: "point.3.connected.trianglepath.dotted")
                InfoRow(title: model.text("quick.activeInterfaces"), value: "\(report.interfaces.filter { $0.isActive }.count)", systemImage: "network")
                InfoRow(title: model.text("quick.dns"), value: report.dns.servers.first ?? model.text("quick.notProbed"), systemImage: "server.rack")
                InfoRow(title: model.text("quick.internet"), value: reachabilityText(report), systemImage: "globe")

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
                Button(model.text("quick.checkNow")) {
                    Task {
                        await model.runCheck()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isChecking)

                Button(model.text("quick.openDetail")) {
                    (NSApp.delegate as? AppDelegate)?.showDetailWindow()
                }

                Spacer()

                Button(model.text("quick.export")) {
                    model.exportSupportPackage()
                }
            }

            Text(model.versionText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
        guard !report.reachability.isEmpty else { return model.text("quick.notProbed") }
        let success = report.reachability.filter { $0.status == .success }.count
        return model.text("quick.successCount", success, report.reachability.count)
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
