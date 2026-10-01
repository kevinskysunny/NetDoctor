import Foundation
import XCTest
import NetworkCore
@testable import NetworkConsoleApp

// MARK: - 本文件 mock（NetworkConsoleAppTests target 独立定义，不复用 NetworkCoreTests/Mocks.swift）

final class MockPathProvider: NetworkPathProviding {
    var currentPath: NetworkPathInfo
    private var updateHandler: ((NetworkPathInfo) -> Void)?

    init(path: NetworkPathInfo) {
        self.currentPath = path
    }

    func start(onUpdate: @escaping (NetworkPathInfo) -> Void) {
        updateHandler = onUpdate
        onUpdate(currentPath)
    }

    func stop() {
        updateHandler = nil
    }

    func emit(_ path: NetworkPathInfo) {
        currentPath = path
        updateHandler?(path)
    }
}

final class MutableInterfaceCollector: InterfaceCollecting {
    var interfaces: [InterfaceInfo]

    init(interfaces: [InterfaceInfo]) {
        self.interfaces = interfaces
    }

    func collect() -> [InterfaceInfo] {
        interfaces
    }
}

struct MockDNSCollector: DNSCollecting {
    var dns: DNSSummary

    func collect() -> DNSSummary { dns }
}

struct MockRouteCollector: RouteCollecting {
    var routes: RouteSummary

    func collect() -> RouteSummary { routes }
}

struct MockReachabilityProber: ReachabilityProbing {
    var result: [ReachabilityProbe]

    func probe(endpoints: [ReachabilityEndpoint], attemptsPerEndpoint: Int, timeout: TimeInterval) async -> [ReachabilityProbe] {
        result
    }
}

final class MemoryEventStore: EventRecording {
    private(set) var events: [TimelineEvent] = []

    func append(_ event: TimelineEvent) { events.append(event) }
}

// MARK: - ET-A 测试

final class EtherLinkDetectAppTests: XCTestCase {
    private var pathRefreshBackup: UInt64 = 5_000_000_000

    @MainActor
    override func setUp() {
        super.setUp()
        pathRefreshBackup = AppModel.pathRefreshDebounceNanoseconds
        AppModel.pathRefreshDebounceNanoseconds = 0
    }

    @MainActor
    override func tearDown() {
        AppModel.pathRefreshDebounceNanoseconds = pathRefreshBackup
        super.tearDown()
    }

    private func makeInterface(
        name: String,
        kind: InterfaceKind,
        isActive: Bool,
        linkState: LinkState,
        addresses: [IPAddressInfo] = [],
        isDefaultRoute: Bool = false
    ) -> InterfaceInfo {
        InterfaceInfo(
            id: name,
            name: name,
            kind: kind,
            isActive: isActive,
            addresses: addresses,
            ssid: nil,
            linkState: linkState,
            isDefaultRouteInterface: isDefaultRoute
        )
    }

    private var availablePath: NetworkPathInfo {
        NetworkPathInfo(
            status: .available,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: true,
            supportsIPv4: true,
            supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wired)]
        )
    }

    // MARK: ET-A1：Local Mac 优先物理网卡
    @MainActor
    func testETA1PreferredInterfaceAvoidsUtun() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let selected = LocalMacSelector.preferredInterface(in: interfaces)
        XCTAssertEqual(selected?.name, "en0", "物理断开时不得回退显示 utun0")
        XCTAssertNotEqual(selected?.name, "utun0")
    }

    // MARK: ET-A2：无物理活跃时选择器仍返回物理卡并计数为空
    @MainActor
    func testETA2SelectorReturnsPhysicalCardAndPhysicalActiveIsEmpty() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        XCTAssertEqual(LocalMacSelector.preferredInterface(in: interfaces)?.name, "en0")
        XCTAssertTrue(LocalMacSelector.physicalActive(interfaces).isEmpty)
    }

    // MARK: ET-A3：Overview 活动卡片物理口径与弱化
    @MainActor
    func testETA3OverviewActivityUsesPhysicalKind() {
        let onlyUtun = [
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let activityUtun = OverviewActivity.compute(onlyUtun)
        XCTAssertEqual(activityUtun.count, 0)
        XCTAssertEqual(activityUtun.names, [])
        XCTAssertTrue(activityUtun.degraded)

        let en0Up = [
            makeInterface(
                name: "en0",
                kind: .wired,
                isActive: true,
                linkState: .up,
                addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")]
            )
        ]
        let activityEn0 = OverviewActivity.compute(en0Up)
        XCTAssertEqual(activityEn0.count, 1)
        XCTAssertEqual(activityEn0.names, ["en0"])
        XCTAssertFalse(activityEn0.degraded)
    }

    // MARK: ET-A4：接口页可见性数据保障——拔线 report 含 down 物理卡
    @MainActor
    func testETA4ReportContainsDownPhysicalInterface() async {
        let downEn0 = makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down)
        let engine = DiagnosticEngine(
            pathProvider: MockPathProvider(path: availablePath),
            interfaceCollector: MutableInterfaceCollector(interfaces: [downEn0]),
            dnsCollector: MockDNSCollector(dns: .empty),
            routeCollector: MockRouteCollector(routes: .empty),
            reachabilityProber: MockReachabilityProber(result: []),
            eventStore: MemoryEventStore()
        )
        let report = await engine.performCheck(endpoints: [], attemptsPerEndpoint: 1, timeout: 1)
        XCTAssertTrue(report.interfaces.contains { $0.name == "en0" && $0.linkState == .down })
        XCTAssertTrue(report.interfaces.contains { $0.addresses.isEmpty })
    }

    // MARK: ET-A5：App 层恢复闭环（拔线 → 插线）
    @MainActor
    func testETA5AppLevelRecoveryLoop() async throws {
        let en0Up = makeInterface(
            name: "en0",
            kind: .wired,
            isActive: true,
            linkState: .up,
            addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")]
        )
        let collector = MutableInterfaceCollector(interfaces: [en0Up])
        let pathProvider = MockPathProvider(path: availablePath)
        let store = MemoryEventStore()
        let engine = DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: collector,
            dnsCollector: MockDNSCollector(dns: .empty),
            routeCollector: MockRouteCollector(routes: .empty),
            reachabilityProber: MockReachabilityProber(result: []),
            eventStore: store
        )
        let model = AppModel(engine: engine, timelineStore: TimelineStore(fileURL: nil))

        // 状态 A：拔线——物理网卡 down，路径中接口消失（触发 handlePathUpdate + 自动 runCheck）
        collector.interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down)
        ]
        let pulledPath = NetworkPathInfo(
            status: .unavailable,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: false,
            supportsIPv4: false,
            supportsIPv6: false,
            interfaces: []
        )
        pathProvider.emit(pulledPath)

        let stateA = await waitForReport(model) { $0?.verdict == .noInterface }
        XCTAssertEqual(stateA?.interfaces.first?.linkState, .down)
        XCTAssertEqual(stateA?.verdict, .noInterface, "拔线后 App 报告必须为 noInterface")

        // 状态 B：插线恢复——物理网卡 up + 有效 IP，路径恢复
        collector.interfaces = [en0Up]
        pathProvider.emit(availablePath)

        let stateB = await waitForReport(model) { $0?.verdict != .noInterface && $0?.health != .critical }
        XCTAssertEqual(stateB?.interfaces.first?.linkState, .up)
        XCTAssertNotNil(stateB)
    }

    @MainActor
    private func waitForReport(
        _ model: AppModel,
        condition: @escaping (DiagnosisReport?) -> Bool
    ) async -> DiagnosisReport? {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if condition(model.report) {
                return model.report
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return model.report
    }
}