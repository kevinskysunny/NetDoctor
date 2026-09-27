import Foundation

public enum NetworkStatus: String, Codable, Sendable {
    case available
    case unavailable
    case unknown

    public var displayName: String {
        rawValue
    }
}

public enum InterfaceKind: String, Codable, CaseIterable, Sendable {
    case wifi
    case wired
    case cellular
    case loopback
    case other

    public var displayName: String {
        rawValue
    }
}

public enum LinkState: String, Codable, Sendable {
    case up
    case down
    case unknown

    public var displayName: String {
        rawValue
    }
}

public struct IPAddressInfo: Codable, Equatable, Sendable {
    public let family: String
    public let address: String

    public init(family: String, address: String) {
        self.family = family
        self.address = address
    }
}

public struct InterfaceInfo: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: InterfaceKind
    public let isActive: Bool
    public let addresses: [IPAddressInfo]
    public let ssid: String?
    public let linkState: LinkState
    public let isDefaultRouteInterface: Bool

    public init(
        id: String,
        name: String,
        kind: InterfaceKind,
        isActive: Bool,
        addresses: [IPAddressInfo],
        ssid: String?,
        linkState: LinkState,
        isDefaultRouteInterface: Bool
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isActive = isActive
        self.addresses = addresses
        self.ssid = ssid
        self.linkState = linkState
        self.isDefaultRouteInterface = isDefaultRouteInterface
    }
}

public struct InterfaceDescriptor: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let kind: InterfaceKind

    public init(name: String, kind: InterfaceKind) {
        self.name = name
        self.kind = kind
    }
}

public struct NetworkPathInfo: Codable, Equatable, Sendable {
    public var status: NetworkStatus
    public var isExpensive: Bool
    public var isConstrained: Bool
    public var supportsDNS: Bool
    public var supportsIPv4: Bool
    public var supportsIPv6: Bool
    public var interfaces: [InterfaceDescriptor]

    public init(
        status: NetworkStatus,
        isExpensive: Bool,
        isConstrained: Bool,
        supportsDNS: Bool,
        supportsIPv4: Bool,
        supportsIPv6: Bool,
        interfaces: [InterfaceDescriptor]
    ) {
        self.status = status
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsDNS = supportsDNS
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.interfaces = interfaces
    }

    public static let unknown = NetworkPathInfo(
        status: .unknown,
        isExpensive: false,
        isConstrained: false,
        supportsDNS: false,
        supportsIPv4: false,
        supportsIPv6: false,
        interfaces: []
    )
}

public struct DNSSummary: Codable, Equatable, Sendable {
    public let resolverSource: String
    public let servers: [String]
    public let searchDomains: [String]
    public let timestamp: Date

    public init(
        resolverSource: String,
        servers: [String],
        searchDomains: [String],
        timestamp: Date
    ) {
        self.resolverSource = resolverSource
        self.servers = servers
        self.searchDomains = searchDomains
        self.timestamp = timestamp
    }

    public static let empty = DNSSummary(
        resolverSource: "未获取",
        servers: [],
        searchDomains: [],
        timestamp: Date()
    )
}

public struct RouteEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let family: String
    public let destination: String
    public let gateway: String?
    public let interfaceName: String?
    public let isDefault: Bool

    public init(
        id: String,
        family: String,
        destination: String,
        gateway: String?,
        interfaceName: String?,
        isDefault: Bool
    ) {
        self.id = id
        self.family = family
        self.destination = destination
        self.gateway = gateway
        self.interfaceName = interfaceName
        self.isDefault = isDefault
    }
}

public struct RouteSummary: Codable, Equatable, Sendable {
    public let routes: [RouteEntry]
    public let primaryServiceID: String?
    public let primaryInterfaceName: String?

    public init(
        routes: [RouteEntry],
        primaryServiceID: String?,
        primaryInterfaceName: String?
    ) {
        self.routes = routes
        self.primaryServiceID = primaryServiceID
        self.primaryInterfaceName = primaryInterfaceName
    }

    public static let empty = RouteSummary(
        routes: [],
        primaryServiceID: nil,
        primaryInterfaceName: nil
    )
}

public enum ProbeKind: String, Codable, Sendable {
    case https
    case tcp
}

