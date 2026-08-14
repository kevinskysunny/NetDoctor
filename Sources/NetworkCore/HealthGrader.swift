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

    public func summary(
        grade: HealthGrade,
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> String {
        switch grade {
        case .checking:
            return "正在检查网络状态。"
        case .healthy:
            return "网络状态正常，外网探测可用。"
        case .warning:
            let reasons = warningReasons(path: path, dns: dns, routes: routes, reachability: reachability)
            return reasons.isEmpty ? "网络可用，但存在需要关注的信号。" : reasons.joined(separator: "；")
        case .critical:
            let reasons = criticalReasons(path: path, interfaces: interfaces, reachability: reachability)
            return reasons.isEmpty ? "网络不可用，请检查连接。" : reasons.joined(separator: "；")
        }
    }

    private func criticalReasons(
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        reachability: [ReachabilityProbe]
    ) -> [String] {
        var reasons: [String] = []
        if path.status != .available {
            reasons.append("网络路径不可用")
        }
        let active = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if active.isEmpty {
            reasons.append("未检测到活动接口")
        }
        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount == 0 {
                reasons.append("所有外网探测均失败")
            }
        }
        return reasons
    }

    private func warningReasons(
        path: NetworkPathInfo,
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe]
    ) -> [String] {
        var reasons: [String] = []
        if path.isConstrained {
            reasons.append("网络受限")
        }
        if !path.supportsDNS {
            reasons.append("当前路径不提供 DNS")
        }
        if dns.servers.isEmpty {
            reasons.append("未获取到 DNS 服务器")
        }
        if routes.routes.isEmpty {
            reasons.append("未获取到默认路由")
        }
        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount < reachability.count {
                reasons.append("部分外网探测失败")
            }
        }
        return reasons
    }
}
