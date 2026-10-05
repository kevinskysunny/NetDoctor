import NetworkCore
import SwiftUI

struct DNSRouteView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: RouteFilter = .all
    @State private var copiedAddress: String? = nil

    enum RouteFilter: String, CaseIterable, Identifiable {
        case all
        case defaultGateway
        case ipv4
        case ipv6

        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let report = model.report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // 1. DNS 智能解析枢纽舱 (DNS Resolver Hub)
                        dnsSection(report.dns)

                        Divider()

                        // 2. 路由高速公路 (Routing Expressway)
                        routeSection(report.routes)
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(model.text("dnsRoute.notChecked"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(model.text("detail.tab.dnsRoute"))
    }

    // MARK: - DNS 智能解析区
    @ViewBuilder
    private func dnsSection(_ dns: DNSSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header 标题栏
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.purple)

                Text(model.text("dnsRoute.dns.telemetryTitle"))
                    .font(.headline.weight(.semibold))

                Text(model.text("dnsRoute.dns.telemetryDetail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // 解析来源胶囊
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 6, height: 6)
                    Text(dns.resolverSource)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.purple.opacity(0.25), lineWidth: 1))

                // 系统设置 DNS 直达按钮
                Button {
                    SystemSettingsNavigator.open(.dns)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .medium))
                        Text(model.text("action.openSettings.dns"))
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Color.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(model.text("action.openSettings.dns"))
            }

            // 搜索域信息标签
            if !dns.searchDomains.isEmpty {
                HStack(spacing: 6) {
                    Text(model.text("dnsRoute.dns.domainChips") + ":")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    ForEach(dns.searchDomains, id: \.self) { domain in
                        Text(domain)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }

            // DNS 服务器卡片网格
            if dns.servers.isEmpty {
                Text(model.text("dnsRoute.noServers"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(Array(dns.servers.enumerated()), id: \.element) { index, server in
                        DNSServerCard(
                            server: server,
                            isPrimary: index == 0,
                            copiedAddress: $copiedAddress,
                            model: model
                        )
                    }
                }
            }
        }
    }

    // MARK: - 路由高速公路区
    @ViewBuilder
    private func routeSection(_ routesSummary: RouteSummary) -> some View {
        let allRoutes = routesSummary.routes
        let filteredRoutes = filterRoutes(allRoutes)

        VStack(alignment: .leading, spacing: 14) {
            // Header 标题栏
            HStack(spacing: 8) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.cyan)

                Text(model.text("dnsRoute.route.telemetryTitle"))
                    .font(.headline.weight(.semibold))

                Text(model.text("dnsRoute.route.telemetryDetail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(model.text("dnsRoute.routesCount", allRoutes.count))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            // 1. 主干默认网关置顶 Hero 卡片（若存在）
            if let defaultRoute = allRoutes.first(where: { $0.isDefault }) {
                DefaultRouteHeroCard(
                    route: defaultRoute,
                    copiedAddress: $copiedAddress,
                    model: model
                )
            }

            // 2. 路由多维分类过滤胶囊
            HStack(spacing: 8) {
                ForEach(RouteFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(filterTitle(filter))
                                .font(.system(size: 12, weight: selectedFilter == filter ? .semibold : .regular))
                            Text("\(filterCount(filter, in: allRoutes))")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    selectedFilter == filter ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedFilter == filter ? Color.cyan.opacity(0.18) : Color.clear,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedFilter == filter ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .foregroundStyle(selectedFilter == filter ? Color.cyan : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 3. 路由条目高速流转列表
            if filteredRoutes.isEmpty {
                Text(model.text("dnsRoute.noRoutes"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredRoutes) { route in
                        RouteExpresswayCard(
                            route: route,
                            copiedAddress: $copiedAddress,
                            model: model
                        )
                    }
                }
            }
        }
    }

    private func filterRoutes(_ routes: [RouteEntry]) -> [RouteEntry] {
        switch selectedFilter {
        case .all:
            return routes
        case .defaultGateway:
            return routes.filter { $0.isDefault }
        case .ipv4:
            return routes.filter { $0.family.contains("4") || !$0.family.contains("6") }
        case .ipv6:
            return routes.filter { $0.family.contains("6") }
        }
    }

    private func filterTitle(_ filter: RouteFilter) -> String {
        switch filter {
        case .all: return model.text("dnsRoute.route.filter.all")
        case .defaultGateway: return model.text("dnsRoute.route.filter.default")
        case .ipv4: return model.text("dnsRoute.route.filter.ipv4")
        case .ipv6: return model.text("dnsRoute.route.filter.ipv6")
        }
    }

    private func filterCount(_ filter: RouteFilter, in routes: [RouteEntry]) -> Int {
        switch filter {
        case .all: return routes.count
        case .defaultGateway: return routes.filter { $0.isDefault }.count
        case .ipv4: return routes.filter { $0.family.contains("4") || !$0.family.contains("6") }.count
        case .ipv6: return routes.filter { $0.family.contains("6") }.count
        }
    }
}

// MARK: - DNS 服务器卡片（含权威 DNS 识别与一键复制）
struct DNSServerCard: View {
    let server: String
    let isPrimary: Bool
    @Binding var copiedAddress: String?
    @ObservedObject var model: AppModel
    @State private var isHovered = false

    private var isCopied: Bool {
        copiedAddress == server
    }

    var body: some View {
        let provider = Self.detectProvider(server)

        VStack(alignment: .leading, spacing: 10) {
            // 顶部：首选/备用标识 + 提供商勋章
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isPrimary ? Color.purple : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(isPrimary ? model.text("dnsRoute.dns.primary") : model.text("dnsRoute.dns.secondary"))
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background((isPrimary ? Color.purple : Color.secondary).opacity(0.12), in: Capsule())
                .foregroundStyle(isPrimary ? Color.purple : Color.secondary)

                Spacer()

                // 提供商识别勋章
                HStack(spacing: 4) {
                    Image(systemName: provider.icon)
                        .font(.system(size: 10))
                    Text(model.text(provider.l10nKey))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(provider.color.opacity(0.12), in: Capsule())
                .foregroundStyle(provider.color)
            }

            // IP 地址与协议芯片
            HStack(alignment: .center, spacing: 8) {
                Text(server)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .textSelection(.enabled)

                Spacer()

                // 一键轻触复制按钮
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(server, forType: .string)
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        copiedAddress = server
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedAddress == server {
                            withAnimation { copiedAddress = nil }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 10))
                        if isCopied {
                            Text(model.text("dnsRoute.route.copied"))
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
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isHovered ? Color.purple.opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }

    static func detectProvider(_ ip: String) -> (l10nKey: String, icon: String, color: Color) {
        if ip == "8.8.8.8" || ip == "8.8.4.4" || ip.starts(with: "2001:4860:") {
            return ("dnsRoute.dns.provider.google", "globe", .blue)
        } else if ip == "1.1.1.1" || ip == "1.0.0.1" || ip.starts(with: "2606:4700:") {
            return ("dnsRoute.dns.provider.cloudflare", "bolt.shield", .orange)
        } else if ip == "223.5.5.5" || ip == "223.6.6.6" || ip.starts(with: "2400:3200:") {
            return ("dnsRoute.dns.provider.alibaba", "cloud", .cyan)
        } else if ip == "114.114.114.114" || ip == "114.114.115.115" {
            return ("dnsRoute.dns.provider.onedns", "network", .purple)
        } else if ip == "9.9.9.9" || ip == "149.112.112.112" {
            return ("dnsRoute.dns.provider.quad9", "checkmark.shield", .mint)
        } else if isPrivateIPv4(ip) || ip.starts(with: "fe80:") {
            return ("dnsRoute.dns.provider.local", "house.fill", .green)
        }
        return ("dnsRoute.dns.provider.public", "server.rack", .secondary)
    }

    static func isPrivateIPv4(_ ip: String) -> Bool {
        if ip.starts(with: "192.168.") || ip.starts(with: "10.") {
            return true
        }
        if ip.starts(with: "172.") {
            let octets = ip.split(separator: ".")
            if octets.count >= 2, let second = Int(octets[1]), 16...31 ~= second {
                return true
            }
        }
        return false
    }
}

// MARK: - 主干默认网关置顶 Hero 卡片
struct DefaultRouteHeroCard: View {
    let route: RouteEntry
    @Binding var copiedAddress: String?
    @ObservedObject var model: AppModel
    @State private var isHovered = false

    private var isCopied: Bool {
        copiedAddress == route.gateway
    }

    var body: some View {
        HStack(spacing: 16) {
            // 左侧发光图标指示
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.88, blue: 0.5).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.88, blue: 0.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.text("dnsRoute.route.defaultHeroTitle"))
                        .font(.headline.weight(.bold))

                    Text("0.0.0.0/0")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text(route.family)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.cyan.opacity(0.12), in: Capsule())
                }

                Text(model.text("dnsRoute.route.defaultHeroDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    if let gw = route.gateway {
                        HStack(spacing: 4) {
                            Text(model.text("dnsRoute.gateway") + ":")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(gw)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.2, green: 0.88, blue: 0.5))
                        }
                    }

                    if let iface = route.interfaceName {
                        HStack(spacing: 4) {
                            Text(model.text("dnsRoute.interface") + ":")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(iface)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // 复制网关按钮
            if let gw = route.gateway {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(gw, forType: .string)
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        copiedAddress = gw
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedAddress == gw {
                            withAnimation { copiedAddress = nil }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text(isCopied ? model.text("dnsRoute.route.copied") : gw)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(isCopied ? Color.green : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            Color(red: 0.2, green: 0.88, blue: 0.5).opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.2, green: 0.88, blue: 0.5).opacity(0.35), lineWidth: 1.2)
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 路由条目高速流转卡片（Next-Hop Flow Card）
struct RouteExpresswayCard: View {
    let route: RouteEntry
    @Binding var copiedAddress: String?
    @ObservedObject var model: AppModel
    @State private var isHovered = false

    private var isCopied: Bool {
        copiedAddress == (route.gateway ?? route.destination)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 协议家族胶囊
            Text(route.family)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(route.family.contains("6") ? Color.orange : Color.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background((route.family.contains("6") ? Color.orange : Color.cyan).opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            // 1. 目标网段 (Destination)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.text("dnsRoute.route.destination"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(route.destination)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(minWidth: 110, alignment: .leading)

            // 2. 下一跳箭头 (Next-Hop Flow)
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.cyan.opacity(0.7))
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
            }
            .frame(width: 40)

            // 3. 网关 (Gateway)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.text("dnsRoute.route.nextHop"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(route.gateway ?? "Direct Link")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(route.gateway != nil ? Color(red: 0.2, green: 0.88, blue: 0.5) : Color.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 120, alignment: .leading)

            Spacer()

            // 4. 出口网卡 (Interface)
            if let iface = route.interfaceName {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                    Text(iface)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.12), in: Capsule())
            }

            // 5. 复制按钮
            Button {
                let target = route.gateway ?? route.destination
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(target, forType: .string)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    copiedAddress = target
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedAddress == target {
                        withAnimation { copiedAddress = nil }
                    }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(isCopied ? Color.green : Color.secondary)
                    .padding(5)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help(model.text("common.copyTarget", route.gateway ?? route.destination))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06), lineWidth: isHovered ? 1.2 : 1)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}