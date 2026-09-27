import AppKit
import Combine
import Foundation
import NetworkCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var report: DiagnosisReport?
    @Published private(set) var isChecking = false
    @Published private(set) var statusSymbolName: String = HealthGrade.checking.symbolName
    @Published private(set) var lastError: String?
    @Published private(set) var timelineEvents: [TimelineEvent] = []
    @Published var settings: AppSettings
    @Published var language: AppLanguage

    private let engine: DiagnosticEngine
    private let timelineStore: TimelineStore
    private let exporter = SupportPackageExporter()
    private var lastRawReport: DiagnosisReport?
    private var pathRefreshTask: Task<Void, Never>?
    private var periodicRefreshTask: Task<Void, Never>?
    private var systemLocaleCancellable: AnyCancellable?

    init(
        engine: DiagnosticEngine? = nil,
        timelineStore: TimelineStore? = nil
    ) {
        let loadedSettings = AppSettings.load()
        let pathProvider = NWPathMonitorProvider()
        let interfaceCollector = SystemInterfaceCollector(pathProvider: pathProvider)
        let dnsCollector = SystemDNSCollector()
        let routeCollector = SystemRouteCollector()
        let prober = URLSessionReachabilityProber()
        let store = timelineStore ?? TimelineStore()
        let resolvedEngine = engine ?? DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: interfaceCollector,
            dnsCollector: dnsCollector,
            routeCollector: routeCollector,
            reachabilityProber: prober,
            eventStore: store
        )

        self.settings = loadedSettings
        self.language = Self.loadLanguage()
        self.engine = resolvedEngine
        self.timelineStore = store

        configureEngine()
        resolvedEngine.start()
        refreshTimeline()
        startPeriodicRefresh()

        systemLocaleCancellable = NotificationCenter.default
            .publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.language == .system else { return }
                self.objectWillChange.send()
                if let last = self.lastRawReport {
                    self.report = self.localizedReport(last)
                }
                self.refreshTimeline()
            }

        Task {
            await runCheck(manual: false)
        }
    }

    private func updateStatusSymbol() {
        let next = isChecking ? HealthGrade.checking.symbolName : (report?.health.symbolName ?? "waveform.path.ecg")
        if statusSymbolName != next {
            statusSymbolName = next
        }
    }

    var statusTitle: String {
        if isChecking {
            return text("status.checking")
        }
        guard let report else {
            return text("status.notChecked")
        }
        return text(for: report.health)
    }

    var summaryText: String {
        if isChecking {
            return text("summary.checking")
        }
        guard let report else {
            return text("summary.notChecked")
        }
        switch report.health {
        case .checking:
            return text("summary.checking")
        case .healthy:
            return text("summary.healthy")
        case .warning:
            return text("summary.warning")
        case .critical:
            return text("summary.critical")
        }
    }

    var score: Int {
        report?.score ?? 100
    }

    var verdictText: String {
        if isChecking {
            return text("verdict.checking")
        }
        guard let report else {
            return text("verdict.notChecked")
        }
        return localizedVerdict(report.verdict)
    }

    var latestRTT: Double? {
        guard let report, !report.latency.isEmpty else { return nil }
        let valid = report.latency.filter { $0.success }.map(\.durationMilliseconds)
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }

    @discardableResult
    func copyDiagnosisCard() -> Bool {
        guard let report else { return false }
        return CyberDiagnosisCardView.copyToPasteboard(
            report: report,
            appVersion: Self.appVersion,
            appBuild: Self.appBuild,
            language: effectiveLanguage
        )
    }

    var versionText: String {
        text("settings.version.text", Self.appVersion, Self.appBuild)
    }

    func start() {
        refreshTimeline()
        startPeriodicRefresh()
    }

    func runCheck(manual: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        updateStatusSymbol()
        lastError = nil

        let result = await engine.performCheck(
            endpoints: settings.endpoints,
            attemptsPerEndpoint: settings.attemptsPerEndpoint,
            timeout: settings.timeoutSeconds
        )

        lastRawReport = result
        report = localizedReport(result)
        isChecking = false
        updateStatusSymbol()
        refreshTimeline()
    }

    func exportSupportPackage() {
        let panel = NSSavePanel()
        panel.title = text("export.title")
        panel.nameFieldStringValue = exporter.suggestedFilename()
        panel.canCreateDirectories = true
        panel.prompt = text("export.prompt")

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.writeSupportPackage(to: url)
            }
        }
    }

    func updateAttempts(_ value: Int) {
        settings.attemptsPerEndpoint = min(10, max(1, value))
        saveSettings()
    }

    func updateTimeout(_ value: Double) {
        settings.timeoutSeconds = min(10, max(0.5, value))
        saveSettings()
    }

    func updateAutoRefresh(_ value: Bool) {
        settings.autoRefreshEnabled = value
        saveSettings()
        startPeriodicRefresh()
    }

    func updateRefreshInterval(_ value: Int) {
        settings.refreshIntervalSeconds = min(3_600, max(60, value))
        saveSettings()
        startPeriodicRefresh()
    }

    func resetEndpoints() {
        settings.endpoints = ReachabilityEndpoint.defaultPublicEndpoints
        saveSettings()
    }

    func updateLanguage(_ value: AppLanguage) {
        language = value
        UserDefaults.standard.set(value.rawValue, forKey: "networkConsoleLite.language")
        if let lastRawReport {
            report = localizedReport(lastRawReport)
        }
        refreshTimeline()
    }

    var effectiveLanguage: AppLanguage {
        language.resolvedLanguage
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let template = L10n.string(key, language: effectiveLanguage)
        if arguments.isEmpty {
            return template
        }
        return String(format: template, arguments: arguments)
    }

    func text(for grade: HealthGrade) -> String {
        switch grade {
        case .checking:
            return text("grade.checking")
        case .healthy:
            return text("grade.healthy")
        case .warning:
            return text("grade.warning")
        case .critical:
            return text("grade.critical")
        }
    }

    func text(for status: NetworkStatus) -> String {
        switch status {
        case .available:
            return text("network.available")
        case .unavailable:
            return text("network.unavailable")
        case .unknown:
            return text("network.unknown")
        }
    }

    func text(for kind: InterfaceKind) -> String {
        switch kind {
        case .wifi:
            return text("interface.wifi")
        case .wired:
            return text("interface.wired")
        case .cellular:
            return text("interface.cellular")
        case .loopback:
            return text("interface.loopback")
        case .other:
            return text("interface.other")
        }
    }

    func text(for link: LinkState) -> String {
        switch link {
        case .up:
            return text("link.up")
        case .down:
            return text("link.down")
        case .unknown:
            return text("link.unknown")
        }
    }

    func text(for kind: TimelineEventKind) -> String {
        switch kind {
        case .pathChanged:
            return text("timeline.pathChanged")
        case .checkStarted:
            return text("timeline.checkStarted")
        case .checkFinished:
            return text("timeline.checkFinished")
        case .exportCreated:
            return text("timeline.exportCreated")
        case .diagnostic:
            return text("timeline.diagnostic")
        }
    }

    private func configureEngine() {
        engine.onPathUpdate = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        engine.onReport = { [weak self] report in
            Task { @MainActor in
                guard let self else { return }
                self.lastRawReport = report
                self.report = self.localizedReport(report)
                self.refreshTimeline()
            }
        }
    }

    private var lastPathUpdate: NetworkPathInfo?

    private func handlePathUpdate(_ path: NetworkPathInfo) {
        let changed = lastPathUpdate.map { $0 != path } ?? (lastPathUpdate != nil)
        guard changed else { return }
        lastPathUpdate = path
        refreshTimeline()
        guard settings.autoRefreshEnabled else { return }
        pathRefreshTask?.cancel()
        pathRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.runCheck(manual: false)
        }
    }

    private func startPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        guard settings.autoRefreshEnabled else { return }
        let interval = UInt64(max(60, settings.refreshIntervalSeconds)) * 1_000_000_000
        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, let self else { return }
                await self.runCheck(manual: false)
            }
        }
    }

    private func writeSupportPackage(to url: URL) {
        do {
            let data = try exporter.jsonData(
                appName: "NetDoctor",
                appVersion: Self.appVersion,
                appBuild: Self.appBuild,
                report: report,
                timeline: timelineEvents,
                settings: settings.supportPackageSettings
            )
            try data.write(to: url, options: .atomic)
            timelineStore.append(
                TimelineEvent(
                    kind: .exportCreated,
                    message: text("export.timeline.message", url.lastPathComponent),
                    arguments: [url.lastPathComponent]
                )
            )
            refreshTimeline()
            lastError = nil
        } catch {
            lastError = text("export.error", error.localizedDescription)
        }
    }

    private func refreshTimeline() {
        timelineEvents = localizedTimelineEvents(timelineStore.allEvents(limit: 50))
    }

    private func localizedReport(_ report: DiagnosisReport) -> DiagnosisReport {
        let dns = DNSSummary(
            resolverSource: localizedResolverSource(report.dns.resolverSource),
            servers: report.dns.servers,
            searchDomains: report.dns.searchDomains,
            timestamp: report.dns.timestamp
        )
        let advice = report.advice.map(localizedAdvice)
        let reachability = report.reachability.map(localizedProbe)

        return DiagnosisReport(
            id: report.id,
            timestamp: report.timestamp,
            path: report.path,
            interfaces: report.interfaces,
            dns: dns,
            routes: report.routes,
            reachability: reachability,
            latency: report.latency,
            advice: advice,
            health: report.health,
            summary: localizedSummary(report.health),
            score: report.score,
            verdict: localizedVerdict(report.verdict)
        )
    }

    func localizedVerdict(_ rawVerdict: String) -> String {
        switch rawVerdict {
        case "全链路畅通 · 状态极佳":
            return text("verdict.optimal")
        case "连接稳定 · 运行正常":
            return text("verdict.good")
        case "解析异常（DNS响应超时或未配置）":
            return text("verdict.dnsSlow")
        case "带宽受限（低数据模式或策略受限）":
            return text("verdict.constrained")
        case "丢包抖动（部分端点探测失败）":
            return text("verdict.jitterLoss")
        case "延迟偏高（响应时间较长）":
            return text("verdict.highLatency")
        case "局部异常（需关注网络配置）":
            return text("verdict.warningDefault")
        case "链路中断（网络已彻底断开）":
            return text("verdict.offline")
        case "物理断开（无活动网络接口）":
            return text("verdict.noInterface")
        case "出口受阻（公网全线探测失败）":
            return text("verdict.allProbesFailed")
        case "严重异常（网络服务中断）":
            return text("verdict.criticalDefault")
        case "链路探测中（网络诊断中…）":
            return text("verdict.checking")
        default:
            return rawVerdict
        }
    }

    private func localizedSummary(_ health: HealthGrade) -> String {
        switch health {
        case .checking:
            return text("summary.checking")
        case .healthy:
            return text("summary.healthy")
        case .warning:
            return text("summary.warning")
        case .critical:
            return text("summary.critical")
        }
    }

    private func localizedProbe(_ probe: ReachabilityProbe) -> ReachabilityProbe {
        let errorDescription: String?
        switch probe.errorDescription {
        case "无效 URL", "Invalid URL":
            errorDescription = text("probe.error.invalidURL")
        case "无效端口", "Invalid port":
            errorDescription = text("probe.error.invalidPort")
        default:
            errorDescription = probe.errorDescription
        }

        return ReachabilityProbe(
            id: probe.id,
            endpointID: probe.endpointID,
            endpointName: probe.endpointName,
            target: probe.target,
            kind: probe.kind,
            startedAt: probe.startedAt,
            durationMilliseconds: probe.durationMilliseconds,
            status: probe.status,
            httpStatusCode: probe.httpStatusCode,
            errorDescription: errorDescription
        )
    }

    private func localizedResolverSource(_ source: String) -> String {
        if source == "未获取" || source == "Not available" {
            return text("overview.notAvailable")
        }
        return source
    }

    private func localizedAdvice(_ advice: DiagnosticAdvice) -> DiagnosticAdvice {
        let titleKey: String
        let messageKey: String
        switch advice.title {
        case "确认网络已连接", "Confirm your network connection":
            titleKey = "advice.confirmConnection.title"
            messageKey = "advice.confirmConnection.message"
        case "启用网络接口", "Enable a network interface":
            titleKey = "advice.enableInterface.title"
            messageKey = "advice.enableInterface.message"
        case "检查 DNS 设置", "Check DNS settings":
            titleKey = "advice.checkDNS.title"
            messageKey = "advice.checkDNS.message"
        case "检查默认路由或 VPN", "Check the default route or VPN":
            titleKey = "advice.checkRoute.title"
            messageKey = "advice.checkRoute.message"
        case "网络处于受限状态", "The network is constrained":
            titleKey = "advice.constrained.title"
            messageKey = "advice.constrained.message"
        case "外网不可达", "The internet is unreachable":
            titleKey = "advice.unreachable.title"
            messageKey = "advice.unreachable.message"
        case "部分外网站点不可达", "Some internet endpoints are unreachable":
            titleKey = "advice.partialUnreachable.title"
            messageKey = "advice.partialUnreachable.message"
        case "延迟偏高", "Latency is high":
            titleKey = "advice.highLatency.title"
            messageKey = "advice.highLatency.message"
        case "网络状态正常", "Your network looks healthy":
            titleKey = "advice.healthy.title"
            messageKey = "advice.healthy.message"
        default:
            return advice
        }
        return DiagnosticAdvice(
            id: advice.id,
            title: text(titleKey),
            message: text(messageKey),
            severity: advice.severity
        )
    }

    private func localizedTimelineEvents(_ events: [TimelineEvent]) -> [TimelineEvent] {
        return events.map { event in
            TimelineEvent(
                id: event.id,
                timestamp: event.timestamp,
                kind: event.kind,
                message: localizedTimelineMessage(event),
                arguments: event.arguments
            )
        }
    }

    private func localizedTimelineMessage(_ event: TimelineEvent) -> String {
        let args = event.arguments
        switch event.kind {
        case .pathChanged:
            guard let rawStatus = args.first,
                  let status = NetworkStatus(rawValue: rawStatus) else { return event.message }
            let statusText = text(for: status)
            let kinds = args.count > 1
                ? args[1].split(separator: ",").compactMap { InterfaceKind(rawValue: String($0)) }
                : []
            guard !kinds.isEmpty else {
                return text("timeline.detail.pathChanged.statusOnly", statusText)
            }
            let interfaceText = kinds
                .map { text(for: $0) }
                .joined(separator: text("timeline.detail.listSeparator"))
            return text("timeline.detail.pathChanged", statusText, interfaceText)
        case .checkStarted:
            guard let count = args.first else { return event.message }
            return text("timeline.detail.checkStarted", count)
        case .checkFinished:
            guard args.count >= 4,
                  let grade = HealthGrade(rawValue: args[0]) else { return event.message }
            return text(
                "timeline.detail.checkFinished",
                text(for: grade),
                "\(args[1])/\(args[2])",
                args[3]
            )
        case .exportCreated:
            guard let filename = args.first else { return event.message }
            return text("export.timeline.message", filename)
        case .diagnostic:
            return event.message
        }
    }

    private func saveSettings() {
        settings.save()
    }

    private static func loadLanguage() -> AppLanguage {
        let stored = UserDefaults.standard.string(forKey: "networkConsoleLite.language")
        return AppLanguage.from(stored: stored)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
