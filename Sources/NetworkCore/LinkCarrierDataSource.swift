import Foundation
import SystemConfiguration

/// SCDynamicStore Link 载波记录。`active == nil` 表示无 Link 记录或 Active 字段异常，触发降级。
struct LinkCarrierRecord: Sendable {
    let interfaceName: String
    let active: Bool?
}

/// 载波数据源抽象：封装 SCDynamicStore `State:/Network/Interface/<name>/Link` 只读查询，测试可注入。
protocol LinkCarrierProviding {
    func fetch(interfaceNames: [String]) -> [LinkCarrierRecord]
    var isAvailable: Bool { get }
}

/// 生产实现：SCDynamicStoreCopyValue 只读查询 Link Active。
/// store 创建失败 → isAvailable == false、fetch() 返回 []，采集器静默降级。
struct SCDynamicStoreLinkCarrierSource: LinkCarrierProviding {
    private let store: SCDynamicStore?

    init() {
        self.store = SCDynamicStoreCreate(nil, "NetDoctor" as CFString, nil, nil)
    }

    var isAvailable: Bool { store != nil }

    func fetch(interfaceNames: [String]) -> [LinkCarrierRecord] {
        guard let store else { return [] }
        return interfaceNames.compactMap { name in
            let key = "State:/Network/Interface/\(name)/Link" as CFString
            guard let value = SCDynamicStoreCopyValue(store, key) else {
                return LinkCarrierRecord(interfaceName: name, active: nil)
            }
            let active = (value as? [String: Any])?["Active"] as? Bool
            return LinkCarrierRecord(interfaceName: name, active: active)
        }
    }
}