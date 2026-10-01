import Foundation

/// 链路状态纯函数：决策①「物理硬件网卡缺失 IFF_RUNNING → 一律 .down」的唯一落点。
/// - `flags == nil`（读取失败异常边界）→ `.unknown`
/// - 物理 kind（.wired/.wifi/.cellular）：`(isUp && isRunning) ? .up : .down`
/// - 非物理（.loopback/.other）：保持宽松语义（isUp&&isRunning→up，!isUp&&!isRunning→down，其余→unknown）
func resolveLinkState(flags: UInt32?, kind: InterfaceKind) -> LinkState {
    guard let flags else { return .unknown }
    let isUp = (flags & UInt32(IFF_UP)) != 0
    let isRunning = (flags & UInt32(IFF_RUNNING)) != 0
    switch kind {
    case .wired, .wifi, .cellular:
        return (isUp && isRunning) ? .up : .down
    case .loopback, .other:
        if isUp && isRunning { return .up }
        if !isUp && !isRunning { return .down }
        return .unknown
    }
}