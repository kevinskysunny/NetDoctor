import Foundation
import CoreWLAN
import Network
import SystemConfiguration

public final class SystemInterfaceCollector: InterfaceCollecting {
    private let rawSource: InterfaceRawDataProviding
    private let portSource: HardwarePortProviding
    private let linkCarrierSource: LinkCarrierProviding
    private let pathProvider: NetworkPathProviding?
    private let wifiClient: CWWiFiClient?
    private let injectedDefaultRouteNames: Set<String>?

    public init(
        pathProvider: NetworkPathProviding? = nil,
        wifiClient: CWWiFiClient? = CWWiFiClient.shared()
    ) {
        self.rawSource = GetifaddrsRawDataSource()
        self.portSource = SystemConfigHardwarePortSource()
        self.linkCarrierSource = SCDynamicStoreLinkCarrierSource()
        self.pathProvider = pathProvider
        self.wifiClient = wifiClient
        self.injectedDefaultRouteNames = nil
    }

    init(
        rawSource: InterfaceRawDataProviding,
        portSource: HardwarePortProviding,
        linkCarrierSource: LinkCarrierProviding = SCDynamicStoreLinkCarrierSource(),
        pathProvider: NetworkPathProviding? = nil,
        wifiClient: CWWiFiClient? = CWWiFiClient.shared(),
        defaultRouteNames: Set<String>? = nil
    ) {
        self.rawSource = rawSource
        self.portSource = portSource
        self.linkCarrierSource = linkCarrierSource
        self.pathProvider = pathProvider
        self.wifiClient = wifiClient
        self.injectedDefaultRouteNames = defaultRouteNames
    }

    /// 模块内部聚合记录：以接口名为键合并 flags / 地址；isSCPlaceholder 标记 SC 硬件端口补全占位。
    private struct AggregatedRecord {
        var flags: UInt32?
        var addresses: [IPAddressInfo] = []
        var isSCPlaceholder = false
    }

    public func collect() -> [InterfaceInfo] {
        guard rawSource.isAvailable else { return [] }

        let pathInterfaces = Dictionary(
            (pathProvider?.currentPath.interfaces ?? []).map { ($0.name, $0.kind) },
            uniquingKeysWith: { first, _ in first }
        )
        let wifiSSID = wifiClient?.interface()?.ssid()
        let defaultNames = injectedDefaultRouteNames
            ?? Set(SystemRouteCollector().collect().routes.compactMap(\.interfaceName))

        let hardwarePorts = portSource.fetch()
        var portKindLookup: [String: InterfaceKind] = [:]
        for port in hardwarePorts {
            if let bsdName = port.bsdName {
                portKindLookup[bsdName] = port.kind
            } else {
                portKindLookup[port.displayName] = port.kind
            }
        }

        // ① 聚合原始记录：登记全部出现过的接口名，AF_LINK 仅保留 name+flags，INET/INET6 追加地址
        var byName: [String: AggregatedRecord] = [:]
        for record in rawSource.fetch() {
            var entry = byName[record.name] ?? AggregatedRecord()
            if record.flags != nil {
                entry.flags = record.flags
            }
            if record.family == Int32(AF_INET) || record.family == Int32(AF_INET6),
               let addressString = record.addressString {
                let familyName = record.family == Int32(AF_INET) ? "IPv4" : "IPv6"
                entry.addresses.append(IPAddressInfo(family: familyName, address: addressString))
            }
            byName[record.name] = entry
        }

        // ② SC 硬件端口补全与类型确认
        for port in hardwarePorts {
            if let bsdName = port.bsdName {
                if byName[bsdName] == nil && port.kind != .loopback && port.kind != .other {
                    byName[bsdName] = AggregatedRecord(flags: nil, addresses: [], isSCPlaceholder: true)
                }
            } else if port.kind == .wired || port.kind == .wifi || port.kind == .cellular {
                let name = port.displayName
                if byName[name] == nil {
                    byName[name] = AggregatedRecord(flags: nil, addresses: [], isSCPlaceholder: true)
                }
            }
        }

        // ③.5 对物理网卡批量查询 SCDynamicStore Link Active（占位记录不查询）
        let physicalNames = byName.compactMap { (name, entry) -> String? in
            guard !entry.isSCPlaceholder else { return nil }
            let kind = pathInterfaces[name] ?? portKindLookup[name] ?? Self.inferKind(from: name)
            return (kind == .wired || kind == .wifi || kind == .cellular) ? name : nil
        }
        let carrierByName: [String: Bool?] = Dictionary(
            linkCarrierSource.fetch(interfaceNames: physicalNames).map { ($0.interfaceName, $0.active) },
            uniquingKeysWith: { first, _ in first }
        )

        // ④ 输出全部聚合键，三源 kind 融合，占位记录直置 .down
        return byName.keys
            .sorted { Self.interfaceSortValue($0) < Self.interfaceSortValue($1) }
            .map { name in
                let entry = byName[name] ?? AggregatedRecord()
                let kind = pathInterfaces[name] ?? portKindLookup[name] ?? Self.inferKind(from: name)
                let linkState: LinkState
                if entry.isSCPlaceholder {
                    linkState = .down
                } else {
                    linkState = resolveLinkState(
                        flags: entry.flags,
                        kind: kind,
                        carrierActive: carrierByName[name] ?? nil,
                        hasValidIP: !entry.addresses.isEmpty
                    )
                }
                let isActive = kind != .loopback && linkState == .up

                return InterfaceInfo(
                    id: name,
                    name: name,
                    kind: kind,
                    isActive: isActive,
                    addresses: entry.addresses,
                    ssid: kind == .wifi ? wifiSSID : nil,
                    linkState: linkState,
                    isDefaultRouteInterface: defaultNames.contains(name)
                )
            }
    }

