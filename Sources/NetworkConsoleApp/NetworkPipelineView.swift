import NetworkCore
import SwiftUI

/// 4 节点网络拓扑链路管线（静默零 CPU 功耗）
struct NetworkPipelineView: View {
    let report: DiagnosisReport?
    let isChecking: Bool
    var isVisible: Bool = true
    var onSelectNode: ((PipelineNodeType) -> Void)? = nil

    enum PipelineNodeType: String, CaseIterable, Identifiable {
        case localMac
        case gateway
        case dns
        case internet

        var id: String { rawValue }
    }

    enum NodeHealth: Equatable {
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
        Group {
            if isVisible {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    pipelineContent(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                pipelineContent(time: 0)
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

    private func pipelineContent(time: TimeInterval) -> some View {
        let cycleDuration: Double = isChecking ? 1.0 : 2.2
        let baseProgress = isVisible ? CGFloat((time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration) : 0

        return HStack(spacing: 0) {
            PipelineNodeView(
                type: .localMac,
                health: macHealth,
                title: title(for: .localMac),
                subtitle: subtitle(for: .localMac),
                onSelect: { onSelectNode?(.localMac) }
            )

            PipelineSegmentCanvas(
                isActive: isLink1Active,
                health: isLink1Active ? .normal : (macHealth == .critical ? .critical : .warning),
                progress: baseProgress,
                isVisible: isVisible
            )

            PipelineNodeView(
                type: .gateway,
                health: gatewayHealth,
                title: title(for: .gateway),
                subtitle: subtitle(for: .gateway),
                onSelect: { onSelectNode?(.gateway) }
            )

            PipelineSegmentCanvas(
                isActive: isLink2Active,
                health: isLink2Active ? .normal : (gatewayHealth == .critical ? .critical : .warning),
                progress: (baseProgress + 0.33).truncatingRemainder(dividingBy: 1.0),
                isVisible: isVisible
            )

            PipelineNodeView(
                type: .dns,
                health: dnsHealth,
                title: title(for: .dns),
                subtitle: subtitle(for: .dns),
                onSelect: { onSelectNode?(.dns) }
            )

            PipelineSegmentCanvas(
                isActive: isLink3Active,
                health: isLink3Active ? .normal : (dnsHealth == .critical ? .critical : .warning),
                progress: (baseProgress + 0.66).truncatingRemainder(dividingBy: 1.0),
                isVisible: isVisible
            )

            PipelineNodeView(
                type: .internet,
                health: internetHealth,
                title: title(for: .internet),
                subtitle: subtitle(for: .internet),
                onSelect: { onSelectNode?(.internet) }
            )
        }
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
        if isChecking { return true }
        return (macHealth == .normal || macHealth == .warning) && (gatewayHealth == .normal || gatewayHealth == .warning)
    }

    private var isLink2Active: Bool {
        if isChecking { return true }
        return isLink1Active && (dnsHealth == .normal || dnsHealth == .warning)
    }

    private var isLink3Active: Bool {
        if isChecking { return true }
        return isLink2Active && (internetHealth == .normal || internetHealth == .warning)
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

// MARK: - 节点连接管道 Canvas 硬件加速视图（免除 GeometryReader 与布局计算）
private struct PipelineSegmentCanvas: View {
    let isActive: Bool
    let health: NetworkPipelineView.NodeHealth
    let progress: CGFloat
    let isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 21)

            Canvas { context, size in
                let w = size.width
                let h = size.height
                guard w > 0, h > 0 else { return }
                let midY = h / 2

                // 底层管道轨道
                let trackRect = CGRect(x: 0, y: midY - 1.25, width: w, height: 2.5)
                context.fill(Path(roundedRect: trackRect, cornerRadius: 1.25), with: .color(health.color.opacity(isActive ? 0.35 : 0.15)))

                // 穿梭微光能量粒子与彗星尾焰
                if isActive && isVisible && w > 8 {
                    let tailWidth: CGFloat = min(28, w * 0.45)
                    let travelDist = max(0, w - 8)
                    let currentX = progress * travelDist

                    let tailX = max(0, currentX - tailWidth + 4)
                    let actualTailWidth = min(tailWidth, currentX + 4)
                    if actualTailWidth > 1 {
                        let tailRect = CGRect(x: tailX, y: midY - 1.25, width: actualTailWidth, height: 2.5)
                        let gradient = Gradient(colors: [
                            health.color.opacity(0.0),
                            health.color.opacity(0.45),
                            Color.white.opacity(0.9)
                        ])
                        context.fill(
                            Path(roundedRect: tailRect, cornerRadius: 1.25),
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: tailRect.minX, y: midY),
                                endPoint: CGPoint(x: tailRect.maxX, y: midY)
                            )
                        )
                    }

                    // 核心高亮发光光子（Photon Bead）
                    let photonRect = CGRect(x: currentX, y: midY - 3.5, width: 7, height: 7)
                    var photonContext = context
                    photonContext.addFilter(.shadow(color: health.color, radius: 4, x: 0, y: 0))
                    photonContext.fill(Path(ellipseIn: photonRect), with: .color(.white))
                }
            }
            .frame(height: 10)

            Spacer()
        }
        .frame(minWidth: 32, maxWidth: .infinity)
    }
}

// MARK: - 静态节点视图（遵循 Equatable，避免在 20fps 渲染时重复 Diff 与求值）
private struct PipelineNodeView: View, Equatable {
    let type: NetworkPipelineView.PipelineNodeType
    let health: NetworkPipelineView.NodeHealth
    let title: String
    let subtitle: String
    let onSelect: (() -> Void)?

    static func == (lhs: PipelineNodeView, rhs: PipelineNodeView) -> Bool {
        lhs.type == rhs.type &&
        lhs.health == rhs.health &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle
    }

    var body: some View {
        Button {
            onSelect?()
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

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 68)
        }
        .buttonStyle(.plain)
    }

    private func iconName(for type: NetworkPipelineView.PipelineNodeType) -> String {
        switch type {
        case .localMac: return "laptopcomputer"
        case .gateway: return "wifi.router"
        case .dns: return "server.rack"
        case .internet: return "globe.asia.australia.fill"
        }
    }
}
