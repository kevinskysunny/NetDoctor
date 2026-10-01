import Foundation
import XCTest
@testable import NetworkCore

// MARK: - 测试夹具（本文件内定义，Mocks.swift 零改动）

struct TestRawDataSource: InterfaceRawDataProviding {
    let records: [InterfaceRawRecord]
    var isAvailable = true
    var fallbackRecords: [InterfaceRawRecord] = []

    func fetch() -> [InterfaceRawRecord] {
        isAvailable ? records : fallbackRecords
    }
}

struct TestHardwarePortSource: HardwarePortProviding {
    let ports: [HardwarePortRecord]

    func fetch() -> [HardwarePortRecord] {
        ports
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

// MARK: - ET-C 物理链路断开检测 Core 测试

final class EtherLinkDetectCoreTests: XCTestCase {
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

    // MARK: ET-C1：无 IP 物理网卡（仅 AF_LINK）保留
    func testETC1RetainsPhysicalInterfaceWithOnlyLinkLayer() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: UInt32(IFF_UP), family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(
                name: "utun0",
                flags: UInt32(IFF_UP) | UInt32(IFF_RUNNING),
                family: Int32(AF_INET6),
                addressString: "fe80::1"
            )
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: [])
        )
        let interfaces = collector.collect()

        let en0 = interfaces.first { $0.name == "en0" }
        XCTAssertNotNil(en0, "拔线后以太网卡必须保留")
        XCTAssertEqual(en0?.linkState, .down)
        XCTAssertEqual(en0?.isActive, false)
        XCTAssertEqual(en0?.addresses, [])

