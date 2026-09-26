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

// MARK: - Interfaces 标签页
private struct InterfacesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let report = model.report, !report.interfaces.isEmpty {
                List(report.interfaces) { interface in
                    InterfaceRow(interface: interface, model: model)
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

private struct InterfaceRow: View {
    let interface: InterfaceInfo
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(interface.name, systemImage: interface.kind == .wifi ? "wifi" : "cable.connector")
                    .font(.headline)
                Spacer()
                Text(model.text(for: interface.kind))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                Text(model.text(for: interface.linkState))
                    .font(.caption)
                    .foregroundStyle(interface.linkState == .up ? Color.green : Color.secondary)
            }

            if interface.isDefaultRouteInterface {
                Label(model.text("interfaces.defaultRoute"), systemImage: "arrow.up.forward.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let ssid = interface.ssid {
                Label(ssid, systemImage: "wifi")
                    .font(.callout)
            }

            if interface.addresses.isEmpty {
                Text(model.text("interfaces.noAddress"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(interface.addresses, id: \.address) { address in
                    HStack {
                        Text(address.family)
                            .foregroundStyle(.secondary)
                        Text(address.address)
                            .textSelection(.enabled)
                    }
                    .font(.caption.monospaced())
                }
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Timeline 标签页
private struct TimelineView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.timelineEvents.isEmpty {
                ContentUnavailableView(
                    model.text("timeline.empty.title"),
                    systemImage: "clock",
                    description: Text(model.text("timeline.empty.message"))
                )
            } else {
                List(model.timelineEvents.reversed()) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: symbolName(for: event.kind))
                            .foregroundStyle(tint(for: event.kind))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(model.text(for: event.kind))
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                Text(event.timestamp, format: timestampFormat(for: event.timestamp))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if !event.message.isEmpty {
                                Text(event.message)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(model.text("detail.tab.timeline"))
    }

    private func symbolName(for kind: TimelineEventKind) -> String {
        switch kind {
        case .pathChanged:
            return "arrow.triangle.swap"
        case .checkStarted:
            return "play.circle"
        case .checkFinished:
            return "checkmark.circle"
        case .exportCreated:
            return "square.and.arrow.up"
        case .diagnostic:
            return "stethoscope"
        }
    }

    private func tint(for kind: TimelineEventKind) -> Color {
        switch kind {
        case .pathChanged:
            return .orange
        case .checkStarted:
            return .blue
        case .checkFinished:
            return .green
        case .exportCreated:
            return .purple
        case .diagnostic:
            return .secondary
        }
    }

    private func timestampFormat(for date: Date) -> Date.FormatStyle {
        if Calendar.current.isDateInToday(date) {
            return .dateTime.hour().minute()
        }
        return .dateTime.month(.abbreviated).day().hour().minute()
    }
}
