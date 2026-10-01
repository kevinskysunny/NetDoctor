import Foundation
import XCTest
import NetworkCore
@testable import NetworkConsoleApp

// MARK: - 本文件 mock（NetworkConsoleAppTests target 独立定义）

final class LCMockPathProvider: NetworkPathProviding {
    var currentPath: NetworkPathInfo
    private var updateHandler: ((NetworkPathInfo) -> Void)?

    init(path: NetworkPathInfo) { self.currentPath = path }

    func start(onUpdate: @escaping (NetworkPathInfo) -> Void) {
        updateHandler = onUpdate
        onUpdate(currentPath)
    }
    func stop() { updateHandler = nil }
    func emit(_ path: NetworkPathInfo) {
        currentPath = path
        updateHandler?(path)
    }
}

final class LCMutableInterfaceCollector: InterfaceCollecting {
    var interfaces: [InterfaceInfo]
    init(interfaces: [InterfaceInfo]) { self.interfaces = interfaces }
    func collect() -> [InterfaceInfo] { interfaces }
}

struct LCMockDNSCollector: DNSCollecting {
    var dns: DNSSummary
    func collect() -> DNSSummary { dns }
}

struct LCMockRouteCollector: RouteCollecting {
    var routes: RouteSummary
    func collect() -> RouteSummary { routes }
}

struct LCMockReachabilityProber: ReachabilityProbing {
    var result: [ReachabilityProbe]
    func probe(endpoints: [ReachabilityEndpoint], attemptsPerEndpoint: Int, timeout: TimeInterval) async -> [ReachabilityProbe] { result }
}

final class LCMemoryEventStore: EventRecording {
    private(set) var events: [TimelineEvent] = []
    func append(_ event: TimelineEvent) { events.append(event) }
}

// MARK: - LC-A 载波误判修复 App 测试

