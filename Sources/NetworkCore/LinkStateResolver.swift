import Foundation

/// 链路状态纯函数：决策①②③的唯一落点。
/// - `flags == nil`（读取失败异常边界）→ `.unknown`
/// - 物理 kind（.wired/.wifi/.cellular）：
///   - `carrierActive` 非 nil（SCDynamicStore Link 有记录）：`!carrierActive → .down`；`carrierActive && isUp && isRunning → .up`，否则 `.down`
///   - `carrierActive == nil`（降级）：`.wired` 须 `hasValidIP && isUp && isRunning → .up` 否则 `.down`；`.wifi`/`.cellular` 按 flags `(isUp && isRunning) ? .up : .down`
/// - 非物理（.loopback/.other）：保持宽松语义（isUp&&isRunning→up，!isUp&&!isRunning→down，其余→unknown）
func resolveLinkState(
    flags: UInt32?,
    kind: InterfaceKind,
    carrierActive: Bool? = nil,
    hasValidIP: Bool = true
) -> LinkState {
    guard let flags else { return .unknown }
    let isUp = (flags & UInt32(IFF_UP)) != 0
    let isRunning = (flags & UInt32(IFF_RUNNING)) != 0
    switch kind {
    case .wired:
        if let carrierActive {
            return (carrierActive && isUp && isRunning) ? .up : .down
        }
        return (hasValidIP && isUp && isRunning) ? .up : .down
    case .wifi, .cellular:
        if let carrierActive {
            return (carrierActive && isUp && isRunning) ? .up : .down
        }
        return (isUp && isRunning) ? .up : .down
    case .loopback, .other:
        if isUp && isRunning { return .up }
        if !isUp && !isRunning { return .down }
        return .unknown
    }
}