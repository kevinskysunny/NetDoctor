import Foundation

public struct HealthGrader {
    public init() {}

    public func grade(
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> HealthGrade {
        if path.status != .available {
            return .critical
        }

        let activeInterfaces = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if activeInterfaces.isEmpty {
            return .critical
        }

        guard !reachability.isEmpty else {
            return .warning
        }

        let successCount = reachability.filter { $0.status == .success }.count
        if successCount == 0 {
            return .critical
        }

        let lossRate = Double(reachability.count - successCount) / Double(reachability.count)
        if lossRate > 0.5 {
            return .critical
        }

        if path.isConstrained || !path.supportsDNS || dns.servers.isEmpty || routes.routes.isEmpty || lossRate > 0 {
            return .warning
        }

        let samples = reachability.compactMap(\.durationMilliseconds)
        if let p90 = LatencyPercentiles(samples: samples).p90, p90 > 800 {
            return .warning
        }

        return .healthy
    }

    public func score(
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> Int {
        if path.status != .available {
            return 0
        }

        let activeInterfaces = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if activeInterfaces.isEmpty {
            return 0
        }

        // 1. 基础路径分 (最高 30 分)
        var pathScore = 30
        if path.isConstrained {
            pathScore = max(0, pathScore - 15)
        }

        // 2. DNS 配置分 (最高 25 分)
        var dnsScore = 25
        if dns.servers.isEmpty {
            dnsScore = 0
        } else if !path.supportsDNS {
            dnsScore = max(0, dnsScore - 10)
        }

        // 3. 网关路由分 (最高 20 分)
        let routeScore = routes.routes.isEmpty ? 0 : 20

        // 4. 公网探测与质量分 (最高 25 分)
        var probeScore = 20
        var allProbesFailed = false
        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount == 0 {
                probeScore = 0
                allProbesFailed = true
            } else {
                let successRatio = Double(successCount) / Double(reachability.count)
                var rawProbeScore = Int((25.0 * successRatio).rounded())

                let samples = reachability.compactMap(\.durationMilliseconds)
                if let p90 = LatencyPercentiles(samples: samples).p90 {
                    if p90 > 800 {
                        rawProbeScore -= 10
                    } else if p90 > 500 {
                        rawProbeScore -= 5
                    }
                }
                probeScore = max(0, min(25, rawProbeScore))
            }
        }

        var total = pathScore + dnsScore + routeScore + probeScore
        if allProbesFailed {
            total = min(total, 35)
        }
        return min(100, max(0, total))
    }

    public func verdict(
        grade: HealthGrade,
        score: Int,
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> VerdictCode {
        switch grade {
        case .checking:
            return .checking
        case .critical:
            if path.status != .available {
                return .offline
            }
            let active = interfaces.filter { $0.isActive && $0.kind != .loopback }
            if active.isEmpty {
                return .noInterface
            }
            if !reachability.isEmpty && reachability.filter({ $0.status == .success }).isEmpty {
                return .allProbesFailed
            }
            return .criticalDefault
        case .warning:
            if dns.servers.isEmpty || !path.supportsDNS {
                return .dnsSlow
            }
            if path.isConstrained {
                return .constrained
            }
            if !reachability.isEmpty {
                let successCount = reachability.filter { $0.status == .success }.count
                if successCount < reachability.count {
                    return .jitterLoss
                }
                let samples = reachability.compactMap(\.durationMilliseconds)
                if let p90 = LatencyPercentiles(samples: samples).p90, p90 > 500 {
                    return .highLatency
                }
            }
            return .warningDefault
        case .healthy:
            if score >= 95 {
                return .optimal
            } else {
                return .good
            }
        }
    }

    public func summary(
        grade: HealthGrade,
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> String {
        ""
    }

    public func advice(
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> [DiagnosticAdvice] {
        var result: [DiagnosticAdvice] = []

        if path.status != .available {
            result.append(
                DiagnosticAdvice(
                    code: .confirmConnection,
                    severity: .critical
                )
            )
        }

        let activeInterfaces = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if activeInterfaces.isEmpty {
            result.append(
                DiagnosticAdvice(
                    code: .enableInterface,
                    severity: .critical
                )
            )
        }

        if dns.servers.isEmpty {
            result.append(
                DiagnosticAdvice(
                    code: .checkDNS,
                    severity: .warning
                )
            )
        }

        if routes.routes.isEmpty {
            result.append(
                DiagnosticAdvice(
                    code: .checkRoute,
                    severity: .warning
                )
            )
        }

        if path.isConstrained {
            result.append(
                DiagnosticAdvice(
                    code: .constrained,
                    severity: .warning
                )
            )
        }

        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount == 0 {
                result.append(
                    DiagnosticAdvice(
                        code: .unreachable,
                        severity: .critical
                    )
                )
            } else if successCount < reachability.count {
                result.append(
                    DiagnosticAdvice(
                        code: .partialUnreachable,
                        severity: .warning
                    )
                )
            }

            let samples = reachability.compactMap(\.durationMilliseconds)
            if let p90 = LatencyPercentiles(samples: samples).p90, p90 > 800 {
                result.append(
                    DiagnosticAdvice(
                        code: .highLatency,
                        severity: .warning
                    )
                )
            }
        }

        if result.isEmpty {
            result.append(
                DiagnosticAdvice(
                    code: .healthy,
                    severity: .healthy
                )
            )
        }

        return result
    }
}