public struct ReachabilityEndpoint: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let host: String
    public let path: String
    public let port: UInt16
    public let kind: ProbeKind

    public init(
        id: String,
        displayName: String,
        host: String,
        path: String = "/",
        port: UInt16,
        kind: ProbeKind
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.path = path
        self.port = port
        self.kind = kind
    }

    public var url: URL? {
        guard kind == .https else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if port != 443 {
            components.port = Int(port)
        }
        return components.url
    }

    public static let defaultPublicEndpoints: [ReachabilityEndpoint] = [
        ReachabilityEndpoint(
            id: "apple",
            displayName: "Apple",
            host: "www.apple.com",
            path: "/library/test/success.html",
            port: 443,
            kind: .https
        ),
        ReachabilityEndpoint(
            id: "cloudflare",
            displayName: "Cloudflare",
            host: "www.cloudflare.com",
            path: "/cdn-cgi/trace",
            port: 443,
            kind: .https
        ),
        ReachabilityEndpoint(
            id: "google",
            displayName: "Google",
            host: "connectivitycheck.gstatic.com",
            path: "/generate_204",
            port: 443,
            kind: .https
        )
    ]
}

public enum ProbeStatus: String, Codable, Sendable {
    case success
    case timeout
    case failed
    case cancelled

    public var displayName: String {
        rawValue
    }
}

public struct ReachabilityProbe: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let endpointID: String
    public let endpointName: String
    public let target: String
    public let kind: ProbeKind
    public let startedAt: Date
    public let durationMilliseconds: Double?
    public let status: ProbeStatus
    public let httpStatusCode: Int?
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        endpointID: String,
        endpointName: String,
        target: String,
        kind: ProbeKind,
        startedAt: Date,
        durationMilliseconds: Double?,
        status: ProbeStatus,
        httpStatusCode: Int?,
        errorDescription: String?
    ) {
        self.id = id
        self.endpointID = endpointID
        self.endpointName = endpointName
        self.target = target
        self.kind = kind
        self.startedAt = startedAt
        self.durationMilliseconds = durationMilliseconds
        self.status = status
        self.httpStatusCode = httpStatusCode
        self.errorDescription = errorDescription
    }
}

public struct LatencySample: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let endpointID: String
    public let endpointName: String
    public let durationMilliseconds: Double
    public let timestamp: Date
    public let success: Bool

    public init(
        id: UUID = UUID(),
        endpointID: String,
        endpointName: String,
        durationMilliseconds: Double,
        timestamp: Date,
        success: Bool
    ) {
        self.id = id
        self.endpointID = endpointID
        self.endpointName = endpointName
        self.durationMilliseconds = durationMilliseconds
        self.timestamp = timestamp
        self.success = success
    }
}

public struct LatencyPercentiles: Codable, Equatable, Sendable {
    public let p50: Double?
    public let p90: Double?
    public let p95: Double?

    public init(samples: [Double]) {
        let sorted = samples.sorted()
        func percentile(_ value: Double) -> Double? {
            guard !sorted.isEmpty else { return nil }
            let rank = value * Double(sorted.count - 1)
            let lower = Int(floor(rank))
            let upper = Int(ceil(rank))
            guard lower >= 0, upper < sorted.count else {
                return sorted[min(max(Int(rank.rounded()), 0), sorted.count - 1)]
            }
            let weight = rank - Double(lower)
            return sorted[lower] * (1 - weight) + sorted[upper] * weight
        }

        self.p50 = percentile(0.50)
        self.p90 = percentile(0.90)
        self.p95 = percentile(0.95)
    }
}

public struct ReachabilitySummary: Identifiable, Codable, Equatable, Sendable {
    public var id: String { endpointID }
    public let endpointID: String
    public let endpointName: String
    public let attempts: Int
    public let successCount: Int
    public let failureCount: Int
    public let lossRate: Double
    public let rttSamples: [Double]
    public let percentiles: LatencyPercentiles

    public init(endpointID: String, endpointName: String, probes: [ReachabilityProbe]) {
        self.endpointID = endpointID
        self.endpointName = endpointName
        self.attempts = probes.count
        self.successCount = probes.filter { $0.status == .success }.count
        self.failureCount = probes.count - successCount
        self.lossRate = probes.isEmpty ? 0 : Double(failureCount) / Double(probes.count)
        self.rttSamples = probes.compactMap { $0.durationMilliseconds }
        self.percentiles = LatencyPercentiles(samples: rttSamples)
    }
}

public enum HealthGrade: String, Codable, Sendable {
    case checking
    case healthy
    case warning
    case critical

    public var displayName: String {
        rawValue
    }

