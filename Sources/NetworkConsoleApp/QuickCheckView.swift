import NetworkCore
import SwiftUI

struct QuickCheckView: View {
    @ObservedObject var model: AppModel
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 顶部 Header：品牌与迷你评分环
            HStack(alignment: .center, spacing: 10) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text("app.name"))
                        .font(.headline.weight(.semibold))

                    HStack(spacing: 4) {
                        Image(systemName: model.statusSymbolName)
                            .font(.system(size: 10, weight: .bold))
                            .symbolEffect(.variableColor.iterative.reversing, isActive: isVisible)

                        Text(model.statusTitle)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12), in: Capsule())
                }

                Spacer()

                // 迷你评分仪
                HealthScoreGaugeView(
                    score: model.score,
                    grade: model.report?.health ?? (model.isChecking ? .checking : .healthy),
                    verdict: "",
                    size: 44,
                    lineWidth: 4.5,
                    showVerdict: false
                )
            }

            // 2. 赛博心电波形视窗 (ECG Waveform，前台灵动波纹，后台休眠)
            ECGWaveformView(
                grade: model.report?.health ?? .checking,
                isChecking: model.isChecking,
                latestRTT: model.latestRTT,
                isVisible: isVisible,
                height: 52
            )

            // 3. 拟人化体检定性评语栏
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)

                Text(model.verdictText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(statusColor.opacity(0.25), lineWidth: 1)
            )

            // 4. 2x2 Bento Box 指标网格
            if let report = model.report {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    MetricCard(
                        title: model.text("quick.bento.latency"),
                        value: latencyDisplay(report),
                        detail: report.path.isConstrained ? model.text("overview.path.detailConstrained") : model.text(for: report.path.status),
                        systemImage: "waveform.path.ecg",
                        accentColor: statusColor
                    )

                    MetricCard(
                        title: model.text("quick.bento.interface"),
                        value: activeInterfaceName(report),
                        detail: "\(report.interfaces.filter { $0.isActive }.count) 个活动接口",
                        systemImage: "network",
                        accentColor: .blue
                    )

                    MetricCard(
                        title: model.text("quick.bento.dns"),
                        value: report.dns.servers.first ?? model.text("overview.notAvailable"),
                        detail: report.path.supportsDNS ? "DNS 正常" : "无 DNS",
                        systemImage: "server.rack",
                        accentColor: .purple
                    )

                    MetricCard(
                        title: model.text("quick.bento.reachability"),
                        value: reachabilityText(report),
                        detail: lossRateDisplay(report),
                        systemImage: "globe",
                        accentColor: reachabilityColor(report)
                    )
                }

                // 排查建议（如有异常）
                if let advice = report.advice.first, advice.severity != .healthy {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: advice.severity.symbolName)
                            .foregroundStyle(adviceColor(advice.severity))
                            .frame(width: 16)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(advice.title)
                                .font(.caption.weight(.semibold))
                            Text(advice.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .background(adviceColor(advice.severity).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if let lastError = model.lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            // 5. 底部操作栏（带声呐涟漪反馈）
            HStack(spacing: 8) {
                ZStack {
                    if model.isChecking {
                        SonarWaveEffect(isActive: true, tintColor: statusColor)
                            .frame(width: 32, height: 32)
                    }

                    Button {
                        Task {
                            await model.runCheck()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if model.isChecking {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Text(model.text("quick.checkNow"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isChecking)
                }

                Button(model.text("quick.openDetail")) {
                    (NSApp.delegate as? AppDelegate)?.showDetailWindow()
                }

                Spacer()

                Button {
                    model.exportSupportPackage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help(model.text("quick.export"))
            }

            HStack {
                Text(model.versionText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    _ = model.copyDiagnosisCard()
                } label: {
                    Label(model.text("detail.copyCard"), systemImage: "doc.on.clipboard")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 380)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }

    // MARK: - 辅助计算属性
    private var statusColor: Color {
        switch model.report?.health {
        case .healthy:
            return Color(red: 0.2, green: 0.88, blue: 0.5)
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
        return "\(success)/\(report.reachability.count)"
    }

    private func reachabilityColor(_ report: DiagnosisReport) -> Color {
        guard !report.reachability.isEmpty else { return .secondary }
        let success = report.reachability.filter { $0.status == .success }.count
        if success == report.reachability.count { return Color(red: 0.2, green: 0.88, blue: 0.5) }
        if success == 0 { return .red }
        return .orange
    }

    private func latencyDisplay(_ report: DiagnosisReport) -> String {
        let valid = report.latency.filter { $0.success }.map(\.durationMilliseconds)
        guard !valid.isEmpty else { return "—" }
        let p50 = LatencyPercentiles(samples: valid).p50
        if let p50 {
            return "\(Int(p50.rounded())) ms"
        }
        return "—"
    }

    private func activeInterfaceName(_ report: DiagnosisReport) -> String {
        let iface = report.interfaces.first(where: { $0.isDefaultRouteInterface }) ?? report.interfaces.first(where: { $0.isActive })
        return iface?.name ?? "无接口"
    }

    private func lossRateDisplay(_ report: DiagnosisReport) -> String {
        guard !report.reachability.isEmpty else { return "未探测" }
        let fail = report.reachability.filter { $0.status != .success }.count
        let rate = Double(fail) / Double(report.reachability.count)
        return String(format: "丢包 %.0f%%", rate * 100)
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
