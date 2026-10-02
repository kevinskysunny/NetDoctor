import NetworkCore

/// 接口筛选模式（internal）。
enum InterfaceFilter: Int, Sendable, CaseIterable {
    case physical, tunnels, all

    var l10nKey: String {
        switch self {
        case .physical: return "interfaces.filter.physical"
        case .tunnels:  return "interfaces.filter.tunnels"
        case .all:      return "interfaces.filter.all"
        }
    }
}

/// 筛选纯函数。
enum InterfaceFilterApplier {
    static func apply(_ filter: InterfaceFilter, to interfaces: [InterfaceInfo]) -> [InterfaceInfo] {
        switch filter {
        case .physical:
            return interfaces.filter { $0.kind == .wifi || $0.kind == .wired || $0.kind == .cellular }
        case .tunnels:
            return interfaces.filter { iface in
                let lower = iface.name.lowercased()
                return lower.hasPrefix("utun") || lower.hasPrefix("ipsec") || lower.hasPrefix("ppp")
            }
        case .all:
            return interfaces
        }
    }
}