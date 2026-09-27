import AppKit
import NetworkCore
import SwiftUI

/// 4 节点网络拓扑链路管线（CoreAnimation GPU 硬件加速，稳态 0% CPU 功耗）
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
        HStack(spacing: 0) {
            PipelineNodeView(
                type: .localMac,
                health: macHealth,
                title: title(for: .localMac),
                subtitle: subtitle(for: .localMac),
                onSelect: { onSelectNode?(.localMac) }
            )

            pipelineSegment(
                isActive: isLink1Active,
                health: isLink1Active ? .normal : (macHealth == .critical ? .critical : .warning),
                phaseOffset: 0.0
            )

            PipelineNodeView(
                type: .gateway,
                health: gatewayHealth,
                title: title(for: .gateway),
                subtitle: subtitle(for: .gateway),
                onSelect: { onSelectNode?(.gateway) }
            )

            pipelineSegment(
                isActive: isLink2Active,
                health: isLink2Active ? .normal : (gatewayHealth == .critical ? .critical : .warning),
                phaseOffset: 0.33
            )

            PipelineNodeView(
                type: .dns,
                health: dnsHealth,
                title: title(for: .dns),
                subtitle: subtitle(for: .dns),
                onSelect: { onSelectNode?(.dns) }
            )

            pipelineSegment(
                isActive: isLink3Active,
                health: isLink3Active ? .normal : (dnsHealth == .critical ? .critical : .warning),
                phaseOffset: 0.66
            )

            PipelineNodeView(
                type: .internet,
                health: internetHealth,
                title: title(for: .internet),
                subtitle: subtitle(for: .internet),
                onSelect: { onSelectNode?(.internet) }
            )
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

    private func pipelineSegment(isActive: Bool, health: NodeHealth, phaseOffset: Double) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 21)

            PipelineSegmentRepresentable(
                isActive: isActive,
                health: health,
                phaseOffset: phaseOffset,
                isChecking: isChecking,
                isVisible: isVisible
            )
            .frame(height: 10)

            Spacer()
        }
        .frame(minWidth: 32, maxWidth: .infinity)
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

// MARK: - 节点连接管道 CoreAnimation 硬件加速视图（GPU 离屏调度，0% CPU 开销）
private struct PipelineSegmentRepresentable: NSViewRepresentable {
    let isActive: Bool
    let health: NetworkPipelineView.NodeHealth
    let phaseOffset: Double
    let isChecking: Bool
    let isVisible: Bool

    func makeNSView(context: Context) -> PipelineSegmentNSView {
        let view = PipelineSegmentNSView()
        view.update(
            isActive: isActive,
            health: health,
            phaseOffset: phaseOffset,
            isChecking: isChecking,
            isVisible: isVisible
        )
        return view
    }

    func updateNSView(_ nsView: PipelineSegmentNSView, context: Context) {
        nsView.update(
            isActive: isActive,
            health: health,
            phaseOffset: phaseOffset,
            isChecking: isChecking,
            isVisible: isVisible
        )
    }
}

private final class PipelineSegmentNSView: NSView {
    private let trackLayer = CALayer()
    private let particleContainerLayer = CALayer()
    private let tailLayer = CAGradientLayer()
    private let photonLayer = CALayer()

    private var currentIsActive: Bool = false
    private var currentHealth: NetworkPipelineView.NodeHealth = .normal
    private var currentPhaseOffset: Double = 0
    private var currentIsChecking: Bool = false
    private var currentIsVisible: Bool = true
    private var lastBounds: NSRect = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayers()
    }

    private func setupLayers() {
        guard let layer else { return }

        // Track
        trackLayer.cornerRadius = 1.25
        layer.addSublayer(trackLayer)

        // Particle container
        particleContainerLayer.opacity = 0
        layer.addSublayer(particleContainerLayer)

        // Tail
        tailLayer.startPoint = CGPoint(x: 0, y: 0.5)
        tailLayer.endPoint = CGPoint(x: 1, y: 0.5)
        tailLayer.cornerRadius = 1.25
        particleContainerLayer.addSublayer(tailLayer)

        // Photon bead
        photonLayer.cornerRadius = 3.5
        photonLayer.backgroundColor = NSColor.white.cgColor
        photonLayer.shadowColor = NSColor.white.cgColor
        photonLayer.shadowOpacity = 0.95
        photonLayer.shadowRadius = 4
        photonLayer.shadowOffset = .zero
        particleContainerLayer.addSublayer(photonLayer)
    }

    func update(
        isActive: Bool,
        health: NetworkPipelineView.NodeHealth,
        phaseOffset: Double,
        isChecking: Bool,
        isVisible: Bool
    ) {
        let needsRestart = (self.currentIsActive != isActive ||
                            self.currentHealth != health ||
                            self.currentIsChecking != isChecking ||
                            self.currentIsVisible != isVisible)

        self.currentIsActive = isActive
        self.currentHealth = health
        self.currentPhaseOffset = phaseOffset
        self.currentIsChecking = isChecking
        self.currentIsVisible = isVisible

        applyColors()
        if needsRestart {
            layoutAndAnimate()
        }
    }

    override func layout() {
        super.layout()
        if bounds != lastBounds {
            lastBounds = bounds
            layoutAndAnimate()
        }
    }

    private func applyColors() {
        let nsColor = NSColor(currentHealth.color)
        trackLayer.backgroundColor = nsColor.withAlphaComponent(currentIsActive ? 0.35 : 0.15).cgColor
        photonLayer.shadowColor = nsColor.cgColor

        tailLayer.colors = [
            nsColor.withAlphaComponent(0.0).cgColor,
            nsColor.withAlphaComponent(0.45).cgColor,
            NSColor.white.withAlphaComponent(0.9).cgColor
        ]
    }

    private func layoutAndAnimate() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else {
            CATransaction.commit()
            return
        }

        let midY = h / 2
        trackLayer.frame = CGRect(x: 0, y: midY - 1.25, width: w, height: 2.5)

        particleContainerLayer.removeAnimation(forKey: "flow")

        guard currentIsActive && currentIsVisible && w > 10 else {
            particleContainerLayer.opacity = 0
            CATransaction.commit()
            return
        }

        let tailWidth: CGFloat = min(28, w * 0.45)
        let travelDist = max(0, w - 8)

        particleContainerLayer.frame = CGRect(x: 0, y: midY - 3.5, width: tailWidth + 7, height: 7)
        tailLayer.frame = CGRect(x: 0, y: 3.5 - 1.25, width: tailWidth, height: 2.5)
        photonLayer.frame = CGRect(x: tailWidth, y: 0, width: 7, height: 7)
        particleContainerLayer.opacity = 1

        let cycleDuration: Double = currentIsChecking ? 1.0 : 2.2
        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = -tailWidth
        anim.toValue = travelDist
        anim.duration = cycleDuration
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.timeOffset = CACurrentMediaTime() + (currentPhaseOffset * cycleDuration)

        particleContainerLayer.add(anim, forKey: "flow")
        CATransaction.commit()
    }
}

// MARK: - 静态节点视图（遵循 Equatable，避免在渲染时重复 Diff 与求值）
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
