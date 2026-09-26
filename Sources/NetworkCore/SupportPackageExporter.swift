import Foundation

public struct SupportPackagePayload: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let appName: String
    public let appVersion: String
    public let appBuild: String
    public let privacyRedacted: Bool
    public let report: DiagnosisReport?
    public let timeline: [TimelineEvent]
    public let settings: SupportPackageSettings

    public init(
        exportedAt: Date = Date(),
        appName: String,
        appVersion: String,
        appBuild: String,
        report: DiagnosisReport?,
        timeline: [TimelineEvent],
        settings: SupportPackageSettings
    ) {
        self.schemaVersion = 1
        self.exportedAt = exportedAt
        self.appName = appName
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.privacyRedacted = true
        self.report = report.map(Self.redact)
        self.timeline = timeline
        self.settings = settings
    }

    public static func redact(_ report: DiagnosisReport) -> DiagnosisReport {
        let interfaces = report.interfaces.map { interface in
            InterfaceInfo(
                id: interface.id,
                name: interface.name,
                kind: interface.kind,
                isActive: interface.isActive,
                addresses: interface.addresses,
                ssid: interface.ssid == nil ? nil : "<redacted>",
                linkState: interface.linkState,
                isDefaultRouteInterface: interface.isDefaultRouteInterface
            )
        }

        return DiagnosisReport(
            id: report.id,
            timestamp: report.timestamp,
            path: report.path,
            interfaces: interfaces,
            dns: report.dns,
            routes: report.routes,
            reachability: report.reachability,
            latency: report.latency,
            advice: report.advice,
            health: report.health,
            summary: report.summary,
            score: report.score,
            verdict: report.verdict
        )
    }
}

public struct SupportPackageSettings: Codable, Equatable, Sendable {
    public let attemptsPerEndpoint: Int
    public let timeoutSeconds: Double
    public let autoRefreshEnabled: Bool
    public let refreshIntervalSeconds: Int

    public init(
        attemptsPerEndpoint: Int,
        timeoutSeconds: Double,
        autoRefreshEnabled: Bool,
        refreshIntervalSeconds: Int
    ) {
        self.attemptsPerEndpoint = attemptsPerEndpoint
        self.timeoutSeconds = timeoutSeconds
        self.autoRefreshEnabled = autoRefreshEnabled
        self.refreshIntervalSeconds = refreshIntervalSeconds
    }
}

public final class SupportPackageExporter {
    public init() {}

    public func jsonData(
        appName: String,
        appVersion: String,
        appBuild: String,
        report: DiagnosisReport?,
        timeline: [TimelineEvent],
        settings: SupportPackageSettings
    ) throws -> Data {
        let payload = SupportPackagePayload(
            appName: appName,
            appVersion: appVersion,
            appBuild: appBuild,
            report: report,
            timeline: timeline,
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public func suggestedFilename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "NetworkConsoleLite-Support-\(formatter.string(from: now)).json"
    }
}
