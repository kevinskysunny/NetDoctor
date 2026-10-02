import AppKit
import XCTest
@testable import NetworkConsoleApp

@MainActor
final class MenuLocalizerTests: XCTestCase {
    func testLocalizeChineseMenuToEnglish() {
        let mainMenu = NSMenu()

        // 0. App menu
        let appMenuItem = NSMenuItem(title: "NetDoctor", action: nil, keyEquivalent: "")
        let appSubmenu = NSMenu(title: "NetDoctor")
        appSubmenu.addItem(NSMenuItem(title: "关于 NetDoctor", action: Selector(("orderFrontStandardAboutPanel:")), keyEquivalent: ""))
        appSubmenu.addItem(NSMenuItem(title: "设置...", action: Selector(("showSettingsWindow:")), keyEquivalent: ","))
        appSubmenu.addItem(NSMenuItem(title: "服务", action: nil, keyEquivalent: ""))
        appSubmenu.addItem(NSMenuItem(title: "隐藏 NetDoctor", action: Selector(("hide:")), keyEquivalent: "h"))
        appSubmenu.addItem(NSMenuItem(title: "隐藏其他", action: Selector(("hideOtherApplications:")), keyEquivalent: "h"))
        appSubmenu.addItem(NSMenuItem(title: "全部显示", action: Selector(("unhideAllApplications:")), keyEquivalent: ""))
        appSubmenu.addItem(NSMenuItem(title: "退出 NetDoctor", action: Selector(("terminate:")), keyEquivalent: "q"))
        appMenuItem.submenu = appSubmenu
        mainMenu.addItem(appMenuItem)

        // 1. Edit menu
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editSubmenu = NSMenu(title: "编辑")
        editSubmenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editSubmenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editSubmenu.addItem(NSMenuItem(title: "剪切", action: Selector(("cut:")), keyEquivalent: "x"))
        editSubmenu.addItem(NSMenuItem(title: "拷贝", action: Selector(("copy:")), keyEquivalent: "c"))
        editSubmenu.addItem(NSMenuItem(title: "粘贴", action: Selector(("paste:")), keyEquivalent: "v"))
        editSubmenu.addItem(NSMenuItem(title: "全选", action: Selector(("selectAll:")), keyEquivalent: "a"))
        let autoFillItem = NSMenuItem(title: "自动填充", action: nil, keyEquivalent: "")
        let autoFillSub = NSMenu(title: "自动填充")
        autoFillSub.addItem(NSMenuItem(title: "联系人...", action: nil, keyEquivalent: ""))
        autoFillSub.addItem(NSMenuItem(title: "密码...", action: nil, keyEquivalent: ""))
        autoFillSub.addItem(NSMenuItem(title: "信用卡...", action: nil, keyEquivalent: ""))
        autoFillItem.submenu = autoFillSub
        editSubmenu.addItem(autoFillItem)
        editSubmenu.addItem(NSMenuItem(title: "开始听写...", action: Selector(("startDictation:")), keyEquivalent: ""))
        editSubmenu.addItem(NSMenuItem(title: "表情与符号", action: Selector(("orderFrontCharacterPalette:")), keyEquivalent: ""))
        editItem.submenu = editSubmenu
        mainMenu.addItem(editItem)

        // 2. View menu
        let viewItem = NSMenuItem(title: "显示", action: nil, keyEquivalent: "")
        let viewSubmenu = NSMenu(title: "显示")
        viewSubmenu.addItem(NSMenuItem(title: "显示标签页栏", action: Selector(("toggleTabBar:")), keyEquivalent: ""))
        viewSubmenu.addItem(NSMenuItem(title: "显示所有标签页", action: Selector(("toggleTabOverview:")), keyEquivalent: "\\"))
        viewSubmenu.addItem(NSMenuItem(title: "进入全屏幕", action: Selector(("toggleFullScreen:")), keyEquivalent: "f"))
        viewItem.submenu = viewSubmenu
        mainMenu.addItem(viewItem)

        // 3. Window menu (Matches user screenshot)
        let windowItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowSubmenu = NSMenu(title: "窗口")
        windowSubmenu.addItem(NSMenuItem(title: "关闭", action: Selector(("performClose:")), keyEquivalent: "w"))
        windowSubmenu.addItem(NSMenuItem(title: "最小化", action: Selector(("performMiniaturize:")), keyEquivalent: "m"))
        windowSubmenu.addItem(NSMenuItem(title: "缩放", action: Selector(("performZoom:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "填充", action: nil, keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "居中", action: nil, keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "移动与调整大小", action: nil, keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "全屏幕平铺", action: nil, keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "前置全部窗口", action: Selector(("arrangeInFront:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "从组中移除窗口", action: Selector(("removeWindowFromGroup:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "显示上一个标签页", action: Selector(("selectPreviousTab:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "显示下一个标签页", action: Selector(("selectNextTab:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "将标签页移到新窗口", action: Selector(("moveTabToNewWindow:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "合并所有窗口", action: Selector(("mergeAllWindows:")), keyEquivalent: ""))
        windowItem.submenu = windowSubmenu
        mainMenu.addItem(windowItem)

        // 4. Help menu
        let helpItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu(title: "帮助")
        helpSubmenu.addItem(NSMenuItem(title: "NetDoctor 帮助", action: Selector(("showHelp:")), keyEquivalent: "?"))
        helpItem.submenu = helpSubmenu
        mainMenu.addItem(helpItem)

        // 执行本地化至 English
        MenuLocalizer.update(mainMenu: mainMenu, language: .english, appName: "NetDoctor")

        // 验证顶层菜单栏全部变为英文
        XCTAssertEqual(mainMenu.items[0].title, "NetDoctor")
        XCTAssertEqual(mainMenu.items[1].title, "Edit")
        XCTAssertTrue(mainMenu.items[1].isHidden) // 编辑菜单已被隐藏
        XCTAssertEqual(mainMenu.items[2].title, "View")
        XCTAssertEqual(mainMenu.items[3].title, "Window")
        XCTAssertEqual(mainMenu.items[4].title, "Help")

        // 验证 Window 子菜单全部变为英文（用户截图红框关注点）
        let winItems = windowSubmenu.items
        XCTAssertEqual(winItems[0].title, "Close")
        XCTAssertEqual(winItems[1].title, "Minimize")
        XCTAssertEqual(winItems[2].title, "Zoom")
        XCTAssertEqual(winItems[3].title, "Fill")
        XCTAssertEqual(winItems[4].title, "Center")
        XCTAssertEqual(winItems[5].title, "Move & Resize")
        XCTAssertEqual(winItems[6].title, "Tile")
        XCTAssertEqual(winItems[7].title, "Bring All to Front")
        XCTAssertEqual(winItems[8].title, "Remove Window from Set")
        XCTAssertTrue(winItems[8].isHidden) // 冗余项已被隐藏
        XCTAssertEqual(winItems[9].title, "Show Previous Tab")
        XCTAssertTrue(winItems[9].isHidden)
        XCTAssertEqual(winItems[10].title, "Show Next Tab")
        XCTAssertTrue(winItems[10].isHidden)
        XCTAssertEqual(winItems[11].title, "Move Tab to New Window")
        XCTAssertTrue(winItems[11].isHidden)
        XCTAssertEqual(winItems[12].title, "Merge All Windows")
        XCTAssertTrue(winItems[12].isHidden)

        // 验证 View 子菜单全部变为英文（用户截图关注点）
        let viewItems = viewSubmenu.items
        XCTAssertEqual(viewItems[0].title, "Show Tab Bar")
        XCTAssertTrue(viewItems[0].isHidden)
        XCTAssertEqual(viewItems[1].title, "Show All Tabs")
        XCTAssertTrue(viewItems[1].isHidden)
        XCTAssertEqual(viewItems[2].title, "Enter Full Screen")

        // 验证 App 子菜单
        let appItems = appSubmenu.items
        XCTAssertEqual(appItems[0].title, "About NetDoctor")
        XCTAssertEqual(appItems[1].title, "Settings...")
        XCTAssertEqual(appItems[1].action, #selector(AppDelegate.openSettingsWindow(_:)))
        XCTAssertEqual(appItems[2].title, "Services")
        XCTAssertTrue(appItems[2].isHidden) // 服务菜单属于冗余项，已被隐藏
        XCTAssertEqual(appItems[3].title, "Hide NetDoctor")
        XCTAssertEqual(appItems[4].title, "Hide Others")
        XCTAssertEqual(appItems[5].title, "Show All")
        XCTAssertEqual(appItems[6].title, "Quit NetDoctor")

        // 验证 Edit 子菜单（包含用户截图红框内的自动填充、听写、表情符号）
        let edItems = editSubmenu.items
        XCTAssertEqual(edItems[0].title, "Undo")
        XCTAssertTrue(edItems[0].isHidden)
        XCTAssertEqual(edItems[1].title, "Redo")
        XCTAssertTrue(edItems[1].isHidden)
        XCTAssertEqual(edItems[2].title, "Cut")
        XCTAssertEqual(edItems[3].title, "Copy")
        XCTAssertEqual(edItems[4].title, "Paste")
        XCTAssertEqual(edItems[5].title, "Select All")
        XCTAssertEqual(edItems[6].title, "AutoFill")
        XCTAssertTrue(edItems[6].isHidden)
        XCTAssertEqual(edItems[6].submenu?.items[0].title, "Contact Info...")
        XCTAssertEqual(edItems[6].submenu?.items[1].title, "Passwords...")
        XCTAssertEqual(edItems[6].submenu?.items[2].title, "Credit Cards...")
        XCTAssertEqual(edItems[7].title, "Start Dictation...")
        XCTAssertTrue(edItems[7].isHidden)
        XCTAssertEqual(edItems[8].title, "Emoji & Symbols")

        // 验证 Help 菜单（解决点击报错未找到帮助的问题，且包含在线文档与隐私政策与官网）
        let helpItems = helpSubmenu.items
        XCTAssertEqual(helpItems[0].title, "NetDoctor Help")
        XCTAssertEqual(helpItems[0].action, #selector(AppDelegate.showHelpWindow(_:)))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "Online Support Guide" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "Privacy Policy" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "Official Product Website" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "Contact Support" }))
    }

    func testLocalizeEnglishMenuToChinese() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "NetDoctor", action: nil, keyEquivalent: "")
        mainMenu.addItem(appItem)

        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowSubmenu = NSMenu(title: "Window")
        windowSubmenu.addItem(NSMenuItem(title: "Close", action: Selector(("performClose:")), keyEquivalent: "w"))
        windowSubmenu.addItem(NSMenuItem(title: "Minimize", action: Selector(("performMiniaturize:")), keyEquivalent: "m"))
        windowSubmenu.addItem(NSMenuItem(title: "Bring All to Front", action: Selector(("arrangeInFront:")), keyEquivalent: ""))
        windowItem.submenu = windowSubmenu
        mainMenu.addItem(windowItem)

        MenuLocalizer.update(mainMenu: mainMenu, language: .chinese, appName: "NetDoctor")

        XCTAssertEqual(mainMenu.items[1].title, "窗口")
        XCTAssertEqual(windowSubmenu.items[0].title, "关闭")
        XCTAssertEqual(windowSubmenu.items[1].title, "最小化")
        XCTAssertEqual(windowSubmenu.items[2].title, "前置全部窗口")
    }

    func testLocalizeMenuToJapanese() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "NetDoctor", action: nil, keyEquivalent: "")
        mainMenu.addItem(appItem)

        // Window 菜单（复现用户截图：包含 Remove Window from Set）
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowSubmenu = NSMenu(title: "Window")
        windowSubmenu.addItem(NSMenuItem(title: "Minimize", action: Selector(("performMiniaturize:")), keyEquivalent: "m"))
        windowSubmenu.addItem(NSMenuItem(title: "Zoom", action: Selector(("performZoom:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "Bring All to Front", action: Selector(("arrangeInFront:")), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem(title: "Remove Window from Set", action: Selector(("removeWindowFromSet:")), keyEquivalent: ""))
        windowItem.submenu = windowSubmenu
        mainMenu.addItem(windowItem)

        // Help 菜单
        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu(title: "Help")
        helpSubmenu.addItem(NSMenuItem(title: "NetDoctor Help", action: Selector(("showHelp:")), keyEquivalent: "?"))
        helpItem.submenu = helpSubmenu
        mainMenu.addItem(helpItem)

        MenuLocalizer.update(mainMenu: mainMenu, language: .japanese, appName: "NetDoctor")

        XCTAssertEqual(mainMenu.items[1].title, "ウィンドウ")
        XCTAssertEqual(windowSubmenu.items[0].title, "しまう")
        XCTAssertEqual(windowSubmenu.items[1].title, "拡大/縮小")
        XCTAssertEqual(windowSubmenu.items[2].title, "すべてを手前に表示")
        XCTAssertEqual(windowSubmenu.items[3].title, "セットからウインドウを削除")
        XCTAssertTrue(windowSubmenu.items[3].isHidden) // 冗余项已被隐藏

        XCTAssertEqual(mainMenu.items[2].title, "ヘルプ")
        let helpItems = helpSubmenu.items
        XCTAssertEqual(helpItems[0].title, "NetDoctor ヘルプ")
        XCTAssertTrue(helpItems.contains(where: { $0.title == "サポートガイド" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "プライバシーポリシー" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "製品公式サイト" }))
        XCTAssertTrue(helpItems.contains(where: { $0.title == "サポートに連絡" }))
    }
}
