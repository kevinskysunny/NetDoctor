import AppKit
import NetworkCore
import SwiftUI

/// 网络诊断卡片视图与图片导出工具
struct CyberDiagnosisCardView: View {
    let report: DiagnosisReport
    let appVersion: String
    let appBuild: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部：网络诊断卡抬头与编号
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeColor)
                        Text("NETDOCTOR DIAGNOSTIC REPORT")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                    Text("NO. \(report.id.uuidString.prefix(12).uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("READ-ONLY SAFE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(themeColor)
                    Text(report.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            dashedDivider

            // 核心评分与定性诊断结论
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.35), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    VStack(spacing: 0) {
                        Text("\(report.score)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(themeColor)
                        Text(report.health.displayName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("诊断结论 (VERDICT)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(report.verdict.isEmpty ? "网络状态正常" : report.verdict)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text(report.summary)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(2)
                }
            }

            dashedDivider

            // 关键物理链路参数 (2x2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                vitalItem(title: "网络路径", value: report.path.status.displayName, sub: report.path.isConstrained ? "受限" : "畅通")
                vitalItem(title: "活动网络接口", value: "\(report.interfaces.filter { $0.isActive }.count) 个", sub: report.interfaces.first(where: { $0.isActive })?.name ?? "无")
                vitalItem(title: "主 DNS 解析", value: report.dns.servers.first ?? "未配置", sub: report.path.supportsDNS ? "DNS 正常" : "无 DNS")
                vitalItem(title: "公网连通端点", value: "\(report.reachability.filter { $0.status == .success }.count)/\(report.reachability.count)", sub: avgLatencyText)
            }

            dashedDivider

            // 底部条形码装饰与开发者版权信息
            HStack {
                // 科技感条形码装饰
                HStack(spacing: 2) {
                    ForEach(0..<28) { i in
                        Rectangle()
                            .fill(Color.white.opacity((i % 3 == 0 || i % 7 == 0) ? 0.7 : 0.25))
                            .frame(width: (i % 4 == 0) ? 3 : 1.5, height: 18)
                    }
                }
                Spacer()
                Text("NetDoctor v\(appVersion) (\(appBuild)) · Kevin Labs")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(18)
        .frame(width: 360)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var themeColor: Color {
        switch report.health {
        case .healthy: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .warning: return Color.orange
        case .critical: return Color.red
        case .checking: return Color.cyan
        }
    }

    private var avgLatencyText: String {
        let samples = report.latency.filter { $0.success }.map(\.durationMilliseconds)
        guard !samples.isEmpty else { return "—" }
        let avg = samples.reduce(0, +) / Double(samples.count)
        return String(format: "Avg %.0fms", avg)
    }

    @ViewBuilder
    private func vitalItem(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private var dashedDivider: some View {
        Line()
            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
    }

    // MARK: - 复制到剪贴板静态方法
    @MainActor
    static func copyToPasteboard(report: DiagnosisReport, appVersion: String, appBuild: String) -> Bool {
        let view = CyberDiagnosisCardView(
            report: report,
            appVersion: appVersion,
            appBuild: appBuild
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // 高清 Retina
        renderer.isOpaque = true
        guard let nsImage = renderer.nsImage else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        return true
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
