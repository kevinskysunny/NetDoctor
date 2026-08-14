import Foundation
import Network

public final class NWPathMonitorProvider: NetworkPathProviding {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.networkconsolelite.pathmonitor")
    private let lock = NSLock()
    private var cachedPath = NetworkPathInfo.unknown
    private var updateHandler: ((NetworkPathInfo) -> Void)?

    public init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.cachedPath = Self.map(monitor.currentPath)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handle(path)
        }
    }

    public var currentPath: NetworkPathInfo {
        lock.lock()
        defer { lock.unlock() }
        return cachedPath
    }

    public func start(onUpdate: @escaping (NetworkPathInfo) -> Void) {
        lock.lock()
        updateHandler = onUpdate
        lock.unlock()
        monitor.start(queue: queue)
        onUpdate(Self.map(monitor.currentPath))
    }

    public func stop() {
        monitor.cancel()
        lock.lock()
        updateHandler = nil
        lock.unlock()
    }

    private func handle(_ path: NWPath) {
        let mapped = Self.map(path)
        lock.lock()
        cachedPath = mapped
        let handler = updateHandler
        lock.unlock()
        handler?(mapped)
    }

    static func map(_ path: NWPath) -> NetworkPathInfo {
        let interfaces = path.availableInterfaces.map {
            InterfaceDescriptor(name: $0.name, kind: map($0.type))
        }

        let status: NetworkStatus
        switch path.status {
        case .satisfied:
            status = .available
        case .unsatisfied:
            status = .unavailable
        case .requiresConnection:
            status = .unavailable
        @unknown default:
            status = .unknown
        }

        return NetworkPathInfo(
            status: status,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsDNS: path.supportsDNS,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            interfaces: interfaces
        )
    }

    static func map(_ type: NWInterface.InterfaceType) -> InterfaceKind {
        switch type {
        case .wifi:
            return .wifi
        case .wiredEthernet:
            return .wired
        case .cellular:
            return .cellular
        case .loopback:
            return .loopback
        case .other:
            return .other
        @unknown default:
            return .other
        }
    }
}
