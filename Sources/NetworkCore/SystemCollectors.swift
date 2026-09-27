import Foundation
import CoreWLAN
import Network
import SystemConfiguration

public final class SystemInterfaceCollector: InterfaceCollecting {
    private let pathProvider: NetworkPathProviding?
    private let wifiClient: CWWiFiClient?

    public init(
        pathProvider: NetworkPathProviding? = nil,
        wifiClient: CWWiFiClient? = CWWiFiClient.shared()
    ) {
        self.pathProvider = pathProvider
        self.wifiClient = wifiClient
    }

    public func collect() -> [InterfaceInfo] {
        let pathInterfaces = Dictionary(
            (pathProvider?.currentPath.interfaces ?? []).map { ($0.name, $0.kind) },
            uniquingKeysWith: { first, _ in first }
        )
        let wifiSSID = wifiClient?.interface()?.ssid()
        let defaultNames = Set(SystemRouteCollector().collect().routes.compactMap(\.interfaceName))

        var addressesByName: [String: [(family: String, address: String)]] = [:]
        var flagsByName: [String: UInt32] = [:]

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0 else {
            return []
        }
        defer { freeifaddrs(ifaddrPointer) }

        var current = ifaddrPointer
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard let namePointer = interface.ifa_name else { continue }
            let name = String(cString: namePointer)
            flagsByName[name] = interface.ifa_flags

            guard let addressPointer = interface.ifa_addr else { continue }
            let family = addressPointer.pointee.sa_family
            let familyName: String
            let addressString: String?

            if family == UInt8(AF_INET) {
                familyName = "IPv4"
                addressString = Self.ipv4String(addressPointer)
            } else if family == UInt8(AF_INET6) {
                familyName = "IPv6"
                addressString = Self.ipv6String(addressPointer)
            } else {
                continue
            }

            guard let addressString else { continue }
            addressesByName[name, default: []].append((familyName, addressString))
        }

        return addressesByName.keys
            .sorted { Self.interfaceSortValue($0) < Self.interfaceSortValue($1) }
            .map { name in
                let kind = pathInterfaces[name] ?? Self.inferKind(from: name)
        let flags = Int32(bitPattern: flagsByName[name] ?? 0)
                let isUp = (flags & IFF_UP) != 0
                let isRunning = (flags & IFF_RUNNING) != 0
                let linkState: LinkState
                if isUp && isRunning {
                    linkState = .up
                } else if isUp || isRunning {
                    linkState = .unknown
                } else {
                    linkState = .down
                }

                return InterfaceInfo(
                    id: name,
                    name: name,
                    kind: kind,
                    isActive: isUp,
                    addresses: addressesByName[name, default: []].map {
                        IPAddressInfo(family: $0.family, address: $0.address)
                    },
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

    private static func ipv4String(_ pointer: UnsafePointer<sockaddr>) -> String? {
        let addr = pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var address = addr.sin_addr
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }

    private static func ipv6String(_ pointer: UnsafePointer<sockaddr>) -> String? {
        let addr = pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var address = addr.sin6_addr
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else {
            return nil
        }
        return String(cString: buffer)
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
