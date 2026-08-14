import NetworkCore
import SwiftUI

struct DetailView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            OverviewView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.overview"), systemImage: "gauge.with.dots.needle.50percent")
                }

            InterfacesView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.interfaces"), systemImage: "network")
                }

            DNSRouteView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.dnsRoute"), systemImage: "point.3.filled.connected.trianglepath.dotted")
                }

            ReachabilityView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.reachability"), systemImage: "globe")
                }

            TimelineView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.timeline"), systemImage: "clock")
                }

            SettingsView(model: model)
                .tabItem {
                    Label(model.text("detail.tab.settings"), systemImage: "gearshape")
                }
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
    }
}

private struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.text("overview.title"))
                            .font(.largeTitle.bold())
                        Text(model.summaryText)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let report = model.report {
                        HealthBadge(grade: report.health, title: model.text(for: report.health))
                    } else {
                        HealthBadge(grade: .checking, title: model.text("status.checking"))
                    }
                }

                if let report = model.report {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricCard(
                            title: model.text("overview.path"),
                            value: model.text(for: report.path.status),
                            detail: report.path.isConstrained ? model.text("overview.path.detailConstrained") : model.text("overview.path.detailNormal"),
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                        MetricCard(
                            title: model.text("overview.activeInterfaces"),
                            value: "\(report.interfaces.filter { $0.isActive }.count)",
                            detail: report.interfaces.map(\.name).joined(separator: ", "),
                            systemImage: "network"
                        )
                        MetricCard(
                            title: model.text("overview.dnsServers"),
                            value: report.dns.servers.first ?? model.text("overview.notAvailable"),
                            detail: report.dns.servers.joined(separator: ", "),
                            systemImage: "server.rack"
                        )
                        MetricCard(
                            title: model.text("overview.internet"),
                            value: "\(report.reachability.filter { $0.status == .success }.count)/\(report.reachability.count)",
                            detail: model.text("overview.internet.detail"),
                            systemImage: "globe"
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.text("overview.summary"))
                            .font(.headline)
                        Text(report.summary)
                            .textSelection(.enabled)
                    }

                    if !report.advice.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.text("overview.advice"))
                                .font(.headline)
                            ForEach(report.advice) { advice in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: advice.severity.symbolName)
                                        .foregroundStyle(adviceColor(advice.severity))
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(advice.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(advice.message)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .padding(.vertical, 4)
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
                    model.text("timeline.empty.title"),
                    systemImage: "clock",
                    description: Text(model.text("timeline.empty.message"))
                )
            } else {
                List(model.timelineEvents.reversed()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(model.text(for: event.kind))
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
        .navigationTitle(model.text("detail.tab.timeline"))
    }
}