    private static func inferKind(from name: String) -> InterfaceKind {
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") {
            return .other
        }
        if name.hasPrefix("en") {
            return .wired
        }
        if name.hasPrefix("lo") {
            return .loopback
        }
        if name.hasPrefix("pdp_ip") || name.hasPrefix("ap") {
            return .cellular
        }
        return .other
    }

    private static func interfaceSortValue(_ name: String) -> String {
        if name == "en0" { return "000-en0" }
        if name.hasPrefix("en") { return "100-\(name)" }
        if name.hasPrefix("utun") { return "200-\(name)" }
        if name == "lo0" { return "900-lo0" }
        return "500-\(name)"
    }

}

public final class SystemDNSCollector: DNSCollecting {
    private let store: SCDynamicStore?

    public init(store: SCDynamicStore? = SCDynamicStoreCreate(nil, "NetDoctor" as CFString, nil, nil)) {
        self.store = store
    }

    public func collect() -> DNSSummary {
        guard let store else { return .empty }
        guard let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any] else {
            return .empty
        }

        let servers = (value["ServerAddresses"] as? [String]) ?? []
        let searchDomains = (value["SearchDomains"] as? [String]) ?? []
        let source = "SystemConfiguration Global DNS"
        return DNSSummary(
            resolverSource: source,
            servers: servers,
            searchDomains: searchDomains,
            timestamp: Date()
        )
    }
}

public final class SystemRouteCollector: RouteCollecting {
    private let store: SCDynamicStore?

    public init(store: SCDynamicStore? = SCDynamicStoreCreate(nil, "NetDoctor" as CFString, nil, nil)) {
        self.store = store
    }

    public func collect() -> RouteSummary {
        guard let store else { return .empty }
        let ipv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        let ipv6 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv6" as CFString) as? [String: Any]

        var routes: [RouteEntry] = []
        var primaryInterfaceName: String?
        var primaryServiceID: String?

        if let ipv4 {
            primaryInterfaceName = ipv4["PrimaryInterface"] as? String
            primaryServiceID = ipv4["PrimaryService"] as? String
            routes.append(
                RouteEntry(
                    id: "ipv4-default",
                    family: "IPv4",
                    destination: "0.0.0.0/0",
                    gateway: ipv4["Router"] as? String,
                    interfaceName: primaryInterfaceName,
                    isDefault: true
                )
            )
        }

        if let ipv6, let router = ipv6["Router"] as? String, !router.isEmpty {
            let interfaceName = ipv6["PrimaryInterface"] as? String
            routes.append(
                RouteEntry(
                    id: "ipv6-default",
                    family: "IPv6",
                    destination: "::/0",
                    gateway: router,
                    interfaceName: interfaceName,
                    isDefault: true
                )
            )
        }

        return RouteSummary(
            routes: routes,
            primaryServiceID: primaryServiceID,
            primaryInterfaceName: primaryInterfaceName
        )
    }
}
