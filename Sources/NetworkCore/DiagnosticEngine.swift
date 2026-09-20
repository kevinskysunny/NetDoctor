import Foundation

public final class DiagnosticEngine: DiagnosticEngineControlling {
    private let pathProvider: NetworkPathProviding
    private let interfaceCollector: InterfaceCollecting
    private let dnsCollector: DNSCollecting
    private let routeCollector: RouteCollecting
    private let reachabilityProber: ReachabilityProbing
    private let eventStore: EventRecording
    private let grader: HealthGrader
    private let lock = NSLock()
    private var pathInfo: NetworkPathInfo

    public var onPathUpdate: ((NetworkPathInfo) -> Void)?
    public var onReport: ((DiagnosisReport) -> Void)?

    public init(
        pathProvider: NetworkPathProviding,
        interfaceCollector: InterfaceCollecting,
        dnsCollector: DNSCollecting,
        routeCollector: RouteCollecting,
        reachabilityProber: ReachabilityProbing,
        eventStore: EventRecording,
        grader: HealthGrader = HealthGrader()
    ) {
        self.pathProvider = pathProvider
        self.interfaceCollector = interfaceCollector
        self.dnsCollector = dnsCollector
        self.routeCollector = routeCollector
        self.reachabilityProber = reachabilityProber
        self.eventStore = eventStore
        self.grader = grader
        self.pathInfo = pathProvider.currentPath
    }

    public var currentPath: NetworkPathInfo {
        lock.lock()
        defer { lock.unlock() }
        return pathInfo
    }

    public func start() {
        pathProvider.start { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            let previous = self.pathInfo
            self.pathInfo = path
            self.lock.unlock()
            if path != previous {
                let interfaceKinds = path.interfaces.map(\.kind.rawValue).joined(separator: ",")
                self.eventStore.append(
                    TimelineEvent(
                        kind: .pathChanged,
                        message: "网络路径变化：\(path.status.displayName)",
                        arguments: [path.status.rawValue, interfaceKinds]
                    )
                )
            }
            self.onPathUpdate?(path)
        }
    }

    public func stop() {
        pathProvider.stop()
    }

    public func performCheck(
        endpoints: [ReachabilityEndpoint],
        attemptsPerEndpoint: Int,
        timeout: TimeInterval
    ) async -> DiagnosisReport {
        eventStore.append(
            TimelineEvent(
                kind: .checkStarted,
                message: "开始网络体检（\(endpoints.count) 个端点）",
                arguments: ["\(endpoints.count)"]
            )
        )
        let path = currentPath
        let interfaces = interfaceCollector.collect()
        let dns = dnsCollector.collect()
        let routes = routeCollector.collect()

        let probes = await reachabilityProber.probe(
            endpoints: endpoints,
            attemptsPerEndpoint: max(1, attemptsPerEndpoint),
            timeout: max(0.5, timeout)
        )

        let latency = probes.compactMap { probe -> LatencySample? in
            guard let duration = probe.durationMilliseconds else { return nil }
            return LatencySample(
                endpointID: probe.endpointID,
                endpointName: probe.endpointName,
                durationMilliseconds: duration,
                timestamp: probe.startedAt,
                success: probe.status == .success
            )
        }

        let grade = grader.grade(
            path: path,
            interfaces: interfaces,
            dns: dns,
            routes: routes,
            reachability: probes
        )
        let summary = grader.summary(
            grade: grade,
            path: path,
            interfaces: interfaces,
            dns: dns,
            routes: routes,
            reachability: probes
        )
        let advice = grader.advice(
            path: path,
            interfaces: interfaces,
            dns: dns,
            routes: routes,
            reachability: probes
        )
        let report = DiagnosisReport(
            timestamp: Date(),
            path: path,
            interfaces: interfaces,
            dns: dns,
            routes: routes,
            reachability: probes,
            latency: latency,
            advice: advice,
            health: grade,
            summary: summary
        )

        let successCount = probes.filter { $0.status == .success }.count
        let durations = probes.compactMap { probe -> Double? in
            guard probe.status == .success else { return nil }
            return probe.durationMilliseconds
        }
        let averageLatency = durations.isEmpty
            ? nil
            : durations.reduce(0, +) / Double(durations.count)
        let latencyText = averageLatency.map { String(format: "%.0fms", $0) } ?? "-"
        eventStore.append(
            TimelineEvent(
                kind: .checkFinished,
                message: "检查完成：\(grade.displayName)，\(successCount)/\(probes.count) 可达，平均延迟 \(latencyText)",
                arguments: [
                    grade.rawValue,
                    "\(successCount)",
                    "\(probes.count)",
                    latencyText,
                ]
            )
        )
        onReport?(report)
        return report
    }
}
