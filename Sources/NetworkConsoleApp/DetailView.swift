import Charts
import NetworkCore
import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview
    case interfaces
    case dnsRoute
    case reachability
    case timeline
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.50percent"
        case .interfaces: return "network"
        case .dnsRoute: return "point.3.filled.connected.trianglepath.dotted"
        case .reachability: return "globe"
        case .timeline: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct DetailView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab: DetailTab = .overview
    @State private var copiedToast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 现代化分段导航胶囊栏
            HStack(spacing: 6) {
                ForEach(DetailTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(tabTitle(tab))
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                                ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if copiedToast {
                    Text(model.text("detail.copiedCard"))
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button {
                    if model.copyDiagnosisCard() {
                        withAnimation { copiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedToast = false }
                        }
                    }
                } label: {
                    Label(model.text("detail.copyCard"), systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // 选项卡内容区
            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(
                        model: model,
                        isTabActive: selectedTab == .overview,
                        onSelectPipelineNode: { node in
                            switch node {
                            case .localMac:
                                selectedTab = .interfaces
                            case .gateway, .dns:
                                selectedTab = .dnsRoute
                            case .internet:
                                selectedTab = .reachability
                            }
                        }
                    )
                case .interfaces:
                    InterfacesView(model: model)
                case .dnsRoute:
                    DNSRouteView(model: model)
                case .reachability:
                    ReachabilityView(model: model)
                case .timeline:
                    TimelineView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(model.text("detail.checkNow")) {
                    Task {
                        await model.runCheck()
                    }
                }
                .disabled(model.isChecking)

                Button(model.text("detail.export")) {
                    model.exportSupportPackage()
                }
            }
        }
        .sensoryFeedback(.success, trigger: model.report?.timestamp)
    }

    private func tabTitle(_ tab: DetailTab) -> String {
        switch tab {
        case .overview: return model.text("detail.tab.overview")
        case .interfaces: return model.text("detail.tab.interfaces")
        case .dnsRoute: return model.text("detail.tab.dnsRoute")
        case .reachability: return model.text("detail.tab.reachability")
        case .timeline: return model.text("detail.tab.timeline")
        case .settings: return model.text("detail.tab.settings")
        }
    }
}

// MARK: - Overview 标签页（拓扑流光 + 评分环 + Bento）
private struct OverviewView: View {
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
                        showVerdict: true
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
                                onSelectNode: onSelectPipelineNode
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

// MARK: - Reachability 标签页（含 Swift Charts 延迟图表）
private struct ReachabilityView: View {
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

private struct MetricLine: View {
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

// MARK: - Interfaces 标签页（赛博物理网卡机架）
private struct InterfacesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let report = model.report, !report.interfaces.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 顶部遥测指示舱 (Interface Telemetry Pod)
                        InterfaceTelemetryPod(report: report, model: model)

                        // 2. 刀片机架卡片网格 (Blade Rack Cards)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 380), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(report.interfaces) { iface in
                                InterfaceBladeCard(interface: iface, model: model)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    model.text("interfaces.empty.title"),
                    systemImage: "network.slash",
                    description: Text(model.text("interfaces.empty.message"))
                )
            }
        }
        .navigationTitle(model.text("detail.tab.interfaces"))
    }
}

// MARK: - 接口遥测指标舱
private struct InterfaceTelemetryPod: View {
    let report: DiagnosisReport
    @ObservedObject var model: AppModel

