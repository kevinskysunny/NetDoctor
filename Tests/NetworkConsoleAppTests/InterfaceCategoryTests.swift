import XCTest
import NetworkCore
@testable import NetworkConsoleApp

final class InterfaceCategoryTests: XCTestCase {

    // MARK: - 分类器测试

    func testWifiKindResolvesToWifi() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .wifi, name: "en0"), .wifi)
    }

    func testWiredKindResolvesToWired() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .wired, name: "en1"), .wired)
    }

    func testCellularKindResolvesToCellular() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .cellular, name: "ap1"), .cellular)
    }

    func testLoopbackKindResolvesToLoopback() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .loopback, name: "lo0"), .loopback)
    }

    func testUtunPrefixResolvesToTunnel() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "utun0"), .tunnel)
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "utun1024"), .tunnel)
    }

    func testIpsecPrefixResolvesToTunnel() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "ipsec0"), .tunnel)
    }

    func testPppPrefixResolvesToTunnel() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "ppp0"), .tunnel)
    }

    func testAwdlPrefixResolvesToAppleP2P() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "awdl0"), .appleP2P)
    }

    func testLlwPrefixResolvesToAppleP2P() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "llw0"), .appleP2P)
    }

    func testNanPrefixResolvesToAppleP2P() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "nan0"), .appleP2P)
    }

    func testBridgePrefixResolvesToBridge() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "bridge0"), .bridge)
    }

    func testAnpiPrefixResolvesToHardwareBus() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "anpi0"), .hardwareBus)
    }

    func testGifPrefixResolvesToSystemTunnel() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "gif0"), .systemTunnel)
    }

    func testStfPrefixResolvesToSystemTunnel() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "stf0"), .systemTunnel)
    }

    func testUnknownPrefixResolvesToOther() {
        XCTAssertEqual(InterfaceCategoryResolver.resolve(kind: .other, name: "unknown0"), .other)
    }

    // MARK: - 筛选器测试

    func testPhysicalFilterReturnsOnlyPhysicalInterfaces() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi),
            makeInterface(name: "en1", kind: .wired),
            makeInterface(name: "ap1", kind: .cellular),
            makeInterface(name: "utun0", kind: .other),
            makeInterface(name: "lo0", kind: .loopback)
        ]
        let result = InterfaceFilterApplier.apply(.physical, to: interfaces)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.name), ["en0", "en1", "ap1"])
    }

    func testTunnelsFilterReturnsOnlyTunnelInterfaces() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi),
            makeInterface(name: "utun0", kind: .other),
            makeInterface(name: "utun1", kind: .other),
            makeInterface(name: "ipsec0", kind: .other),
            makeInterface(name: "ppp0", kind: .other),
            makeInterface(name: "awdl0", kind: .other),
            makeInterface(name: "bridge0", kind: .other)
        ]
        let result = InterfaceFilterApplier.apply(.tunnels, to: interfaces)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.map(\.name), ["utun0", "utun1", "ipsec0", "ppp0"])
    }

    func testAllFilterReturnsAllInterfaces() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi),
            makeInterface(name: "utun0", kind: .other),
            makeInterface(name: "lo0", kind: .loopback)
        ]
        let result = InterfaceFilterApplier.apply(.all, to: interfaces)
        XCTAssertEqual(result.count, 3)
    }

    func testEmptyInterfacesForAllFilters() {
        let interfaces: [InterfaceInfo] = []
        XCTAssertEqual(InterfaceFilterApplier.apply(.physical, to: interfaces).count, 0)
        XCTAssertEqual(InterfaceFilterApplier.apply(.tunnels, to: interfaces).count, 0)
        XCTAssertEqual(InterfaceFilterApplier.apply(.all, to: interfaces).count, 0)
    }

    // MARK: - 样式测试

    func testCategoryStyleReturnsCorrectSfSymbol() {
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .wifi).sfSymbol, "wifi")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .wired).sfSymbol, "cable.connector")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .tunnel).sfSymbol, "lock.shield")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .appleP2P).sfSymbol, "airplayaudio")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .bridge).sfSymbol, "point.3.connected.trianglepath.dotted")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .hardwareBus).sfSymbol, "cpu")
    }

    func testCategoryStyleReturnsCorrectL10nKey() {
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .tunnel).l10nKey, "interfaces.category.tunnel")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .appleP2P).l10nKey, "interfaces.category.appleP2P")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .bridge).l10nKey, "interfaces.category.bridge")
        XCTAssertEqual(InterfaceCategoryStyle.style(for: .hardwareBus).l10nKey, "interfaces.category.hardwareBus")
    }

    // MARK: - 辅助

    private func makeInterface(name: String, kind: InterfaceKind) -> InterfaceInfo {
        InterfaceInfo(
            id: name, name: name, kind: kind, isActive: true,
            addresses: [], ssid: nil, linkState: .up,
            isDefaultRouteInterface: false
        )
    }
}