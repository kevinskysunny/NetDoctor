import NetworkCore
import SwiftUI

/// 4 节点网络拓扑链路流光管线
struct NetworkPipelineView: View {
    let report: DiagnosisReport?
    let isChecking: Bool
    var onSelectNode: ((PipelineNodeType) -> Void)? = nil

    enum PipelineNodeType: String, CaseIterable, Identifiable {
        case localMac
        case gateway
        case dns
        case internet

        var id: String { rawValue }
    }

    enum NodeHealth {
        case normal
        case warning
        case critical
        case checking

        var color: Color {
            switch self {
            case .normal: return Color(red: 0.2, green: 0.88, blue: 0.5)
            case .warning: return Color.orange
            case .critical: return Color.red
            case .checking: return Color.cyan
            }
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 0) {
                nodeView(type: .localMac, health: macHealth)

                pipelineSegment(
                    isActive: isLink1Active,
                    health: isLink1Active ? .normal : (macHealth == .critical ? .critical : .warning),
                    time: time
                )

                nodeView(type: .gateway, health: gatewayHealth)

                pipelineSegment(
                    isActive: isLink2Active,
                    health: isLink2Active ? .normal : (gatewayHealth == .critical ? .critical : .warning),
                    time: time
                )

                nodeView(type: .dns, health: dnsHealth)

                pipelineSegment(
                    isActive: isLink3Active,
                    health: isLink3Active ? .normal : (dnsHealth == .critical ? .critical : .warning),
                    time: time
                )

                nodeView(type: .internet, health: internetHealth)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - 节点状态逻辑
    private var macHealth: NodeHealth {
        if isChecking { return .checking }
        guard let report else { return .checking }
        if report.path.status != .available { return .critical }
        let active = report.interfaces.filter { $0.isActive && $0.kind != .loopback }
        return active.isEmpty ? .critical : .normal
    }

    private var gatewayHealth: NodeHealth {
        if isChecking { return .checking }
        guard let report else { return .checking }
        if report.path.status != .available { return .critical }
        if report.routes.routes.isEmpty { return .warning }
        return .normal
    }

    private var dnsHealth: NodeHealth {
        if isChecking { return .checking }
        guard let report else { return .checking }
        if report.path.status != .available { return .critical }
        if report.dns.servers.isEmpty || !report.path.supportsDNS { return .warning }
        return .normal
    }

    private var internetHealth: NodeHealth {
        if isChecking { return .checking }
        guard let report else { return .checking }
        if report.path.status != .available { return .critical }
        guard !report.reachability.isEmpty else { return .warning }
        let success = report.reachability.filter { $0.status == .success }.count
        if success == 0 { return .critical }
        if success < report.reachability.count { return .warning }
        return .normal
    }

    private var isLink1Active: Bool {
        macHealth == .normal && (gatewayHealth == .normal || gatewayHealth == .warning)
    }

    private var isLink2Active: Bool {
        isLink1Active && (dnsHealth == .normal || dnsHealth == .warning)
    }

    private var isLink3Active: Bool {
        isLink2Active && internetHealth == .normal
    }

    // MARK: - 单个节点视图
    @ViewBuilder
    private func nodeView(type: PipelineNodeType, health: NodeHealth) -> some View {
        Button {
            onSelectNode?(type)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(health.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(health.color.opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: iconName(for: type))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(health.color)
                }

                Text(title(for: type))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle(for: type))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 68)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 节点连接管道与流动光粒子
    @ViewBuilder
    private func pipelineSegment(isActive: Bool, health: NodeHealth, time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let midY = h * 0.35 // 对齐圆形图标的水平轴

            Canvas { context, size in
                // 底层管道轨道
                var trackPath = Path()
                trackPath.move(to: CGPoint(x: 0, y: midY))
                trackPath.addLine(to: CGPoint(x: w, y: midY))

                if isActive {
                    // 连通流动的能量轨道
                    context.stroke(
                        trackPath,
                        with: .color(health.color.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                    // 发光穿梭粒子（Particle Flow）
                    let speed = 40.0
                    let particleCycle = max(1.0, Double(w) / speed)
                    let progress = (time.truncatingRemainder(dividingBy: particleCycle)) / particleCycle
                    let particleX = CGFloat(progress) * w

                    let particleRect = CGRect(x: particleX - 3.5, y: midY - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: particleRect), with: .color(.white))

                    let haloRect = CGRect(x: particleX - 7, y: midY - 7, width: 14, height: 14)
                    context.fill(Path(ellipseIn: haloRect), with: .color(health.color.opacity(0.7)))
                } else {
                    // 异常阻断虚线
                    context.stroke(
                        trackPath,
                        with: .color(health.color.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                    )
                }
            }
        }
        .frame(minWidth: 28, maxHeight: .infinity)
    }

    private func iconName(for type: PipelineNodeType) -> String {
        switch type {
        case .localMac: return "laptopcomputer"
        case .gateway: return "wifi.router"
        case .dns: return "server.rack"
        case .internet: return "globe.asia.australia.fill"
        }
    }

    private func title(for type: PipelineNodeType) -> String {
        switch type {
        case .localMac: return "本机 Mac"
        case .gateway: return "本地网关"
        case .dns: return "DNS 解析"
        case .internet: return "互联网"
        }
    }

    private func subtitle(for type: PipelineNodeType) -> String {
        guard let report else { return "—" }
        switch type {
        case .localMac:
            let iface = report.interfaces.first(where: { $0.isDefaultRouteInterface }) ?? report.interfaces.first(where: { $0.isActive })
            return iface?.name ?? "en0"
        case .gateway:
            let gw = report.routes.routes.first(where: { $0.isDefault })?.gateway
            return gw ?? "Router"
        case .dns:
            return report.dns.servers.first ?? "DNS"
        case .internet:
            let success = report.reachability.filter { $0.status == .success }.count
            return "\(success)/\(report.reachability.count)"
        }
    }
}
