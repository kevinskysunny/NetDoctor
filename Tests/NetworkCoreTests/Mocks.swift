import Foundation
@testable import NetworkCore

final class MockPathProvider: NetworkPathProviding {
    var currentPath: NetworkPathInfo
    private var updateHandler: ((NetworkPathInfo) -> Void)?

    init(path: NetworkPathInfo) {
        self.currentPath = path
    }

    func start(onUpdate: @escaping (NetworkPathInfo) -> Void) {
        updateHandler = onUpdate
        onUpdate(currentPath)
    }

    func stop() {
        updateHandler = nil
    }

    func emit(_ path: NetworkPathInfo) {
        currentPath = path
        updateHandler?(path)
    }
}

struct MockInterfaceCollector: InterfaceCollecting {
    var interfaces: [InterfaceInfo]

    func collect() -> [InterfaceInfo] {
        interfaces
    }
}

struct MockDNSCollector: DNSCollecting {
    var dns: DNSSummary

    func collect() -> DNSSummary {
        dns
    }
}

struct MockRouteCollector: RouteCollecting {
    var routes: RouteSummary

    func collect() -> RouteSummary {
        routes
    }
}

struct MockReachabilityProber: ReachabilityProbing {
    var result: [ReachabilityProbe]

    func probe(
        endpoints: [ReachabilityEndpoint],
        attemptsPerEndpoint: Int,
        timeout: TimeInterval
    ) async -> [ReachabilityProbe] {
        result
    }
}

final class MemoryEventStore: EventRecording {
    private(set) var events: [TimelineEvent] = []

    func append(_ event: TimelineEvent) {
        events.append(event)
    }
}
