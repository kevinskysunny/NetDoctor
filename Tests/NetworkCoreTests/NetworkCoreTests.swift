import Foundation
import XCTest
@testable import NetworkCore

final class HealthGraderTests: XCTestCase {
    func testCriticalWhenPathUnavailable() {
        let path = NetworkPathInfo(
            status: .unavailable,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: false,
            supportsIPv4: false,
            supportsIPv6: false,
            interfaces: []
        )

        let grade = HealthGrader().grade(
            path: path,
            interfaces: [],
            dns: .empty,
            routes: .empty,
            reachability: []
        )

        XCTAssertEqual(grade, .critical)
    }

    func testWarningWhenSomeProbesFail() {
        let path = Self.availablePath
        let interface = Self.activeInterface
        let dns = DNSSummary(
            resolverSource: "mock",
            servers: ["1.1.1.1"],
            searchDomains: [],
            timestamp: Date()
        )
        let route = RouteSummary(
            routes: [
                RouteEntry(
                    id: "default",
                    family: "IPv4",
                    destination: "0.0.0.0/0",
                    gateway: "192.168.1.1",
                    interfaceName: "en0",
                    isDefault: true
                )
            ],
            primaryServiceID: nil,
            primaryInterfaceName: "en0"
        )
        let probes = [
            Self.probe(endpointID: "a", status: .success, duration: 30),
            Self.probe(endpointID: "a", status: .failed, duration: nil)
        ]

        let grade = HealthGrader().grade(
            path: path,
            interfaces: [interface],
            dns: dns,
            routes: route,
            reachability: probes
        )

        XCTAssertEqual(grade, .warning)
    }

    func testHealthyWhenEverythingIsAvailable() {
        let path = Self.availablePath
        let interface = Self.activeInterface
        let dns = DNSSummary(
            resolverSource: "mock",
            servers: ["1.1.1.1"],
            searchDomains: [],
            timestamp: Date()
        )
        let route = RouteSummary(
            routes: [
                RouteEntry(
                    id: "default",
                    family: "IPv4",
                    destination: "0.0.0.0/0",
                    gateway: "192.168.1.1",
                    interfaceName: "en0",
                    isDefault: true
                )
            ],
            primaryServiceID: nil,
            primaryInterfaceName: "en0"
        )
        let probes = [
            Self.probe(endpointID: "a", status: .success, duration: 20),
            Self.probe(endpointID: "a", status: .success, duration: 24)
        ]

        let grade = HealthGrader().grade(
            path: path,
            interfaces: [interface],
            dns: dns,
            routes: route,
            reachability: probes
        )

        XCTAssertEqual(grade, .healthy)
    }

    func testAdviceExplainsDNSAndExternalFailuresForNoviceUsers() {
        let path = NetworkPathInfo(
            status: .available,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wifi)]
        )
        let interface = Self.activeInterface
        let probes = [
            Self.probe(endpointID: "a", status: .failed, duration: nil)
        ]

        let advice = HealthGrader().advice(
            path: path,
            interfaces: [interface],
            dns: .empty,
            routes: .empty,
            reachability: probes
        )

        XCTAssertTrue(advice.contains { $0.title == "检查 DNS 设置" })
        XCTAssertTrue(advice.contains { $0.title == "检查默认路由或 VPN" })
        XCTAssertTrue(advice.contains { $0.title == "外网不可达" })
    }

    private static var availablePath: NetworkPathInfo {
        NetworkPathInfo(
            status: .available,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wifi)]
        )
    }

    private static var activeInterface: InterfaceInfo {
        InterfaceInfo(
            id: "en0",
            name: "en0",
            kind: .wifi,
            isActive: true,
            addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")],
            ssid: "Home",
            linkState: .up,
            isDefaultRouteInterface: true
        )
    }

    private static func probe(
        endpointID: String,
        status: ProbeStatus,
        duration: Double?
    ) -> ReachabilityProbe {
        ReachabilityProbe(
            endpointID: endpointID,
            endpointName: "Endpoint",
            target: "example.com:443",
            kind: .https,
            startedAt: Date(),
            durationMilliseconds: duration,
            status: status,
            httpStatusCode: status == .success ? 200 : nil,
            errorDescription: status == .success ? nil : "failed"
        )
    }
}

final class LatencyPercentilesTests: XCTestCase {
    func testPercentilesAreOrdered() {
        let percentiles = LatencyPercentiles(samples: [10, 20, 30, 40, 50])
        XCTAssertEqual(percentiles.p50, 30)
        XCTAssertEqual(percentiles.p90, 46)
        XCTAssertEqual(percentiles.p95, 48)
    }