    var body: some View {
        let activeCount = report.interfaces.filter { $0.isActive }.count
        let totalCount = report.interfaces.count
        let primaryUplink = report.interfaces.first(where: { $0.isDefaultRouteInterface })
        let hasIPv4 = report.interfaces.contains { $0.addresses.contains { $0.family == "IPv4" } }
        let hasIPv6 = report.interfaces.contains { $0.addresses.contains { $0.family == "IPv6" } }

        HStack(spacing: 14) {
            // 活动网卡
            telemetryItem(
                title: model.text("interfaces.telemetry.activeTitle"),
                value: "\(activeCount) / \(totalCount)",
                detail: model.text("interfaces.telemetry.activeDetail"),
                systemImage: "network",
                accentColor: .blue
            )

            Divider().frame(height: 32).opacity(0.3)

            // 主干出口
            telemetryItem(
                title: model.text("interfaces.telemetry.primaryTitle"),
                value: primaryUplink?.name ?? "—",
                detail: primaryUplink != nil ? model.text(for: primaryUplink!.kind) : model.text("interfaces.telemetry.none"),
                systemImage: "arrow.up.forward.circle.fill",
                accentColor: .cyan
            )

            Divider().frame(height: 32).opacity(0.3)

            // 双栈协议
            telemetryItem(
                title: model.text("interfaces.telemetry.dualStackTitle"),
                value: (hasIPv4 && hasIPv6) ? "IPv4 + IPv6" : (hasIPv4 ? "IPv4" : (hasIPv6 ? "IPv6" : "—")),
                detail: (hasIPv4 && hasIPv6) ? model.text("interfaces.telemetry.dualReady") : model.text("interfaces.telemetry.singleReady"),
                systemImage: "bolt.horizontal.fill",
                accentColor: .purple
            )
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func telemetryItem(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        accentColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 刀片网卡硬件模块卡片
private struct InterfaceBladeCard: View {
    let interface: InterfaceInfo
    @ObservedObject var model: AppModel

    @State private var isHovered = false
    @State private var copiedAddress: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部 Header：硬件图标 + 名称 + 芯片类型 + 主干徽章 + 物理 Link LED
            HStack(alignment: .center, spacing: 10) {
                // 硬件图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hardwareAccentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(hardwareAccentColor.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: hardwareIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hardwareAccentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(interface.name)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))

                        // 接口类型胶囊
                        Text(model.text(for: interface.kind))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.6), in: Capsule())

                        // 主干链路徽章 (Primary Uplink)
                        if interface.isDefaultRouteInterface {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text("PRIMARY")
                                    .font(.system(size: 9, weight: .heavy))
                            }
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }

                Spacer()

                // 物理链路状态指示灯 (Hardware Link LED)
                HStack(spacing: 5) {
                    Circle()
                        .fill(interface.linkState == .up ? Color(red: 0.2, green: 0.88, blue: 0.5) : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: interface.linkState == .up ? Color.green.opacity(0.7) : .clear,
                            radius: 3
                        )

                    Text(model.text(for: interface.linkState))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(interface.linkState == .up ? Color.green : Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (interface.linkState == .up ? Color.green : Color.secondary).opacity(0.1),
                    in: Capsule()
                )
            }

            Divider()
                .opacity(0.5)

            // Wi-Fi 专属无线电舱 (SSID + 天线)
            if let ssid = interface.ssid {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("SSID:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(ssid)
                        .font(.callout.weight(.semibold))
                        .textSelection(.enabled)
                    Spacer()
                    Text("802.11 Wi-Fi")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // IP 地址芯片列表 (IPv4 / IPv6 Chip Tags with instant copy)
            VStack(alignment: .leading, spacing: 8) {
                if interface.addresses.isEmpty {
                    Text(model.text("interfaces.noAddress"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(interface.addresses, id: \.address) { addr in
                        ipAddressChip(addr: addr)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHovered ? hardwareAccentColor.opacity(0.4) : Color.white.opacity(0.1),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func ipAddressChip(addr: IPAddressInfo) -> some View {
        let isIPv4 = addr.family == "IPv4"
        let chipColor = isIPv4 ? Color.blue : Color.purple
        let isCopied = copiedAddress == addr.address

        return HStack(spacing: 8) {
            // 协议版本徽章
            Text(addr.family)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(chipColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            // IP 地址文本
            Text(addr.address)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .textSelection(.enabled)

            Spacer()

            // 快捷复制按钮（带反馈）
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(addr.address, forType: .string)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    copiedAddress = addr.address
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        if copiedAddress == addr.address {
                            copiedAddress = nil
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10))
                    if isCopied {
                        Text(model.text("interfaces.copied"))
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundStyle(isCopied ? Color.green : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((isCopied ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var hardwareIconName: String {
        switch interface.kind {
        case .wifi: return "wifi"
        case .wired: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .other: return "network"
        }
    }

    private var hardwareAccentColor: Color {
        if interface.isDefaultRouteInterface {
            return .cyan
        }
        switch interface.kind {
        case .wifi: return .cyan
        case .wired: return .blue
        case .cellular: return .orange
        case .loopback: return .secondary
        case .other: return .indigo
        }
    }
}

// MARK: - DNS & Route 标签页
private struct DNSRouteView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List {
            if let report = model.report {
                Section(model.text("dnsRoute.section.dns")) {
                    LabeledContent(model.text("dnsRoute.source"), value: report.dns.resolverSource)
                    if report.dns.servers.isEmpty {
                        Text(model.text("dnsRoute.noServers"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.dns.servers, id: \.self) { server in
                            Text(server)
                                .textSelection(.enabled)
                        }
                    }
                    if !report.dns.searchDomains.isEmpty {
                        LabeledContent(model.text("dnsRoute.searchDomains"), value: report.dns.searchDomains.joined(separator: ", "))
                    }
                }

                Section(model.text("dnsRoute.section.routes")) {
                    if report.routes.routes.isEmpty {
                        Text(model.text("dnsRoute.noRoutes"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.routes.routes) { route in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(route.family, systemImage: "arrow.up.forward.circle")
                                    .font(.headline)
                                LabeledContent(model.text("dnsRoute.destination"), value: route.destination)
                                if let gateway = route.gateway {
                                    LabeledContent(model.text("dnsRoute.gateway"), value: gateway)
                                }
                                if let interfaceName = route.interfaceName {
                                    LabeledContent(model.text("dnsRoute.interface"), value: interfaceName)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text(model.text("dnsRoute.notChecked"))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(model.text("detail.tab.dnsRoute"))
    }
}

// MARK: - Timeline 标签页（赛博飞行记录仪）
private struct TimelineView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: TimelineFilter = .all

    enum TimelineFilter: String, CaseIterable, Identifiable {
        case all
        case pathChanges
        case checks
        case exports

        var id: String { rawValue }
    }

    private var filteredEvents: [TimelineEvent] {
        let events = model.timelineEvents.reversed()
        switch selectedFilter {
        case .all:
            return Array(events)
        case .pathChanges:
            return events.filter { $0.kind == .pathChanged }
        case .checks:
            return events.filter { $0.kind == .checkStarted || $0.kind == .checkFinished }
        case .exports:
            return events.filter { $0.kind == .exportCreated || $0.kind == .diagnostic }
        }
    }

    var body: some View {
        Group {
            if model.timelineEvents.isEmpty {
                ContentUnavailableView(
                    model.text("timeline.empty.title"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.text("timeline.empty.message"))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 顶部事件过滤胶囊栏 (Filter Chips)
                        filterBar

                        // 2. 垂直时空铁轨事件流 (Chronological Railway)
                        if filteredEvents.isEmpty {
                            ContentUnavailableView(
                                model.text("timeline.filterEmpty.title"),
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text(model.text("timeline.filterEmpty.message"))
                            )
                            .frame(maxWidth: .infinity, minHeight: 240)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                    TimelineRailwayItem(
                                        event: event,
                                        isLast: index == filteredEvents.count - 1,
                                        model: model
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(model.text("detail.tab.timeline"))
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(TimelineFilter.allCases) { filter in
                let count = count(for: filter)
                let isSelected = selectedFilter == filter

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filterIcon(filter))
                            .font(.system(size: 11, weight: .bold))

                        Text(filterTitle(filter))
                            .font(.caption.weight(.medium))

                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                (isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15)),
                                in: Capsule()
                            )
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? filterColor(filter) : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? filterColor(filter).opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func count(for filter: TimelineFilter) -> Int {
        switch filter {
        case .all:
            return model.timelineEvents.count
        case .pathChanges:
            return model.timelineEvents.filter { $0.kind == .pathChanged }.count
        case .checks:
            return model.timelineEvents.filter { $0.kind == .checkStarted || $0.kind == .checkFinished }.count
        case .exports:
            return model.timelineEvents.filter { $0.kind == .exportCreated || $0.kind == .diagnostic }.count
        }
    }

    private func filterTitle(_ filter: TimelineFilter) -> String {
        switch filter {
        case .all: return model.text("timeline.filter.all")
        case .pathChanges: return model.text("timeline.filter.pathChanges")
        case .checks: return model.text("timeline.filter.checks")
        case .exports: return model.text("timeline.filter.exports")
        }
    }

    private func filterIcon(_ filter: TimelineFilter) -> String {
        switch filter {
        case .all: return "tray.full.fill"
        case .pathChanges: return "arrow.triangle.swap"
        case .checks: return "stethoscope"
        case .exports: return "square.and.arrow.up.fill"
        }
    }

    private func filterColor(_ filter: TimelineFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .pathChanges: return .orange
        case .checks: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .exports: return .purple
        }
    }
}

// MARK: - 垂直发光时间轨道节点与事件卡片
private struct TimelineRailwayItem: View {
    let event: TimelineEvent
    let isLast: Bool
    @ObservedObject var model: AppModel

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 左侧：时空节点光圈 (Glowing Pip) + 垂直轨道 (Connecting Rail)
            VStack(spacing: 0) {
                // 节点发光圆环
                ZStack {
                    Circle()
                        .fill(nodeColor.opacity(0.18))
                        .frame(width: 30, height: 30)

                    Circle()
                        .stroke(nodeColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 30, height: 30)

                    Image(systemName: symbolName(for: event.kind))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(nodeColor)
                }
                .shadow(color: nodeColor.opacity(0.5), radius: 4)

                // 垂直连线导轨
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [nodeColor.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .frame(minHeight: 36)
                }
            }
            .frame(width: 30)

            // 右侧：时空胶囊卡片 (Event Capsule Card)
            VStack(alignment: .leading, spacing: 8) {
                // 卡片头部：分类徽标 + 相对时间 + 绝对时间戳
                HStack(alignment: .center, spacing: 8) {
                    Text(model.text(for: event.kind))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(nodeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(nodeColor.opacity(0.12), in: Capsule())

                    Text(relativeTimeString(for: event.timestamp))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(event.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                // 核心事件描述
                if !event.message.isEmpty {
                    Text(event.message)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }

                // 结构化黑匣子解密详情 (Arguments Inspection)
                if !event.arguments.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(event.arguments.enumerated()), id: \.offset) { _, arg in
                            Text(arg)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isHovered ? nodeColor.opacity(0.35) : Color.white.opacity(0.08),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onHover { isHovered = $0 }
            .padding(.bottom, isLast ? 0 : 10)
        }
    }

    private var nodeColor: Color {
        switch event.kind {
        case .pathChanged: return .orange
        case .checkStarted: return .blue
        case .checkFinished: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .exportCreated: return .purple
        case .diagnostic: return .cyan
        }
    }

    private func symbolName(for kind: TimelineEventKind) -> String {
        switch kind {
        case .pathChanged: return "arrow.triangle.swap"
        case .checkStarted: return "play.fill"
        case .checkFinished: return "checkmark"
        case .exportCreated: return "square.and.arrow.up"
        case .diagnostic: return "stethoscope"
        }
    }

    private func relativeTimeString(for date: Date) -> String {
        let now = Date()
        let interval = max(0, now.timeIntervalSince(date))
        let isZh = model.language.resolvedLanguage == .chinese

        if interval < 45 {
            return isZh ? "刚刚" : "Just now"
        } else if interval < 3600 {
            let mins = max(1, Int(interval / 60))
            return isZh ? "\(mins) 分钟前" : "\(mins)m ago"
        } else if Calendar.current.isDateInToday(date) {
            let hours = Int(interval / 3600)
            return isZh ? "\(hours) 小时前" : "\(hours)h ago"
        } else if Calendar.current.isDateInYesterday(date) {
            return (isZh ? "昨天 " : "Yesterday ") + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}
