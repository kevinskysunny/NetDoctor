import AppKit
import Combine
import Foundation
import NetworkCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var report: DiagnosisReport?
    @Published private(set) var isChecking = false
    @Published private(set) var lastError: String?
    @Published private(set) var timelineEvents: [TimelineEvent] = []
    @Published var settings: AppSettings
    @Published var language: AppLanguage

    private let engine: DiagnosticEngine
    private let timelineStore: TimelineStore
    private let exporter = SupportPackageExporter()
    private var pathRefreshTask: Task<Void, Never>?
    private var periodicRefreshTask: Task<Void, Never>?

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
        Task {
            await runCheck(manual: false)
        }
    }

    var statusSymbolName: String {
        if isChecking {
            return HealthGrade.checking.symbolName
        }
        return report?.health.symbolName ?? HealthGrade.checking.symbolName
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
        lastError = nil

        let result = await engine.performCheck(
            endpoints: settings.endpoints,
            attemptsPerEndpoint: settings.attemptsPerEndpoint,
            timeout: settings.timeoutSeconds
        )

        report = localizedReport(result)
        isChecking = false
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
        if let report {
            self.report = localizedReport(report)
        }
        refreshTimeline()
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let template = L10n.string(key, language: language)
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
                self.report = self.localizedReport(report)
                self.refreshTimeline()
            }
        }
    }

    private func handlePathUpdate(_ path: NetworkPathInfo) {
        refreshTimeline()
        guard settings.autoRefreshEnabled else { return }
        pathRefreshTask?.cancel()
        pathRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
                appName: "NetworkConsole Lite",
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
                    message: text("export.timeline.message", url.lastPathComponent)
                )
            )
            refreshTimeline()
            lastError = nil
        } catch {
            lastError = text("export.error", error.localizedDescription)
        }
    }

    private func refreshTimeline() {
        timelineEvents = localizedTimelineEvents(timelineStore.allEvents(limit: 500))
    }

    private func localizedReport(_ report: DiagnosisReport) -> DiagnosisReport {
        guard language == .english else { return report }

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
            summary: localizedSummary(report.health)
        )
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
        guard language == .english else { return probe }
        let errorDescription: String?
        switch probe.errorDescription {
        case "无效 URL":
            errorDescription = "Invalid URL"
        case "无效端口":
            errorDescription = "Invalid port"
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
        guard language == .english else { return source }
        if source == "未获取" {
            return "Not available"
        }
        return source
    }

    private func localizedAdvice(_ advice: DiagnosticAdvice) -> DiagnosticAdvice {
        guard language == .english else { return advice }
        switch advice.title {
        case "确认网络已连接":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Confirm your network connection",
                message: "Check the Wi-Fi icon in the menu bar or the Ethernet cable. If it is already connected, try turning Wi-Fi off and on again, or switch to a phone hotspot to see whether the issue is local.",
                severity: advice.severity
            )
        case "启用网络接口":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Enable a network interface",
                message: "No active interface was detected. Open System Settings > Network and make sure Wi-Fi or Ethernet is enabled.",
                severity: advice.severity
            )
        case "检查 DNS 设置":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Check DNS settings",
                message: "No DNS server was found. Open System Settings > Network > Details > DNS, or ask your network administrator whether DHCP should provide one.",
                severity: advice.severity
            )
        case "检查默认路由或 VPN":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Check the default route or VPN",
                message: "No default route was found. If you are using a VPN, disconnect it and check again. Otherwise, confirm that the current service received an address and gateway.",
                severity: advice.severity
            )
        case "网络处于受限状态":
            return DiagnosticAdvice(
                id: advice.id,
                title: "The network is constrained",
                message: "macOS reports that this network is constrained. This often happens with phone hotspots, Low Data Mode, or captive portals.",
                severity: advice.severity
            )
        case "外网不可达":
            return DiagnosticAdvice(
                id: advice.id,
                title: "The internet is unreachable",
                message: "All public endpoints failed. Check the router, modem, and VPN first, then verify that a firewall is not blocking outbound connections.",
                severity: advice.severity
            )
        case "部分外网站点不可达":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Some internet endpoints are unreachable",
                message: "Some public endpoints failed. This may be a blocked site or a remote service issue. Check whether Apple and Cloudflare succeeded.",
                severity: advice.severity
            )
        case "延迟偏高":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Latency is high",
                message: "P90 latency is above 800 ms. Pause large downloads or backups and prefer 5 GHz Wi-Fi or a wired connection.",
                severity: advice.severity
            )
        case "网络状态正常":
            return DiagnosticAdvice(
                id: advice.id,
                title: "Your network looks healthy",
                message: "No issue was found. If a specific website still fails, check whether that site is unavailable by itself.",
                severity: advice.severity
            )
        default:
            return advice
        }
    }

    private func localizedTimelineEvents(_ events: [TimelineEvent]) -> [TimelineEvent] {
        guard language == .english else { return events }
        return events.map { event in
            TimelineEvent(
                id: event.id,
                timestamp: event.timestamp,
                kind: event.kind,
                message: localizedTimelineMessage(event.kind)
            )
        }
    }

    private func localizedTimelineMessage(_ kind: TimelineEventKind) -> String {
        switch kind {
        case .pathChanged:
            return "Network path changed"
        case .checkStarted:
            return "Network health check started"
        case .checkFinished:
            return "Network health check finished"
        case .exportCreated:
            return "Support package exported"
        case .diagnostic:
            return "Diagnostic event recorded"
        }
    }

    private func saveSettings() {
        settings.save()
    }

    private static func loadLanguage() -> AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: "networkConsoleLite.language") else {
            return .chinese
        }
        return AppLanguage(rawValue: rawValue) ?? .chinese
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
