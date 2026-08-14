import Foundation

public protocol NetworkPathProviding: AnyObject {
    var currentPath: NetworkPathInfo { get }
    func start(onUpdate: @escaping (NetworkPathInfo) -> Void)
    func stop()
}

public protocol InterfaceCollecting {
    func collect() -> [InterfaceInfo]
}

public protocol DNSCollecting {
    func collect() -> DNSSummary
}

public protocol RouteCollecting {
    func collect() -> RouteSummary
}

public protocol ReachabilityProbing {
    func probe(
        endpoints: [ReachabilityEndpoint],
        attemptsPerEndpoint: Int,
        timeout: TimeInterval
    ) async -> [ReachabilityProbe]
}

public protocol EventRecording {
    func append(_ event: TimelineEvent)
}

public protocol DiagnosticEngineControlling: AnyObject {
    var currentPath: NetworkPathInfo { get }
    func start()
    func stop()
    func performCheck(
        endpoints: [ReachabilityEndpoint],
        attemptsPerEndpoint: Int,
        timeout: TimeInterval
    ) async -> DiagnosisReport
}
