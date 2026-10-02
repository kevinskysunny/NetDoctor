import XCTest
import NetworkCore
@testable import NetworkConsoleApp

final class OverviewActivityCardTests: XCTestCase {

    // MARK: - 口径统一测试

    func testOverviewActivityPhysicalCountNotAllActive() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: true, linkState: .up),
            makeInterface(name: "en1", kind: .wired, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up),
            makeInterface(name: "utun1", kind: .other, isActive: true, linkState: .up),
            makeInterface(name: "awdl0", kind: .other, isActive: true, linkState: .up),
            makeInterface(name: "bridge0", kind: .other, isActive: true, linkState: .up)
        ]
        let activity = OverviewActivity.compute(interfaces)
        XCTAssertEqual(activity.count, 1, "物理口径计数应为 1（仅 en0）")
        XCTAssertEqual(activity.names, ["en0"])
        XCTAssertFalse(activity.degraded)
    }

    func testOverviewActivityDegradedWhenNoPhysicalButVirtualActive() {
        let interfaces = [
            makeInterface(name: "en0", kind: .wifi, isActive: false, linkState: .down),
            makeInterface(name: "utun0", kind: .other, isActive: true, linkState: .up)
        ]
        let activity = OverviewActivity.compute(interfaces)
        XCTAssertEqual(activity.count, 0)
        XCTAssertTrue(activity.degraded, "物理全断但有虚拟活跃 → degraded")
    }

    // MARK: - L10n 新增 key 存在性断言

    func testNewL10nKeysExistInAllLanguages() {
        let keys = [
            "interfaces.filter.physical",
            "interfaces.filter.tunnels",
            "interfaces.filter.all",
            "interfaces.category.tunnel",
            "interfaces.category.appleP2P",
            "interfaces.category.bridge",
            "interfaces.category.hardwareBus"
        ]
        let languages: [AppLanguage] = [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]
        for key in keys {
            for lang in languages {
                let value = L10n.string(key, language: lang)
                XCTAssertNotEqual(value, key, "\(lang.rawValue) 缺失 key: \(key)")
            }
        }
    }

    // MARK: - 辅助

    private func makeInterface(
        name: String,
        kind: InterfaceKind,
        isActive: Bool,
        linkState: LinkState
    ) -> InterfaceInfo {
        InterfaceInfo(
            id: name, name: name, kind: kind, isActive: isActive,
            addresses: [], ssid: nil, linkState: linkState,
            isDefaultRouteInterface: false
        )
    }
}