    public var symbolName: String {
        switch self {
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .healthy:
            return "waveform.path.ecg"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
}

public struct DiagnosticAdvice: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let code: AdviceCode
    public let title: String
    public let message: String
    public let severity: HealthGrade

    public init(
        id: UUID = UUID(),
        code: AdviceCode,
        title: String = "",
        message: String = "",
        severity: HealthGrade
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.message = message
        self.severity = severity
    }

    private enum CodingKeys: String, CodingKey {
        case id, code, title, message, severity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let rawCode = try container.decodeIfPresent(String.self, forKey: .code) ?? AdviceCode.unknown.rawValue
        code = AdviceCode(rawValue: rawCode) ?? .unknown
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        severity = try container.decode(HealthGrade.self, forKey: .severity)
    }
}

public struct DiagnosisReport: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let path: NetworkPathInfo
    public let interfaces: [InterfaceInfo]
    public let dns: DNSSummary
    public let routes: RouteSummary
    public let reachability: [ReachabilityProbe]
    public let latency: [LatencySample]
    public let advice: [DiagnosticAdvice]
    public let health: HealthGrade
    public let summary: String
    public let score: Int
    public let verdict: VerdictCode

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        path: NetworkPathInfo,
        interfaces: [InterfaceInfo],
        dns: DNSSummary,
        routes: RouteSummary,
        reachability: [ReachabilityProbe],
        latency: [LatencySample],
        advice: [DiagnosticAdvice],
        health: HealthGrade,
        summary: String,
        score: Int = 100,
        verdict: VerdictCode = .checking
    ) {
        self.id = id
        self.timestamp = timestamp
        self.path = path
        self.interfaces = interfaces
        self.dns = dns
        self.routes = routes
        self.reachability = reachability
        self.latency = latency
        self.advice = advice
        self.health = health
        self.summary = summary
        self.score = score
        self.verdict = verdict
    }

    private enum VerdictCodingKeys: String, CodingKey {
        case id, timestamp, path, interfaces, dns, routes, reachability, latency, advice, health, summary, score, verdict
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerdictCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        path = try container.decode(NetworkPathInfo.self, forKey: .path)
        interfaces = try container.decode([InterfaceInfo].self, forKey: .interfaces)
        dns = try container.decode(DNSSummary.self, forKey: .dns)
        routes = try container.decode(RouteSummary.self, forKey: .routes)
        reachability = try container.decode([ReachabilityProbe].self, forKey: .reachability)
        latency = try container.decode([LatencySample].self, forKey: .latency)
        advice = try container.decode([DiagnosticAdvice].self, forKey: .advice)
        health = try container.decode(HealthGrade.self, forKey: .health)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 100
        let rawVerdict = try container.decode(String.self, forKey: .verdict)
        verdict = VerdictCode(rawValue: rawVerdict) ?? .checking
    }

    public var reachabilitySummaries: [ReachabilitySummary] {
        Dictionary(grouping: reachability, by: \.endpointID)
            .map { key, value in
                ReachabilitySummary(
                    endpointID: key,
                    endpointName: value.first?.endpointName ?? key,
                    probes: value
                )
            }
            .sorted { $0.endpointName.localizedCaseInsensitiveCompare($1.endpointName) == .orderedAscending }
    }
}

public enum TimelineEventKind: String, Codable, Sendable {
    case pathChanged
    case checkStarted
    case checkFinished
    case exportCreated
    case diagnostic

    public var displayName: String {
        rawValue
    }
}

public struct TimelineEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: TimelineEventKind
    public let message: String
    /// Language-neutral values (status/grade raw values, counts, filenames)
    /// used to rebuild a localized message at display time.
    public let arguments: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: TimelineEventKind,
        message: String,
        arguments: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
        self.arguments = arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        kind = try container.decode(TimelineEventKind.self, forKey: .kind)
        message = try container.decode(String.self, forKey: .message)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
    }
}
public enum VerdictCode: String, Codable, Sendable, CaseIterable {
    case checking
    case optimal
    case good
    case dnsSlow
    case constrained
    case jitterLoss
    case highLatency
    case warningDefault
    case offline
    case noInterface
    case allProbesFailed
    case criticalDefault

    public var l10nKey: String {
        "verdict.\(rawValue)"
    }
}

public enum AdviceCode: String, Codable, Sendable, CaseIterable {
    case confirmConnection
    case enableInterface
    case checkDNS
    case checkRoute
    case constrained
    case unreachable
    case partialUnreachable
    case highLatency
    case healthy
    case unknown

    public var titleKey: String {
        "advice.\(rawValue).title"
    }

    public var messageKey: String {
        "advice.\(rawValue).message"
    }
}