        let utun0 = interfaces.first { $0.name == "utun0" }
        XCTAssertEqual(utun0?.kind, .other)
    }

    // MARK: ET-C2：物理卡 UP 无 RUNNING → .down（严格判定，不允许 .unknown）
    func testETC2PhysicalInterfaceWithoutRunningIsDownNotUnknown() {
        for flags in [UInt32(IFF_UP), UInt32(IFF_RUNNING)] {
            let raw = TestRawDataSource(records: [
                InterfaceRawRecord(name: "en0", flags: flags, family: Int32(AF_LINK), addressString: nil)
            ])
            let collector = SystemInterfaceCollector(
                rawSource: raw,
                portSource: TestHardwarePortSource(ports: [])
            )
            let en0 = collector.collect().first { $0.name == "en0" }
            XCTAssertEqual(en0?.linkState, .down, "flags=\(flags) 必须判定为 down")
        }
    }

    // MARK: ET-C3：flags 读取失败 → .unknown 且 isActive == false
    func testETC3FlagsUnavailableYieldsUnknownAndInactive() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: nil, family: Int32(AF_LINK), addressString: nil)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: [])
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .unknown)
        XCTAssertEqual(en0?.isActive, false)
    }

    // MARK: ET-C4：isActive 与 linkState 一致性 + 确定性
    func testETC4ActiveConsistencyAndDeterminism() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(
                name: "en0",
                flags: UInt32(IFF_UP) | UInt32(IFF_RUNNING),
                family: Int32(AF_INET),
                addressString: "192.168.1.10"
            ),
            InterfaceRawRecord(
                name: "en1",
                flags: UInt32(IFF_UP),
                family: Int32(AF_INET),
                addressString: "192.168.2.10"
            )
        ])
        let firstRun = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: [])
        ).collect()
        let secondRun = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: [])
        ).collect()

        XCTAssertEqual(firstRun, secondRun, "相同输入必须产生相同输出（确定性）")

        let en0 = firstRun.first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up)
        XCTAssertEqual(en0?.isActive, true)

        let en1 = firstRun.first { $0.name == "en1" }
        XCTAssertEqual(en1?.linkState, .down)
        XCTAssertEqual(en1?.isActive, false)
    }

    // MARK: ET-C5：SC 硬件端口补全与类型修正
    func testETC5HardwarePortCompletionAndKindFix() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(
                name: "en0",
                flags: UInt32(IFF_UP) | UInt32(IFF_RUNNING),
                family: Int32(AF_INET),
                addressString: "192.168.1.10"
            )
        ])
        let ports = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi),
            HardwarePortRecord(bsdName: nil, displayName: "Ethernet Adapter", kind: .wired)
        ])
        let interfaces = SystemInterfaceCollector(
            rawSource: raw,
            portSource: ports
        ).collect()

        let en0 = interfaces.first { $0.name == "en0" }
        XCTAssertEqual(en0?.kind, .wifi, "SC 类型确认应修正 en0 为 wifi")

        let placeholder = interfaces.first { $0.name == "Ethernet Adapter" }
        XCTAssertNotNil(placeholder, "已配置未连接的以太网必须补入列表")
        XCTAssertEqual(placeholder?.kind, .wired)
        XCTAssertEqual(placeholder?.linkState, .down)
        XCTAssertEqual(placeholder?.isActive, false)
        XCTAssertEqual(placeholder?.addresses, [])
    }

    // MARK: ET-C6：虚拟网卡前缀分类
    func testETC6VirtualPrefixesAreOther() {
        let records = ["utun0", "ipsec0", "ppp0"].map {
            InterfaceRawRecord(
                name: $0,
                flags: UInt32(IFF_UP) | UInt32(IFF_RUNNING),
                family: Int32(AF_LINK),
                addressString: nil
            )
        }
        let interfaces = SystemInterfaceCollector(
            rawSource: TestRawDataSource(records: records),
            portSource: TestHardwarePortSource(ports: [])
        ).collect()

        for name in ["utun0", "ipsec0", "ppp0"] {
            XCTAssertEqual(interfaces.first { $0.name == name }?.kind, .other, "\(name) 应为 .other")
        }
    }

    // MARK: ET-C7：默认路由标记与链路状态解耦
    func testETC7DefaultRouteMarkerDecoupledFromLinkState() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: UInt32(IFF_UP), family: Int32(AF_LINK), addressString: nil)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            defaultRouteNames: ["en0"]
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.isDefaultRouteInterface, true)
        XCTAssertEqual(en0?.linkState, .down)
    }

    // MARK: ET-C8：物理全 down + utun up + probes 全失败 → noInterface + enableInterface + unreachable
    func testETC8PhysicalDownWithUtunAndAllProbesFail() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let grader = HealthGrader()
        let probes = [Self.probe(status: .failed)]
        let path = availablePath

        let grade = grader.grade(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        XCTAssertEqual(grade, .critical)

        let verdict = grader.verdict(
            grade: grade,
            score: 0,
            path: path,
            interfaces: interfaces,
            dns: .empty,
            routes: .empty,
            reachability: probes
        )
        XCTAssertEqual(verdict, .noInterface)

        let advice = grader.advice(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        XCTAssertTrue(advice.contains { $0.code == .enableInterface })
        XCTAssertTrue(advice.contains { $0.code == .unreachable })
    }

    // MARK: ET-C9：物理 up + utun up → 正常
    func testETC9PhysicalUpWithUtunIsHealthy() {
        let interfaces = [
            makeInterface(
                name: "en0",
                kind: .wired,
                isActive: true,
                linkState: .up,
                addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")]
            ),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let grader = HealthGrader()
        let probes = [Self.probe(status: .success, duration: 20)]
        let path = availablePath

        let grade = grader.grade(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        XCTAssertTrue(grade == .healthy || grade == .warning)

        let verdict = grader.verdict(
            grade: .healthy,
            score: 100,
            path: path,
            interfaces: interfaces,
            dns: .empty,
            routes: .empty,
            reachability: probes
        )
        XCTAssertNotEqual(verdict, .noInterface)
    }

    // MARK: ET-C10：仅 loopback + utun（无物理卡）→ noInterface + 通用引导
    func testETC10OnlyLoopbackAndUtunYieldsNoInterface() {
        let interfaces = [
            makeInterface(name: "lo0", kind: .loopback, isActive: true, linkState: .up),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let grader = HealthGrader()
        let path = availablePath
        let probes: [ReachabilityProbe] = []

        let grade = grader.grade(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        let verdict = grader.verdict(
            grade: grade,
            score: 0,
            path: path,
            interfaces: interfaces,
            dns: .empty,
            routes: .empty,
            reachability: probes
        )
        XCTAssertEqual(verdict, .noInterface)

        let advice = grader.advice(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        XCTAssertTrue(advice.contains { $0.code == .enableInterface })
        XCTAssertFalse(advice.contains { $0.message.contains("网线") }, "纯虚拟环境不断言具体物理断开")
    }

    // MARK: ET-C11：物理全断 + path unavailable + utun up → 仍为 noInterface（verdict 顺序调整验证）
    func testETC11NoInterfaceTakesPrecedenceOverOffline() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let path = NetworkPathInfo(
            status: .unavailable,
            isExpensive: false,
            isConstrained: false,
            supportsDNS: false,
            supportsIPv4: false,
            supportsIPv6: false,
            interfaces: []
        )
        let grader = HealthGrader()
        let probes: [ReachabilityProbe] = []

        let grade = grader.grade(path: path, interfaces: interfaces, dns: .empty, routes: .empty, reachability: probes)
        XCTAssertEqual(grade, .critical)

        let verdict = grader.verdict(
            grade: grade,
            score: 0,
            path: path,
            interfaces: interfaces,
            dns: .empty,
            routes: .empty,
            reachability: probes
        )
        XCTAssertEqual(verdict, .noInterface, "物理活跃为空时必须优先于 path 不可用判定")
    }

    // MARK: ET-C12：恢复闭环状态 A（拔线）
    func testETC12RecoveryStateARemovedLink() async {
        let en0Up = makeInterface(
            name: "en0",
            kind: .wired,
            isActive: true,
            linkState: .up,
            addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")]
        )
        let collector = MutableInterfaceCollector(interfaces: [en0Up])
        let pathProvider = MockPathProvider(path: availablePath)
        let engine = DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: collector,
            dnsCollector: MockDNSCollector(dns: .empty),
            routeCollector: MockRouteCollector(routes: .empty),
            reachabilityProber: MockReachabilityProber(result: []),
            eventStore: MemoryEventStore()
        )

        collector.interfaces = [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down)
        ]
        let report = await engine.performCheck(
            endpoints: [],
            attemptsPerEndpoint: 1,
            timeout: 1
        )
        XCTAssertEqual(report.interfaces.first?.linkState, .down)
        XCTAssertEqual(report.interfaces.first?.isActive, false)
        XCTAssertEqual(report.verdict, .noInterface)
    }

    // MARK: ET-C13：恢复闭环状态 B（插线恢复）
    func testETC13RecoveryStateBRepluggedLink() async {
        let collector = MutableInterfaceCollector(interfaces: [
            makeInterface(name: "en0", kind: .wired, isActive: false, linkState: .down)
        ])
        let pathProvider = MockPathProvider(path: availablePath)
        let engine = DiagnosticEngine(
            pathProvider: pathProvider,
            interfaceCollector: collector,
            dnsCollector: MockDNSCollector(dns: .empty),
            routeCollector: MockRouteCollector(routes: .empty),
            reachabilityProber: MockReachabilityProber(result: [Self.probe(status: .success, duration: 20)]),
            eventStore: MemoryEventStore()
        )

        collector.interfaces = [
            makeInterface(
                name: "en0",
                kind: .wired,
                isActive: true,
                linkState: .up,
                addresses: [IPAddressInfo(family: "IPv4", address: "192.168.1.10")]
            )
        ]
        let report = await engine.performCheck(
            endpoints: [],
            attemptsPerEndpoint: 1,
            timeout: 1
        )
        XCTAssertEqual(report.interfaces.first?.linkState, .up)
        XCTAssertEqual(report.interfaces.first?.isActive, true)
        XCTAssertFalse(report.interfaces.first?.addresses.isEmpty ?? true, "插线恢复后必须获取有效 IP")
        XCTAssertNotEqual(report.verdict, .noInterface)
        XCTAssertNotEqual(report.health, .critical)
    }

    // MARK: ET-C14：getifaddrs 失败降级
    func testETC14RawSourceUnavailableReturnsEmpty() {
        let collector = SystemInterfaceCollector(
            rawSource: TestRawDataSource(records: [], isAvailable: false),
            portSource: TestHardwarePortSource(ports: [])
        )
        XCTAssertEqual(collector.collect(), [])
    }

    // MARK: ET-C15：SC 端口源返回空 —— 降级不崩溃
    func testETC15EmptyPortSourceFallsBackToRaw() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: UInt32(IFF_UP), family: Int32(AF_LINK), addressString: nil)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: [])
        )
        let interfaces = collector.collect()
        XCTAssertFalse(interfaces.isEmpty, "SC 返回空时必须仅依赖 getifaddrs 结果")
        XCTAssertNotNil(interfaces.first { $0.name == "en0" })
    }

    private static func probe(status: ProbeStatus, duration: Double? = nil) -> ReachabilityProbe {
        ReachabilityProbe(
            endpointID: "a",
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