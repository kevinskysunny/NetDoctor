import Foundation
import SystemConfiguration

/// SCNetworkInterface 语义化记录。`bsdName` 允许为 nil（未激活服务）。
struct HardwarePortRecord: Sendable {
    let bsdName: String?
    let displayName: String
    let kind: InterfaceKind

    init(bsdName: String?, displayName: String, kind: InterfaceKind) {
        self.bsdName = bsdName
        self.displayName = displayName
        self.kind = kind
    }
}

/// 硬件端口数据源抽象：抽象 SCNetworkInterfaceCopyAll()，测试可注入。
protocol HardwarePortProviding {
    func fetch() -> [HardwarePortRecord]
}

/// 生产实现：遍历 SCNetworkInterfaceCopyAll()，类型常量映射到物理 InterfaceKind。
/// 返回空/失败时 fetch() 返回 []，采集器静默降级（不抛异常）。
struct SystemConfigHardwarePortSource: HardwarePortProviding {
    func fetch() -> [HardwarePortRecord] {
        let interfaces = SCNetworkInterfaceCopyAll()
        let array = interfaces as? [SCNetworkInterface] ?? []
        return array.compactMap { port in
            guard let kind = Self.mapType(port) else { return nil }
            let bsdName = Self.bsdName(of: port)
            let displayName = Self.displayName(of: port) ?? bsdName ?? "interface"
            return HardwarePortRecord(bsdName: bsdName, displayName: displayName, kind: kind)
        }
    }

    private static func mapType(_ port: SCNetworkInterface) -> InterfaceKind? {
        guard let optionalType = SCNetworkInterfaceGetInterfaceType(port) else { return nil }
        let rawType = String(optionalType)
        if rawType == kSCNetworkInterfaceTypeIEEE80211 as String {
            return .wifi
        }
        if rawType == kSCNetworkInterfaceTypeEthernet as String {
            return .wired
        }
        if rawType == kSCNetworkInterfaceTypeWWAN as String {
            return .cellular
        }
        return nil
    }

    private static func bsdName(of port: SCNetworkInterface) -> String? {
        guard let name = SCNetworkInterfaceGetBSDName(port) else { return nil }
        return String(name)
    }

    private static func displayName(of port: SCNetworkInterface) -> String? {
        guard let name = SCNetworkInterfaceGetLocalizedDisplayName(port) else { return nil }
        return String(name)
    }
}