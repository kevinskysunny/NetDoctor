import NetworkCore
import SwiftUI

struct DetailView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            OverviewView(model: model)
                .tabItem {
                    Label("概览", systemImage: "gauge.with.dots.needle.50percent")
                }

            InterfacesView(model: model)
                .tabItem {
                    Label("网络接口", systemImage: "network")
                }

            DNSRouteView(model: model)
                .tabItem {
                    Label("DNS 与路由", systemImage: "point.3.filled.connected.trianglepath.dotted")
                }

            ReachabilityView(model: model)
                .tabItem {
                    Label("外网探测", systemImage: "globe")
                }

            TimelineView(model: model)
                .tabItem {
                    Label("时间线", systemImage: "clock")
                }

            SettingsView(model: model)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("立即检查") {
                    Task {
                        await model.runCheck()
                    }
                }
                .disabled(model.isChecking)

                Button("导出支持包") {
                    model.exportSupportPackage()
                }
            }
        }
    }
}

private struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("网络体检")
                            .font(.largeTitle.bold())
                        Text(model.summaryText)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let report = model.report {
                        HealthBadge(grade: report.health)
                    } else {
                        HealthBadge(grade: .checking)
                    }
                }

                if let report = model.report {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricCard(
                            title: "网络路径",
                            value: report.path.status.displayName,
                            detail: report.path.isConstrained ? "网络受限" : "Network.framework 路径",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                        MetricCard(
                            title: "活动接口",
                            value: "\(report.interfaces.filter { $0.isActive }.count)",
                            detail: report.interfaces.map(\.name).joined(separator: ", "),
                            systemImage: "network"
                        )
                        MetricCard(
                            title: "DNS 服务器",
                            value: report.dns.servers.first ?? "未获取",
                            detail: report.dns.servers.joined(separator: ", "),
                            systemImage: "server.rack"
                        )
                        MetricCard(
                            title: "外网探测",
                            value: "\(report.reachability.filter { $0.status == .success }.count)/\(report.reachability.count)",
                            detail: "延迟和丢包为应用层近似",
                            systemImage: "globe"
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("当前说明")
                            .font(.headline)
                        Text(report.summary)
                            .textSelection(.enabled)
                    }
                } else {
                    ContentUnavailableView(
                        "尚未完成检查",
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text("点击“立即检查”开始只读网络体检。")
                    )
                }
            }
            .padding(24)
        }
    }
}

private struct InterfacesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let report = model.report, !report.interfaces.isEmpty {
                List(report.interfaces) { interface in
                    InterfaceRow(interface: interface)
                }
            } else {
                ContentUnavailableView(
                    "暂无接口数据",
                    systemImage: "network.slash",
                    description: Text("无网络时接口列表仍会显示本机只读状态。")
                )
            }
        }
        .navigationTitle("网络接口")
    }
}

private struct InterfaceRow: View {
    let interface: InterfaceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(interface.name, systemImage: interface.kind == .wifi ? "wifi" : "cable.connector")
                    .font(.headline)
                Spacer()
                Text(interface.kind.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                Text(interface.linkState.displayName)
                    .font(.caption)
                    .foregroundStyle(interface.linkState == .up ? Color.green : Color.secondary)
            }

            if interface.isDefaultRouteInterface {
                Label("默认路由接口", systemImage: "arrow.up.forward.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let ssid = interface.ssid {
                Label(ssid, systemImage: "wifi")
                    .font(.callout)
            }

            if interface.addresses.isEmpty {
                Text("无 IPv4/IPv6 地址")
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

private struct DNSRouteView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List {
            if let report = model.report {
                Section("DNS 解析器") {
                    LabeledContent("来源", value: report.dns.resolverSource)
                    if report.dns.servers.isEmpty {
                        Text("未获取到 DNS 服务器")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.dns.servers, id: \.self) { server in
                            Text(server)
                                .textSelection(.enabled)
                        }
                    }
                    if !report.dns.searchDomains.isEmpty {
                        LabeledContent("搜索域", value: report.dns.searchDomains.joined(separator: ", "))
                    }
                }

                Section("默认路由") {
                    if report.routes.routes.isEmpty {
                        Text("未获取到默认路由")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.routes.routes) { route in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(route.family, systemImage: "arrow.up.forward.circle")
                                    .font(.headline)
                                LabeledContent("目标", value: route.destination)
                                if let gateway = route.gateway {
                                    LabeledContent("网关", value: gateway)
                                }
                                if let interfaceName = route.interfaceName {
                                    LabeledContent("接口", value: interfaceName)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text("尚未完成检查")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("DNS 与路由")
    }
}

private struct ReachabilityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let report = model.report, !report.reachabilitySummaries.isEmpty {
                List(report.reachabilitySummaries) { summary in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(summary.endpointName)
                                .font(.headline)
                            Spacer()
                            Text("\(summary.successCount)/\(summary.attempts) 成功")
                                .font(.callout)
                                .foregroundStyle(summary.failureCount == 0 ? Color.green : Color.orange)
                        }

                        HStack(spacing: 12) {
                            MetricLine(title: "丢包近似", value: summary.lossRate.formatted(.percent.precision(.fractionLength(0))))
                            MetricLine(title: "P50", value: Self.format(summary.percentiles.p50))
                            MetricLine(title: "P90", value: Self.format(summary.percentiles.p90))
                            MetricLine(title: "P95", value: Self.format(summary.percentiles.p95))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView(
                    "暂无外网探测结果",
                    systemImage: "globe",
                    description: Text("完整检查会并发探测公开 HTTPS/TCP 端点。")
                )
            }
        }
        .navigationTitle("外网探测")
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

private struct TimelineView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.timelineEvents.isEmpty {
                ContentUnavailableView(
                    "暂无本地事件",
                    systemImage: "clock",
                    description: Text("诊断记录只保存在本机。")
                )
            } else {
                List(model.timelineEvents.reversed()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.kind.displayName)
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("本地时间线")
    }
}
