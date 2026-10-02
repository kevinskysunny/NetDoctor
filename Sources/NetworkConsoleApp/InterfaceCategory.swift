import NetworkCore
import SwiftUI

/// 表现层接口细分分类（internal，不破坏底层 InterfaceKind 公共枚举）。
enum InterfaceCategory: Int, Sendable {
    case wifi, wired, cellular, loopback, tunnel, appleP2P, bridge, hardwareBus, systemTunnel, other
}

/// 分类解析纯函数：kind 直接映射 4 类 + name 前缀匹配 5 类 + 兜底 1 类。
enum InterfaceCategoryResolver {
    static func resolve(kind: InterfaceKind, name: String) -> InterfaceCategory {
        switch kind {
        case .wifi: return .wifi
        case .wired: return .wired
        case .cellular: return .cellular
        case .loopback: return .loopback
        case .other:
            let lower = name.lowercased()
            if lower.hasPrefix("utun") || lower.hasPrefix("ipsec") || lower.hasPrefix("ppp") {
                return .tunnel
            }
            if lower.hasPrefix("awdl") || lower.hasPrefix("llw") || lower.hasPrefix("nan") {
                return .appleP2P
            }
            if lower.hasPrefix("bridge") {
                return .bridge
            }
            if lower.hasPrefix("anpi") {
                return .hardwareBus
            }
            if lower.hasPrefix("gif") || lower.hasPrefix("stf") {
                return .systemTunnel
            }
            return .other
        }
    }
}

/// 分类样式映射：SF Symbol + 配色 + L10n key。
struct InterfaceCategoryStyle: Sendable {
    let sfSymbol: String
    let accentColor: Color
    let l10nKey: String

    static func style(for category: InterfaceCategory) -> InterfaceCategoryStyle {
        switch category {
        case .wifi:        return InterfaceCategoryStyle(sfSymbol: "wifi", accentColor: .cyan, l10nKey: "kind.wifi")
        case .wired:       return InterfaceCategoryStyle(sfSymbol: "cable.connector", accentColor: .blue, l10nKey: "kind.wired")
        case .cellular:    return InterfaceCategoryStyle(sfSymbol: "antenna.radiowaves.left.and.right", accentColor: .orange, l10nKey: "kind.cellular")
        case .loopback:    return InterfaceCategoryStyle(sfSymbol: "arrow.triangle.2.circlepath", accentColor: .secondary, l10nKey: "kind.loopback")
        case .tunnel:      return InterfaceCategoryStyle(sfSymbol: "lock.shield", accentColor: .indigo, l10nKey: "interfaces.category.tunnel")
        case .appleP2P:    return InterfaceCategoryStyle(sfSymbol: "airplayaudio", accentColor: .pink, l10nKey: "interfaces.category.appleP2P")
        case .bridge:      return InterfaceCategoryStyle(sfSymbol: "point.3.connected.trianglepath.dotted", accentColor: .teal, l10nKey: "interfaces.category.bridge")
        case .hardwareBus: return InterfaceCategoryStyle(sfSymbol: "cpu", accentColor: .gray, l10nKey: "interfaces.category.hardwareBus")
        case .systemTunnel: return InterfaceCategoryStyle(sfSymbol: "arrow.left.arrow.right", accentColor: .secondary, l10nKey: "kind.other")
        case .other:       return InterfaceCategoryStyle(sfSymbol: "network", accentColor: .indigo, l10nKey: "kind.other")
        }
    }
}