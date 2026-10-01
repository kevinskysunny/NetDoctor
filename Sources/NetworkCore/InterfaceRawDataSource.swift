import Foundation

/// 与 getifaddrs 返回记录等价的语义化记录（测试可自由构造）。
/// `flags == nil` 表示 flags 读取失败（异常边界）。
struct InterfaceRawRecord: Sendable {
    let name: String
    let flags: UInt32?
    let family: Int32
    let addressString: String?

    init(name: String, flags: UInt32?, family: Int32, addressString: String?) {
        self.name = name
        self.flags = flags
        self.family = family
        self.addressString = addressString
    }
}

/// getifaddrs 数据源抽象：把系统调用与业务判定解耦，便于测试注入任意记录组合。
protocol InterfaceRawDataProviding {
    func fetch() -> [InterfaceRawRecord]
    /// 返回 getifaddrs 是否成功（false 表示调用失败 → collect 降级）
    var isAvailable: Bool { get }
}

/// 生产实现：封装 getifaddrs/freeifaddrs + ifa_next 链表遍历。
/// 仅 AF_INET/AF_INET6 且 inet_ntop 成功时填 addressString；
/// AF_LINK 及其他 family 记录 addressString 为 nil（禁止因无地址而跳过）。
struct GetifaddrsRawDataSource: InterfaceRawDataProviding {
    private(set) var isAvailable: Bool = true

    func fetch() -> [InterfaceRawRecord] {
        var records: [InterfaceRawRecord] = []
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0 else {
            return records
        }
        defer { freeifaddrs(ifaddrPointer) }

        var current = ifaddrPointer
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard let namePointer = interface.ifa_name else { continue }
            let name = String(cString: namePointer)

            let flags = interface.ifa_flags
            var family: Int32 = 0
            var addressString: String?
            if let addressPointer = interface.ifa_addr {
                let rawFamily = addressPointer.pointee.sa_family
                family = Int32(rawFamily)
                if rawFamily == UInt8(AF_INET) {
                    addressString = Self.ipv4String(addressPointer)
                } else if rawFamily == UInt8(AF_INET6) {
                    addressString = Self.ipv6String(addressPointer)
                }
            }

            records.append(
                InterfaceRawRecord(
                    name: name,
                    flags: flags,
                    family: family,
                    addressString: addressString
                )
            )
        }
        return records
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