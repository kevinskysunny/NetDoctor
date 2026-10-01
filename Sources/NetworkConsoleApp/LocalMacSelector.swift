import Foundation
import NetworkCore

/// Local Mac 节点物理网卡选择器（internal 纯函数，无副作用）。
enum LocalMacSelector {
    static func isPhysicalKind(_ kind: InterfaceKind) -> Bool {
        kind == .wired || kind == .wifi || kind == .cellular
    }

    /// 物理活跃网卡（kind ∈ {wired, wifi, cellular} ∧ isActive ∧ linkState == .up），与 HealthGrader 同口径。
    static func physicalActive(_ interfaces: [InterfaceInfo]) -> [InterfaceInfo] {
        interfaces.filter { isPhysicalKind($0.kind) && $0.isActive && $0.linkState == .up }
    }

    /// 四段选择链：
    /// ① 物理活跃 ∩ 默认路由 → ② 物理活跃 → ③ 首个物理卡（含 down）→ ④ 首个非 loopback → ⑤ nil
    static func preferredInterface(in interfaces: [InterfaceInfo]) -> InterfaceInfo? {
        let physical = physicalActive(interfaces)
        if let defaultRoute = physical.first(where: { $0.isDefaultRouteInterface }) {
            return defaultRoute
        }
        if let active = physical.first {
            return active
        }
        if let anyPhysical = interfaces.first(where: { isPhysicalKind($0.kind) }) {
            return anyPhysical
        }
        return interfaces.first { $0.kind != .loopback }
    }
}