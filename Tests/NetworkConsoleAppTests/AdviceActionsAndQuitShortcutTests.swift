import AppKit
import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

@MainActor
final class AdviceActionsAndQuitShortcutTests: XCTestCase {

    // MARK: - ⌘Q 快捷键与菜单测试

    func testQuitMenuItemEnforcesCommandQShortcut() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "NetDoctor", action: nil, keyEquivalent: "")
        let appSubmenu = NSMenu(title: "NetDoctor")

        // 模拟原本缺少快捷键或快捷键为空串的退出菜单项
        let quitItem = NSMenuItem(
            title: "Quit NetDoctor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        quitItem.keyEquivalentModifierMask = []
        appSubmenu.addItem(quitItem)
        appItem.submenu = appSubmenu
        mainMenu.addItem(appItem)

        // 执行本地化与快捷键加固
        MenuLocalizer.update(mainMenu: mainMenu, language: .english, appName: "NetDoctor")

        XCTAssertEqual(quitItem.keyEquivalent, "q", "退出菜单项必须绑定 'q' 键")
        XCTAssertEqual(quitItem.keyEquivalentModifierMask, .command, "退出菜单项修饰键必须为 ⌘ (Command)")
    }

    func testQuitMenuItemRetainsCommandQAcrossLanguageSwitching() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "NetDoctor", action: nil, keyEquivalent: "")
        let appSubmenu = NSMenu(title: "NetDoctor")

        let quitItem = NSMenuItem(
            title: "退出 NetDoctor",
            action: Selector(("terminate:")),
            keyEquivalent: ""
        )
        appSubmenu.addItem(quitItem)
        appItem.submenu = appSubmenu
        mainMenu.addItem(appItem)

        let testLanguages: [AppLanguage] = [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]
        for lang in testLanguages {
            MenuLocalizer.update(mainMenu: mainMenu, language: lang, appName: "NetDoctor")
            XCTAssertEqual(quitItem.keyEquivalent, "q", "\(lang.rawValue) 语言下退出菜单项必须保持 'q' 键")
            XCTAssertEqual(quitItem.keyEquivalentModifierMask, .command, "\(lang.rawValue) 语言下退出菜单项必须保持 ⌘ 键")
        }
    }

    // MARK: - 排查建议直达按钮 (AdviceActions) 测试

    func testAdviceActionsForEnableInterface() {
        let actions = AdviceActions.items(for: .enableInterface)
        XCTAssertEqual(actions.count, 2, "启用网络接口建议需提供以太网和 Wi-Fi 2 个快捷按钮")

        XCTAssertEqual(actions[0].pane, .ethernet)
        XCTAssertEqual(actions[0].titleKey, "action.openSettings.ethernet")
        XCTAssertEqual(actions[0].systemImage, "cable.connector")

        XCTAssertEqual(actions[1].pane, .wifi)
        XCTAssertEqual(actions[1].titleKey, "action.openSettings.wifi")
        XCTAssertEqual(actions[1].systemImage, "wifi")
    }

    func testAdviceActionsForCheckDNS() {
        let actions = AdviceActions.items(for: .checkDNS)
        XCTAssertEqual(actions.count, 1, "DNS 排查建议需提供 1 个 DNS 直达按钮")

        XCTAssertEqual(actions[0].pane, .dns)
        XCTAssertEqual(actions[0].titleKey, "action.openSettings.dns")
        XCTAssertEqual(actions[0].systemImage, "server.rack")
    }

    func testAdviceActionsForConfirmConnection() {
        let actions = AdviceActions.items(for: .confirmConnection)
        XCTAssertEqual(actions.count, 2, "确认连接建议需提供 Wi-Fi 与系统网络设置直达按钮")
        XCTAssertEqual(actions[0].pane, .wifi)
        XCTAssertEqual(actions[1].pane, .network)
    }

    func testAdviceActionsForNetworkTroubleshooting() {
        let failureCodes: [AdviceCode] = [.checkRoute, .unreachable, .partialUnreachable, .constrained, .highLatency]
        for code in failureCodes {
            let actions = AdviceActions.items(for: code)
            XCTAssertEqual(actions.count, 1, "\(code) 需提供 1 个网络设置直达按钮")
            XCTAssertEqual(actions[0].pane, .network)
            XCTAssertEqual(actions[0].titleKey, "action.openSettings.network")
        }
    }

    func testAdviceActionsForHealthyAndUnknownIsEmpty() {
        XCTAssertTrue(AdviceActions.items(for: .healthy).isEmpty, "健康状态下无需显示直达设置按钮")
        XCTAssertTrue(AdviceActions.items(for: .unknown).isEmpty, "未知状态下无需显示直达设置按钮")
    }

    func testAllAdviceActionTitleKeysExistInAll8Languages() {
        let allCodes = AdviceCode.allCases
        let languages: [AppLanguage] = [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]

        for code in allCodes {
            let actions = AdviceActions.items(for: code)
            for action in actions {
                for lang in languages {
                    let localized = L10n.string(action.titleKey, language: lang)
                    XCTAssertNotEqual(localized, action.titleKey, "语言 \(lang.rawValue) 必须包含按键字典: \(action.titleKey)")
                    XCTAssertFalse(localized.isEmpty, "本地化文案不能为空")
                }
            }
        }
    }
}
