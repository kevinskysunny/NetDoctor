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
                    title: "确认网络已连接",
                    message: "先检查菜单栏 Wi-Fi 图标或网线连接。若已连接，可尝试关闭再打开 Wi-Fi，或切换到手机热点确认是否为本机网络问题。",
                    severity: .critical
                )
            )
        }

        let activeInterfaces = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if activeInterfaces.isEmpty {
            result.append(
                DiagnosticAdvice(
                    title: "启用网络接口",
                    message: "系统没有检测到活动接口。请打开“系统设置 > 网络”，确认 Wi-Fi 或以太网服务已启用。",
                    severity: .critical
                )
            )
        }

        if dns.servers.isEmpty {
            result.append(
                DiagnosticAdvice(
                    title: "检查 DNS 设置",
                    message: "当前没有读取到 DNS 服务器。可在“系统设置 > 网络 > 详细信息 > DNS”中检查，或联系网络管理员确认是否由 DHCP 下发。",
                    severity: .warning
                )
            )
        }

        if routes.routes.isEmpty {
            result.append(
                DiagnosticAdvice(
                    title: "检查默认路由或 VPN",
                    message: "没有获取到默认路由。若正在使用 VPN，可尝试断开后重新检查；否则请检查当前网络服务是否已获得地址和网关。",
                    severity: .warning
                )
            )
        }

        if path.isConstrained {
            result.append(
                DiagnosticAdvice(
                    title: "网络处于受限状态",
                    message: "系统报告网络受限，常见于手机热点、低数据模式或强制门户。请确认热点是否允许所有流量，并检查是否存在登录页面。",
                    severity: .warning
                )
            )
        }

        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount == 0 {
                result.append(
                    DiagnosticAdvice(
                        title: "外网不可达",
                        message: "所有公开端点均探测失败。请先检查路由器、光猫和 VPN，再查看防火墙是否拦截出站连接。",
                        severity: .critical
                    )
                )
            } else if successCount < reachability.count {
                result.append(
                    DiagnosticAdvice(
                        title: "部分外网站点不可达",
                        message: "部分公开端点失败，可能只是该站点被网络策略拦截或服务端异常。请优先看 Apple、Cloudflare 等主端点是否成功。",
                        severity: .warning
                    )
                )
            }

            let samples = reachability.compactMap(\.durationMilliseconds)
            if let p90 = LatencyPercentiles(samples: samples).p90, p90 > 800 {
                result.append(
                    DiagnosticAdvice(
                        title: "延迟偏高",
                        message: "P90 延迟超过 800 ms。建议暂停大流量下载或备份，优先使用 5 GHz Wi-Fi 或有线连接。",
                        severity: .warning
                    )
                )
            }
        }

        if result.isEmpty {
            result.append(
                DiagnosticAdvice(
                    title: "网络状态正常",
                    message: "当前没有发现需要处理的问题。若仍有网页打不开，可检查具体网站是否单独不可用。",
                    severity: .healthy
                )
            )
        }

        return result
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
