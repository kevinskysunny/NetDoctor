import Foundation
import XCTest
@testable import NetworkCore

// MARK: - 测试夹具（本文件内定义，Mocks.swift / EtherLinkDetectCoreTests.swift 零改动）

struct TestLinkCarrierSource: LinkCarrierProviding {
    let records: [LinkCarrierRecord]
    var isAvailable = true

    func fetch(interfaceNames: [String]) -> [LinkCarrierRecord] {
        guard isAvailable else { return [] }
        let byName = Dictionary(records.map { ($0.interfaceName, $0) }, uniquingKeysWith: { first, _ in first })
        return interfaceNames.compactMap { byName[$0] }
    }
}

// MARK: - LC-C 载波误判修复 Core 测试

final class LinkCarrierFixCoreTests: XCTestCase {
    private let upRunning = UInt32(IFF_UP) | UInt32(IFF_RUNNING)

    // MARK: LC-C1：雷雳网口 IFF_RUNNING 常驻 + Carrier Active==false → .down
    func testLCC1ThunderboltRunningButCarrierFalseYieldsDown() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en1", active: false)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let en1 = collector.collect().first { $0.name == "en1" }
        XCTAssertEqual(en1?.linkState, .down, "IFF_RUNNING 常驻但 Carrier Active==false 必须判定为 down")
        XCTAssertEqual(en1?.isActive, false)
    }

    // MARK: LC-C2：Carrier Active==true + UP+RUNNING → .up（wired）
    func testLCC2CarrierTrueWithUpRunningYieldsUp() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10")
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up)
        XCTAssertEqual(en0?.isActive, true)
    }

    // MARK: LC-C3：Carrier Active==nil（无记录）+ wired 有 IP + UP+RUNNING → .up（降级）
    func testLCC3CarrierNilWiredWithIPYieldsUpDegraded() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10")
        ])
        let carrier = TestLinkCarrierSource(records: [])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up, "降级模式 wired 有 IP + UP+RUNNING → up")
    }

    // MARK: LC-C4：Carrier Active==nil + wired 无 IP + UP+RUNNING → .down（降级）
    func testLCC4CarrierNilWiredWithoutIPYieldsDownDegraded() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let en1 = collector.collect().first { $0.name == "en1" }
        XCTAssertEqual(en1?.linkState, .down, "降级模式 wired 无 IP → down")
    }

    // MARK: LC-C5：Wi-Fi Carrier Active==false → .down
    func testLCC5WifiCarrierFalseYieldsDown() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: false)
        ])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: port,
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .down)
        XCTAssertEqual(en0?.isActive, false)
    }

    // MARK: LC-C6：Wi-Fi Carrier Active==true + UP+RUNNING → .up
    func testLCC6WifiCarrierTrueYieldsUp() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10")
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true)
        ])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: port,
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up)
        XCTAssertEqual(en0?.isActive, true)
    }

    // MARK: LC-C7：Wi-Fi Carrier Active==nil + UP+RUNNING → .up（降级，wifi 不要求 IP）
    func testLCC7WifiCarrierNilYieldsUpDegraded() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: port,
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up, "降级模式 wifi 不要求 IP，UP+RUNNING → up")
    }

    // MARK: LC-C8：flags==nil → .unknown（无论 carrier）
    func testLCC8FlagsNilYieldsUnknownRegardlessCarrier() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: nil, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let en0 = collector.collect().first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .unknown)
        XCTAssertEqual(en0?.isActive, false)
    }

    // MARK: LC-C9：loopback 不受 carrierActive 影响
    func testLCC9LoopbackUnaffectedByCarrier() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "lo0", flags: upRunning, family: Int32(AF_INET), addressString: "127.0.0.1")
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "lo0", active: false)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let lo0 = collector.collect().first { $0.name == "lo0" }
        XCTAssertEqual(lo0?.linkState, .up, "loopback 不查询 carrier，按 flags 判定")
    }

    // MARK: LC-C10：other（utun）不受 carrierActive 影响
    func testLCC10OtherUnaffectedByCarrier() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "utun0", flags: upRunning, family: Int32(AF_INET6), addressString: "fe80::1")
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "utun0", active: false)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let utun0 = collector.collect().first { $0.name == "utun0" }
        XCTAssertEqual(utun0?.linkState, .up, "utun 不查询 carrier，按 flags 判定")
    }

    // MARK: LC-C11：纯 Wi-Fi 环境 — 活动接口数 == 1（仅 en0）
    func testLCC11PureWifiEnvironmentActiveCountIsOne() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.180"),
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en2", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en3", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en5", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en6", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en8", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true),
            LinkCarrierRecord(interfaceName: "en1", active: false),
            LinkCarrierRecord(interfaceName: "en2", active: false),
            LinkCarrierRecord(interfaceName: "en3", active: false),
            LinkCarrierRecord(interfaceName: "en5", active: false),
            LinkCarrierRecord(interfaceName: "en6", active: false),
            LinkCarrierRecord(interfaceName: "en8", active: false)
        ])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi),
            HardwarePortRecord(bsdName: "en1", displayName: "Thunderbolt 1", kind: .wired),
            HardwarePortRecord(bsdName: "en2", displayName: "Thunderbolt 2", kind: .wired),
            HardwarePortRecord(bsdName: "en3", displayName: "Thunderbolt 3", kind: .wired),
            HardwarePortRecord(bsdName: "en5", displayName: "USB LAN", kind: .wired),
            HardwarePortRecord(bsdName: "en6", displayName: "Thunderbolt 4", kind: .wired),
            HardwarePortRecord(bsdName: "en8", displayName: "USB LAN 2", kind: .wired)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: port,
            linkCarrierSource: carrier
        )
        let interfaces = collector.collect()
        let active = interfaces.filter(\.isActive)
        XCTAssertEqual(active.count, 1, "纯 Wi-Fi 环境活动接口数必须为 1")
        XCTAssertEqual(active.first?.name, "en0")
    }

    // MARK: LC-C12：载波翻转闭环（未插线 → 插线恢复）
    func testLCC12CarrierFlipRecovery() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en1", displayName: "Thunderbolt", kind: .wired)
        ])

        let carrierDown = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en1", active: false)
        ])
        let stateDown = SystemInterfaceCollector(
            rawSource: raw, portSource: port, linkCarrierSource: carrierDown
        ).collect().first { $0.name == "en1" }
        XCTAssertEqual(stateDown?.linkState, .down)
        XCTAssertEqual(stateDown?.isActive, false)

        let rawUp = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_INET), addressString: "10.0.0.5")
        ])
        let carrierUp = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en1", active: true)
        ])
        let stateUp = SystemInterfaceCollector(
            rawSource: rawUp, portSource: port, linkCarrierSource: carrierUp
        ).collect().first { $0.name == "en1" }
        XCTAssertEqual(stateUp?.linkState, .up)
        XCTAssertEqual(stateUp?.isActive, true)
    }

    // MARK: LC-C13：SCDynamicStore 不可用 → 全量降级到 flags+IP
    func testLCC13SCDynamicStoreUnavailableDegradesGracefully() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10"),
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [], isAvailable: false)
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let interfaces = collector.collect()
        let en0 = interfaces.first { $0.name == "en0" }
        XCTAssertEqual(en0?.linkState, .up, "降级 en0 有 IP → up")
        let en1 = interfaces.first { $0.name == "en1" }
        XCTAssertEqual(en1?.linkState, .down, "降级 en1 无 IP → down")
    }

    // MARK: LC-C14：确定性 — 相同输入恒有相同输出
    func testLCC14Determinism() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10"),
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true),
            LinkCarrierRecord(interfaceName: "en1", active: false)
        ])
        let first = SystemInterfaceCollector(
            rawSource: raw, portSource: TestHardwarePortSource(ports: []), linkCarrierSource: carrier
        ).collect()
        let second = SystemInterfaceCollector(
            rawSource: raw, portSource: TestHardwarePortSource(ports: []), linkCarrierSource: carrier
        ).collect()
        XCTAssertEqual(first, second)
    }

    // MARK: LC-C15：雷雳 en1~en3 IFF_RUNNING 常驻 + Carrier false → 全部 down
    func testLCC15MultipleThunderboltAllDown() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en2", flags: upRunning, family: Int32(AF_LINK), addressString: nil),
            InterfaceRawRecord(name: "en3", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en1", active: false),
            LinkCarrierRecord(interfaceName: "en2", active: false),
            LinkCarrierRecord(interfaceName: "en3", active: false)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let interfaces = collector.collect()
        for name in ["en1", "en2", "en3"] {
            let iface = interfaces.first { $0.name == name }
            XCTAssertEqual(iface?.linkState, .down, "\(name) 必须为 down")
            XCTAssertEqual(iface?.isActive, false, "\(name) 必须为 inactive")
        }
    }

    // MARK: LC-C16：多物理网卡混合 carrier 状态
    func testLCC16MixedCarrierStates() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10"),
            InterfaceRawRecord(name: "en1", flags: upRunning, family: Int32(AF_INET), addressString: "10.0.0.5"),
            InterfaceRawRecord(name: "en2", flags: upRunning, family: Int32(AF_LINK), addressString: nil)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true),
            LinkCarrierRecord(interfaceName: "en1", active: true),
            LinkCarrierRecord(interfaceName: "en2", active: false)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: TestHardwarePortSource(ports: []),
            linkCarrierSource: carrier
        )
        let interfaces = collector.collect()
        XCTAssertEqual(interfaces.first { $0.name == "en0" }?.isActive, true)
        XCTAssertEqual(interfaces.first { $0.name == "en1" }?.isActive, true)
        XCTAssertEqual(interfaces.first { $0.name == "en2" }?.isActive, false)
        XCTAssertEqual(interfaces.filter(\.isActive).count, 2)
    }

    // MARK: LC-C17：resolveLinkState 纯函数 — wired 降级 hasValidIP=false → down
    func testLCC17ResolveLinkStateWiredDegradedNoIPYieldsDown() {
        let result = resolveLinkState(flags: upRunning, kind: .wired, carrierActive: nil, hasValidIP: false)
        XCTAssertEqual(result, .down)
    }

    // MARK: LC-C18：resolveLinkState 纯函数 — wired 降级 hasValidIP=true → up
    func testLCC18ResolveLinkStateWiredDegradedWithIPYieldsUp() {
        let result = resolveLinkState(flags: upRunning, kind: .wired, carrierActive: nil, hasValidIP: true)
        XCTAssertEqual(result, .up)
    }

    // MARK: LC-C19：resolveLinkState 纯函数矩阵 — 全组合确定性
    func testLCC19ResolveLinkStatePureFunctionMatrix() {
        let flagsCases: [UInt32?] = [nil, upRunning, UInt32(IFF_UP), UInt32(IFF_RUNNING), 0]
        let kinds: [InterfaceKind] = [.wired, .wifi, .cellular, .loopback, .other]
        let carriers: [Bool?] = [nil, true, false]
        let ipCases: [Bool] = [true, false]
        for flags in flagsCases {
            for kind in kinds {
                for carrier in carriers {
                    for hasIP in ipCases {
                        let a = resolveLinkState(flags: flags, kind: kind, carrierActive: carrier, hasValidIP: hasIP)
                        let b = resolveLinkState(flags: flags, kind: kind, carrierActive: carrier, hasValidIP: hasIP)
                        XCTAssertEqual(a, b, "纯函数确定性: flags=\(String(describing: flags)) kind=\(kind) carrier=\(String(describing: carrier)) ip=\(hasIP)")
                    }
                }
            }
        }
    }

    // MARK: LC-C20：占位记录不查询 carrier，直置 .down
    func testLCC20PlaceholderRecordsDoNotQueryCarrier() {
        let raw = TestRawDataSource(records: [
            InterfaceRawRecord(name: "en0", flags: upRunning, family: Int32(AF_INET), addressString: "192.168.1.10")
        ])
        let port = TestHardwarePortSource(ports: [
            HardwarePortRecord(bsdName: "en0", displayName: "Wi-Fi", kind: .wifi),
            HardwarePortRecord(bsdName: "en9", displayName: "Thunderbolt", kind: .wired)
        ])
        let carrier = TestLinkCarrierSource(records: [
            LinkCarrierRecord(interfaceName: "en0", active: true),
            LinkCarrierRecord(interfaceName: "en9", active: true)
        ])
        let collector = SystemInterfaceCollector(
            rawSource: raw,
            portSource: port,
            linkCarrierSource: carrier
        )
        let interfaces = collector.collect()
        let en9 = interfaces.first { $0.name == "en9" }
        XCTAssertEqual(en9?.linkState, .down, "占位记录直置 down，不查询 carrier")
        XCTAssertEqual(en9?.isActive, false)
    }
}