final class LinkCarrierFixAppTests: XCTestCase {
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
            id: name, name: name, kind: kind, isActive: isActive,
            addresses: addresses, ssid: nil, linkState: linkState,
            isDefaultRouteInterface: isDefaultRoute
        )
    }

    private var availablePath: NetworkPathInfo {
        NetworkPathInfo(
            status: .available, isExpensive: false, isConstrained: false,
            supportsDNS: true, supportsIPv4: true, supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wifi)]
        )
    }

    // MARK: LC-A1：纯 Wi-Fi 环境 Overview 活动接口计数 == 1
    @MainActor
    func testLCA1PureWifiActiveCountIsOne() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: true, linkState: .up,
                          addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.180")]),
            makeInterface(name: "en1", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "en2", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "en3", kind: .wired, isActive: false, linkState: .down)
        ]
        let activity = OverviewActivity.compute(interfaces)
        XCTAssertEqual(activity.count, 1, "纯 Wi-Fi 环境活动接口计数必须为 1")
        XCTAssertEqual(activity.names, ["en0"])
        XCTAssertFalse(activity.degraded)
    }

    // MARK: LC-A2：LocalMacSelector 优先 en0（Wi-Fi），不选 en1~en3（down）
    @MainActor
    func testLCA2SelectorPrefersWifiOverDownWired() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: true, linkState: .up),
            makeInterface(name: "en1", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "en2", kind: .wired, isActive: false, linkState: .down)
        ]
        let selected = LocalMacSelector.preferredInterface(in: interfaces)
        XCTAssertEqual(selected?.name, "en0")
        XCTAssertEqual(LocalMacSelector.physicalActive(interfaces).count, 1)
    }

    // MARK: LC-A3：HealthGrader 物理口径 — 纯 Wi-Fi 仅有 en0 活跃 → 非 critical
    @MainActor
    func testLCA3HealthGraderPhysicalActiveWithOnlyWifi() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: true, linkState: .up,
                          addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.180")]),
            makeInterface(name: "en1", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "en2", kind: .wired, isActive: false, linkState: .down)
        ]
        let path = NetworkPathInfo(
            status: .available, isExpensive: false, isConstrained: false,
            supportsDNS: true, supportsIPv4: true, supportsIPv6: false,
            interfaces: [InterfaceDescriptor(name: "en0", kind: .wifi)]
        )
        let grade = HealthGrader().grade(
            path: path,
            interfaces: interfaces,
            dns: DNSSummary(resolverSource: "test", servers: ["8.8.8.8"], searchDomains: [], timestamp: Date()),
            routes: .empty,
            reachability: []
        )
        XCTAssertNotEqual(grade, .critical, "纯 Wi-Fi 环境有物理活跃接口 → 不应 critical")
    }

    // MARK: LC-A4：App 层恢复闭环（载波 down → up）
    @MainActor
    func testLCA4AppLevelCarrierRecoveryLoop() async throws {
        let en0Up = makeInterface(
            name: "en0", kind: .wifi, isActive: true, linkState: .up,
            addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.180")]
        )
        let collector = LCMutableInterfaceCollector(interfaces: [en0Up])
        let pathProvider = LCMockPathProvider(path: availablePath)
        let store = LCMemoryEventStore()
        let engine = DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: collector,
            dnsCollector: LCMockDNSCollector(dns: .empty),
            routeCollector: LCMockRouteCollector(routes: .empty),
            reachabilityProber: LCMockReachabilityProber(result: []),
            eventStore: store
        )
        let model = AppModel(engine: engine, timelineStore: TimelineStore(fileURL: nil))

        collector.interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: false, linkState: .down)
        ]
        let pulledPath = NetworkPathInfo(
            status: .unavailable, isExpensive: false, isConstrained: false,
            supportsDNS: false, supportsIPv4: false, supportsIPv6: false,
            interfaces: []
        )
        pathProvider.emit(pulledPath)

        let stateA = await waitForReport(model) { $0?.verdict == .noInterface }
        XCTAssertEqual(stateA?.verdict, .noInterface, "载波 down 后 App 报告必须为 noInterface")

        collector.interfaces = [en0Up]
        pathProvider.emit(availablePath)

        let stateB = await waitForReport(model) { $0?.verdict != .noInterface && $0?.health != .critical }
        XCTAssertNotNil(stateB, "载波恢复后 App 必须脱离 noInterface")
    }

    // MARK: LC-A5：回归基线 — 既有 ET-A 行为零破坏
    @MainActor
    func testLCA5RegressionBaselinePreserved() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let selected = LocalMacSelector.preferredInterface(in: interfaces)
        XCTAssertEqual(selected?.name, "en0", "物理断开时仍优先物理卡")
        XCTAssertTrue(LocalMacSelector.physicalActive(interfaces).isEmpty, "物理活跃为空")
    }

    // MARK: LC-A6：活动接口计数反映真实物理连接数
    @MainActor
    func testLCA6ActiveCountReflectsPhysicalReality() {
        let en0Wifi = makeInterface(name: "en0", kind: .wifi, isActive: true, linkState: .up,
                                    addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.180")])
        let en1WiredDown = makeInterface(name: "en1", kind: .wired, isActive: false, linkState: .down)
        let utun0 = makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)

        let activity = OverviewActivity.compute([en0Wifi, en1WiredDown, utun0])
        XCTAssertEqual(activity.count, 1, "仅 en0 物理活跃，utun0 不计入物理口径")
        XCTAssertEqual(activity.names, ["en0"])

        let en1WiredUp = makeInterface(name: "en1", kind: .wired, isActive: true, linkState: .up,
                                       addresses: [IPAddressInfo(family: "IPv4", address: "10.0.0.5")])
        let activity2 = OverviewActivity.compute([en0Wifi, en1WiredUp, utun0])
        XCTAssertEqual(activity2.count, 2, "en0 + en1 物理活跃")
        XCTAssertEqual(activity2.names, ["en0", "en1"])
    }

    @MainActor
    private func waitForReport(
        _ model: AppModel,
        condition: @escaping (DiagnosisReport?) -> Bool
    ) async -> DiagnosisReport? {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if condition(model.report) { return model.report }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return model.report
    }
}