    func testEmptySamplesProduceNil() {
        let percentiles = LatencyPercentiles(samples: [])
        XCTAssertNil(percentiles.p50)
        XCTAssertNil(percentiles.p90)
        XCTAssertNil(percentiles.p95)
    }
}

final class ReachabilityEndpointTests: XCTestCase {
    func testDefaultHTTPSEndpointsUseConcreteProbePaths() {
        let endpoints = Dictionary(
            uniqueKeysWithValues: ReachabilityEndpoint.defaultPublicEndpoints.map { ($0.id, $0) }
        )

        XCTAssertEqual(endpoints["apple"]?.url?.path, "/library/test/success.html")
        XCTAssertEqual(endpoints["cloudflare"]?.url?.path, "/cdn-cgi/trace")
        XCTAssertEqual(endpoints["google"]?.url?.path, "/generate_204")
    }
}

final class DiagnosticEngineTests: XCTestCase {
    @MainActor
    func testEngineBuildsReportFromMocks() async {
        let path = NetworkPathInfo(
            status: .available,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wifi)]
        )
        let pathProvider = MockPathProvider(path: path)
        let interface = InterfaceInfo(
            id: "en0",
            name: "en0",
            kind: .wifi,
            isActive: true,
            addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")],
            ssid: "Home",
            linkState: .up,
            isDefaultRouteInterface: true
        )
        let dns = DNSSummary(
            resolverSource: "mock",
            servers: ["1.1.1.1"],
            searchDomains: [],
            timestamp: Date()
        )
        let route = RouteSummary(
            routes: [
                RouteEntry(
                    id: "default",
                    family: "IPv4",
                    destination: "0.0.0.0/0",
                    gateway: "192.168.1.1",
                    interfaceName: "en0",
                    isDefault: true
                )
            ],
            primaryServiceID: nil,
            primaryInterfaceName: "en0"
        )
        let probe = ReachabilityProbe(
            endpointID: "apple",
            endpointName: "Apple",
            target: "www.apple.com:443",
            kind: .https,
            startedAt: Date(),
            durationMilliseconds: 25,
            status: .success,
            httpStatusCode: 200,
            errorDescription: nil
        )
        let events = MemoryEventStore()
        let engine = DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: MockInterfaceCollector(interfaces: [interface]),
            dnsCollector: MockDNSCollector(dns: dns),
            routeCollector: MockRouteCollector(routes: route),
            reachabilityProber: MockReachabilityProber(result: [probe]),
            eventStore: events
        )

        let report = await engine.performCheck(
            endpoints: ReachabilityEndpoint.defaultPublicEndpoints,
            attemptsPerEndpoint: 2,
            timeout: 2
        )

        XCTAssertEqual(report.health, .healthy)
        XCTAssertEqual(report.reachability.count, 1)
        XCTAssertTrue(events.events.contains { $0.kind == .checkStarted })
        XCTAssertTrue(events.events.contains { $0.kind == .checkFinished })
    }
}

final class SupportPackageExporterTests: XCTestCase {
    func testExporterRedactsSSIDAndProducesJSON() throws {
        let report = DiagnosisReport(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            path: NetworkPathInfo.unknown,
            interfaces: [
                InterfaceInfo(
                    id: "en0",
                    name: "en0",
                    kind: .wifi,
                    isActive: true,
                    addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")],
                    ssid: "MyHome",
                    linkState: .up,
                    isDefaultRouteInterface: true
                )
            ],
            dns: .empty,
            routes: .empty,
            reachability: [],
            latency: [],
            advice: [],
            health: .healthy,
            summary: "ok"
        )
        let data = try SupportPackageExporter().jsonData(
            appName: "Test",
            appVersion: "1.0",
            appBuild: "1",
            report: report,
            timeline: [],
            settings: SupportPackageSettings(
                attemptsPerEndpoint: 3,
                timeoutSeconds: 2,
                autoRefreshEnabled: true,
                refreshIntervalSeconds: 300
            )
        )
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["privacyRedacted"] as? Bool, true)
        let reportObject = try XCTUnwrap(object["report"] as? [String: Any])
        let interfaces = try XCTUnwrap(reportObject["interfaces"] as? [[String: Any]])
        XCTAssertEqual(interfaces.first?["ssid"] as? String, "<redacted>")
    }
}

final class TimelineStoreTests: XCTestCase {
    func testTimelineRoundTripWithoutNetwork() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("timeline.jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TimelineStore(fileURL: url, maximumStoredEvents: 10)
        store.append(TimelineEvent(kind: .diagnostic, message: "test"))
        XCTAssertEqual(store.allEvents().count, 1)

        let reloaded = TimelineStore(fileURL: url, maximumStoredEvents: 10)
        XCTAssertEqual(reloaded.allEvents().first?.message, "test")
    }
}
