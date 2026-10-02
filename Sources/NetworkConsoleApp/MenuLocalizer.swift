import AppKit
import Foundation

/// macOS 系统菜单栏（NSApp.mainMenu 及全部子菜单）全量深度动态本地化工具
@MainActor
enum MenuLocalizer {
    enum ItemRole {
        // App Menu
        case about
        case settings
        case services
        case hideApp
        case hideOthers
        case showAll
        case quitApp

        // Edit Menu
        case undo
        case redo
        case cut
        case copy
        case paste
        case pasteAndMatchStyle
        case delete
        case selectAll
        case autoFill
        case autoFillContacts
        case autoFillPasswords
        case autoFillCreditCards
        case startDictation
        case emojiAndSymbols

        // View Menu
        case showTabBar
        case hideTabBar
        case showAllTabs
        case enterFullScreen
        case exitFullScreen

        // Window Menu
        case close
        case minimize
        case zoom
        case fill
        case center
        case moveAndResize
        case tile
        case bringAllToFront
        case removeWindowFromGroup
        case showPreviousTab
        case showNextTab
        case moveTabToNewWindow
        case mergeAllWindows

        // Help Menu
        case appHelp
        case onlineDocumentation
        case privacyPolicy
        case contactSupport
    }

    /// 本地化全部菜单与子菜单
    static func update(mainMenu: NSMenu, language: AppLanguage, appName: String) {
        let lang = language.resolvedLanguage

        // 1. 本地化顶层菜单栏（Menu Bar Items）
        localizeTopBar(mainMenu: mainMenu, language: lang, appName: appName)

        // 2. 递归本地化每一个子菜单项
        for item in mainMenu.items {
            if let submenu = item.submenu {
                localizeSubmenu(submenu, language: lang, appName: appName)
            }
        }
    }

    private static func localizeTopBar(mainMenu: NSMenu, language: AppLanguage, appName: String) {
        let editText = localizedTitle(for: "Edit", language: language)
        let viewText = localizedTitle(for: "View", language: language)
        let windowText = localizedTitle(for: "Window", language: language)
        let helpText = localizedTitle(for: "Help", language: language)

        let count = mainMenu.items.count

        for (index, item) in mainMenu.items.enumerated() {
            if index == 0 {
                item.title = appName
                item.submenu?.title = appName
                continue
            }

            let title = item.title

            if isEditMenu(title: title, index: index, count: count) {
                item.title = editText
                item.submenu?.title = editText
            }
            else if isViewMenu(title: title, index: index, count: count) {
                item.title = viewText
                item.submenu?.title = viewText
            }
            else if isWindowMenu(title: title, index: index, count: count) {
                item.title = windowText
                item.submenu?.title = windowText
            }
            else if isHelpMenu(title: title, index: index, count: count) {
                item.title = helpText
                item.submenu?.title = helpText
                if let submenu = item.submenu {
                    ensureHelpSubmenuItems(submenu, language: language, appName: appName)
                }
            }
        }
    }

    private static func localizeSubmenu(_ menu: NSMenu, language: AppLanguage, appName: String) {
        for item in menu.items {
            if item.isSeparatorItem { continue }

            if let role = identifyRole(for: item) {
                item.title = localizedRoleTitle(role: role, language: language, appName: appName)

                // 劫持 Help 菜单中默认失效报错的 action
                if role == .appHelp {
                    item.target = AppDelegate.shared
                    item.action = #selector(AppDelegate.showHelpWindow(_:))
                }
            }

            if let sub = item.submenu {
                localizeSubmenu(sub, language: language, appName: appName)
            }
        }
    }

    private static func ensureHelpSubmenuItems(_ menu: NSMenu, language: AppLanguage, appName: String) {
        let isZh = (language == .chinese)
        let docsTitle = isZh ? "在线使用文档" : "Online Documentation"
        let privacyTitle = isZh ? "隐私政策" : "Privacy Policy"
        let contactTitle = isZh ? "联系技术支持" : "Contact Support"

        // 检查是否已添加过文档与隐私项
        var hasDocs = false
        var hasPrivacy = false
        var hasContact = false

        for item in menu.items {
            if item.action == #selector(AppDelegate.openOnlineDocumentation(_:)) {
                hasDocs = true
                item.title = docsTitle
            }
            if item.action == #selector(AppDelegate.openPrivacyPolicy(_:)) {
                hasPrivacy = true
                item.title = privacyTitle
            }
            if item.action == #selector(AppDelegate.openContactSupport(_:)) {
                hasContact = true
                item.title = contactTitle
            }
        }

        if !hasDocs {
            if !menu.items.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }
            let docsItem = NSMenuItem(title: docsTitle, action: #selector(AppDelegate.openOnlineDocumentation(_:)), keyEquivalent: "")
            docsItem.target = AppDelegate.shared
            menu.addItem(docsItem)
        }

        if !hasPrivacy {
            let privacyItem = NSMenuItem(title: privacyTitle, action: #selector(AppDelegate.openPrivacyPolicy(_:)), keyEquivalent: "")
            privacyItem.target = AppDelegate.shared
            menu.addItem(privacyItem)
        }

        if !hasContact {
            let contactItem = NSMenuItem(title: contactTitle, action: #selector(AppDelegate.openContactSupport(_:)), keyEquivalent: "")
            contactItem.target = AppDelegate.shared
            menu.addItem(contactItem)
        }
    }

    private static func identifyRole(for item: NSMenuItem) -> ItemRole? {
        let actionStr = item.action?.description ?? ""
        let title = item.title

        // 1. 根据 Action Selector 识别
        switch actionStr {
        case "orderFrontStandardAboutPanel:":
            return .about
        case "showSettingsWindow:":
            return .settings
        case "hide:":
            return .hideApp
        case "hideOtherApplications:":
            return .hideOthers
        case "unhideAllApplications:":
            return .showAll
        case "terminate:":
            return .quitApp
        case "undo:":
            return .undo
        case "redo:":
            return .redo
        case "cut:":
            return .cut
        case "copy:":
            return .copy
        case "paste:":
            return .paste
        case "pasteAsPlainText:", "pasteAndMatchStyle:":
            return .pasteAndMatchStyle
        case "delete:":
            return .delete
        case "selectAll:":
            return .selectAll
        case "startDictation:":
            return .startDictation
        case "orderFrontCharacterPalette:":
            return .emojiAndSymbols
        case "toggleFullScreen:":
            return title.contains("Exit") || title.contains("退出") ? .exitFullScreen : .enterFullScreen
        case "toggleTabBar:":
            return title.contains("Hide") || title.contains("隐藏") ? .hideTabBar : .showTabBar
        case "toggleTabOverview:":
            return .showAllTabs
        case "performClose:":
            return .close
        case "performMiniaturize:":
            return .minimize
        case "performZoom:":
            return .zoom
        case "arrangeInFront:":
            return .bringAllToFront
        case "removeWindowFromGroup:":
            return .removeWindowFromGroup
        case "selectPreviousTab:":
            return .showPreviousTab
        case "selectNextTab:":
            return .showNextTab
        case "moveTabToNewWindow:":
            return .moveTabToNewWindow
        case "mergeAllWindows:":
            return .mergeAllWindows
        case "showHelp:", "showHelpWindow:":
            return .appHelp
        case "openOnlineDocumentation:":
            return .onlineDocumentation
        case "openPrivacyPolicy:":
            return .privacyPolicy
        case "openContactSupport:":
            return .contactSupport
        default:
            break
        }

        // 2. 根据快捷键 + 修饰键识别
        let key = item.keyEquivalent.lowercased()
        let mods = item.keyEquivalentModifierMask

        if key == "w" && mods.contains(.command) { return .close }
        if key == "m" && mods.contains(.command) { return .minimize }
        if key == "q" && mods.contains(.command) { return .quitApp }
        if key == "h" && mods.contains(.command) && mods.contains(.option) { return .hideOthers }
        if key == "h" && mods.contains(.command) { return .hideApp }
        if key == "," && mods.contains(.command) { return .settings }
        if key == "z" && mods.contains(.command) && mods.contains(.shift) { return .redo }
        if key == "z" && mods.contains(.command) { return .undo }
        if key == "x" && mods.contains(.command) { return .cut }
        if key == "c" && mods.contains(.command) { return .copy }
        if key == "v" && mods.contains(.command) { return .paste }
        if key == "a" && mods.contains(.command) { return .selectAll }

        // 3. 根据多语言标题特征精准匹配
        // App 菜单
        if title.hasPrefix("About ") || title.contains("关于") || title.contains("について") || title.contains("Über ") || title.contains("À propos") {
            return .about
        }
        if title.contains("Setting") || title.contains("设置") || title.contains("設定") || title.contains("설정") || title.contains("Einstellung") || title.contains("Réglage") || title.contains("Configur") {
            return .settings
        }
        if title == "Services" || title == "服务" || title == "サービス" || title == "Dienste" {
            return .services
        }
        if title.hasPrefix("Hide Others") || title == "隐藏其他" || title.contains("ほかを非表示") || title.contains("Andere ausblenden") {
            return .hideOthers
        }
        if title.hasPrefix("Show All") || title == "全部显示" || title.contains("すべてを表示") || title.contains("Alle einblenden") {
            return .showAll
        }
        if title.hasPrefix("Hide ") || title.hasPrefix("隐藏 ") || title.contains("を非表示") || title.contains("ausblenden") {
            return .hideApp
        }
        if title.hasPrefix("Quit ") || title.hasPrefix("退出 ") || title.contains("库出") || title.contains("を終了") || title.contains("beenden") || title.contains("Quitter") {
            return .quitApp
        }

        // Edit 菜单及智能填充、听写
        if title == "Undo" || title == "撤销" || title == "取り消す" || title == "Widerrufen" || title == "Annuler" {
            return .undo
        }
        if title == "Redo" || title == "重做" || title == "やり直す" || title == "Wiederholen" || title == "Rétablir" {
            return .redo
        }
        if title == "Cut" || title == "剪切" || title == "カット" || title == "Ausschneiden" || title == "Couper" {
            return .cut
        }
        if title == "Copy" || title == "拷贝" || title == "复制" || title == "コピー" || title == "Kopieren" || title == "Copier" {
            return .copy
        }
        if title == "Paste" || title == "粘贴" || title == "ペースト" || title == "Einsetzen" || title == "Coller" {
            return .paste
        }
        if title.contains("Match Style") || title.contains("匹配样式") {
            return .pasteAndMatchStyle
        }
        if title == "Delete" || title == "删除" || title == "削除" || title == "Löschen" || title == "Supprimer" {
            return .delete
        }
        if title == "Select All" || title == "全选" || title == "すべてを選択" || title == "Alles auswählen" || title == "Tout sélectionner" {
            return .selectAll
        }
        if title == "AutoFill" || title == "自动填充" || title.contains("自動入力") || title.contains("Automatisches Ausfüllen") {
            return .autoFill
        }
        if title.contains("Contact") || title.contains("联系人") || title.contains("連絡先") {
            return .autoFillContacts
        }
        if title.contains("Password") || title.contains("密码") || title.contains("パスワード") {
            return .autoFillPasswords
        }
        if title.contains("Credit Card") || title.contains("信用卡") || title.contains("クレジットカード") {
            return .autoFillCreditCards
        }
        if title.contains("Dictation") || title.contains("听写") || title.contains("音声入力") || title.contains("Diktat") {
            return .startDictation
        }
        if title.contains("Emoji") || title.contains("表情与符号") || title.contains("絵文字") || title.contains("Symbole") {
            return .emojiAndSymbols
        }

        // View 菜单
        if title.contains("Show Tab Bar") || title == "显示标签页栏" || title.contains("タブバーを表示") {
            return .showTabBar
        }
        if title.contains("Hide Tab Bar") || title == "隐藏标签页栏" || title.contains("タブバーを非表示") {
            return .hideTabBar
        }
        if title.contains("Show All Tabs") || title == "显示所有标签页" || title.contains("すべてのタブを表示") {
            return .showAllTabs
        }
        if title.contains("Enter Full Screen") || title == "进入全屏幕" || title.contains("フルスクリーンにする") {
            return .enterFullScreen
        }
        if title.contains("Exit Full Screen") || title == "退出全屏幕" || title.contains("フルスクリーンを解除") {
            return .exitFullScreen
        }

        // Window 菜单
        if title == "Close" || title == "关闭" || title == "閉じる" || title == "Schließen" || title == "Fermer" || title == "Cerrar" {
            return .close
        }
        if title == "Minimize" || title == "最小化" || title == "しまう" || title == "Minimieren" || title == "Réduire" || title == "Minimizar" {
            return .minimize
        }
        if title == "Zoom" || title == "缩放" || title == "拡大/縮小" || title == "Zoomen" || title == "Agrandir" {
            return .zoom
        }
        if title == "Fill" || title == "填充" || title == "Ausfüllen" || title == "Remplir" {
            return .fill
        }
        if title == "Center" || title == "居中" || title == "中央に配置" || title == "Zentrieren" || title == "Centrer" {
            return .center
        }
        if title.contains("Move & Resize") || title.contains("移动与调整大小") || title.contains("移動とサイズ変更") {
            return .moveAndResize
        }
        if title.contains("Tile") || title.contains("平铺") || title.contains("タイル") || title.contains("Kacheln") {
            return .tile
        }
        if title.contains("Bring All to Front") || title.contains("前置全部窗口") || title.contains("すべてを手前に表示") || title.contains("Alle nach vorne") {
            return .bringAllToFront
        }
        if title.contains("Remove Window from Group") || title.contains("从组中移除窗口") || title.contains("グループからウインドウを削除") {
            return .removeWindowFromGroup
        }
        if title.contains("Show Previous Tab") || title.contains("显示上一个标签页") || title.contains("前のタブを表示") {
            return .showPreviousTab
        }
        if title.contains("Show Next Tab") || title.contains("显示下一个标签页") || title.contains("次のタブを表示") {
            return .showNextTab
        }
        if title.contains("Move Tab to New Window") || title.contains("将标签页移到新窗口") || title.contains("タブを新規ウインドウに移動") {
            return .moveTabToNewWindow
        }
        if title.contains("Merge All Windows") || title.contains("合并所有窗口") || title.contains("すべてのウインドウを統合") {
            return .mergeAllWindows
        }

        // Help 菜单
        if title.contains("Online Documentation") || title.contains("在线使用文档") || title.contains("在线文档") {
            return .onlineDocumentation
        }
        if title.contains("Privacy Policy") || title.contains("隐私政策") {
            return .privacyPolicy
        }
        if title.contains("Contact Support") || title.contains("联系技术支持") {
            return .contactSupport
        }
        if title.contains("Help") || title.contains("帮助") || title.contains("ヘルプ") || title.contains("Hilfe") || title.contains("Aide") {
            return .appHelp
        }

        return nil
    }

    private static func localizedRoleTitle(role: ItemRole, language: AppLanguage, appName: String) -> String {
        let isZh = (language == .chinese)
        let isJa = (language == .japanese)

        switch role {
        // App Menu
        case .about:
            let format = L10n.string("menu.about", language: language)
            return String(format: format, locale: language.locale, appName)
        case .settings:
            return L10n.string("menu.settings", language: language)
        case .services:
            if isZh { return "服务" }
            if isJa { return "サービス" }
            return "Services"
        case .hideApp:
            if isZh { return "隐藏 \(appName)" }
            if isJa { return "\(appName) を非表示" }
            return "Hide \(appName)"
        case .hideOthers:
            if isZh { return "隐藏其他" }
            if isJa { return "ほかを非表示" }
            return "Hide Others"
        case .showAll:
            if isZh { return "全部显示" }
            if isJa { return "すべてを表示" }
            return "Show All"
        case .quitApp:
            let format = L10n.string("menu.quit", language: language)
            return String(format: format, locale: language.locale, appName)

        // Edit Menu
        case .undo:
            if isZh { return "撤销" }
            if isJa { return "取り消す" }
            return "Undo"
        case .redo:
            if isZh { return "重做" }
            if isJa { return "やり直す" }
            return "Redo"
        case .cut:
            if isZh { return "剪切" }
            if isJa { return "カット" }
            return "Cut"
        case .copy:
            if isZh { return "拷贝" }
            if isJa { return "コピー" }
            return "Copy"
        case .paste:
            if isZh { return "粘贴" }
            if isJa { return "ペースト" }
            return "Paste"
        case .pasteAndMatchStyle:
            if isZh { return "粘贴并匹配样式" }
            if isJa { return "スタイルに合わせてペースト" }
            return "Paste and Match Style"
        case .delete:
            if isZh { return "删除" }
            if isJa { return "削除" }
            return "Delete"
        case .selectAll:
            if isZh { return "全选" }
            if isJa { return "すべてを選択" }
            return "Select All"
        case .autoFill:
            if isZh { return "自动填充" }
            if isJa { return "自動入力" }
            return "AutoFill"
        case .autoFillContacts:
            if isZh { return "联系人..." }
            if isJa { return "連絡先..." }
            return "Contact Info..."
        case .autoFillPasswords:
            if isZh { return "密码..." }
            if isJa { return "パスワード..." }
            return "Passwords..."
        case .autoFillCreditCards:
            if isZh { return "信用卡..." }
            if isJa { return "クレジットカード..." }
            return "Credit Cards..."
        case .startDictation:
            if isZh { return "开始听写..." }
            if isJa { return "音声入力を開始..." }
            return "Start Dictation..."
        case .emojiAndSymbols:
            if isZh { return "表情与符号" }
            if isJa { return "絵文字と記号" }
            return "Emoji & Symbols"

        // View Menu
        case .showTabBar:
            if isZh { return "显示标签页栏" }
            if isJa { return "タブバーを表示" }
            return "Show Tab Bar"
        case .hideTabBar:
            if isZh { return "隐藏标签页栏" }
            if isJa { return "タブバーを非表示" }
            return "Hide Tab Bar"
        case .showAllTabs:
            if isZh { return "显示所有标签页" }
            if isJa { return "すべてのタブを表示" }
            return "Show All Tabs"
        case .enterFullScreen:
            if isZh { return "进入全屏幕" }
            if isJa { return "フルスクリーンにする" }
            return "Enter Full Screen"
        case .exitFullScreen:
            if isZh { return "退出全屏幕" }
            if isJa { return "フルスクリーンを解除" }
            return "Exit Full Screen"

        // Window Menu
        case .close:
            if isZh { return "关闭" }
            if isJa { return "閉じる" }
            return "Close"
        case .minimize:
            if isZh { return "最小化" }
            if isJa { return "しまう" }
            return "Minimize"
        case .zoom:
            if isZh { return "缩放" }
            if isJa { return "拡大/縮小" }
            return "Zoom"
        case .fill:
            if isZh { return "填充" }
            if isJa { return "フルスクリーン" }
            return "Fill"
        case .center:
            if isZh { return "居中" }
            if isJa { return "中央に配置" }
            return "Center"
        case .moveAndResize:
            if isZh { return "移动与调整大小" }
            if isJa { return "移動とサイズ変更" }
            return "Move & Resize"
        case .tile:
            if isZh { return "全屏幕平铺" }
            if isJa { return "タイル" }
            return "Tile"
        case .bringAllToFront:
            if isZh { return "前置全部窗口" }
            if isJa { return "すべてを手前に表示" }
            return "Bring All to Front"
        case .removeWindowFromGroup:
            if isZh { return "从组中移除窗口" }
            if isJa { return "グループからウインドウを削除" }
            return "Remove Window from Group"
        case .showPreviousTab:
            if isZh { return "显示上一个标签页" }
            if isJa { return "前のタブを表示" }
            return "Show Previous Tab"
        case .showNextTab:
            if isZh { return "显示下一个标签页" }
            if isJa { return "次のタブを表示" }
            return "Show Next Tab"
        case .moveTabToNewWindow:
            if isZh { return "将标签页移到新窗口" }
            if isJa { return "タブを新規ウインドウに移動" }
            return "Move Tab to New Window"
        case .mergeAllWindows:
            if isZh { return "合并所有窗口" }
            if isJa { return "すべてのウインドウを統合" }
            return "Merge All Windows"

        // Help Menu
        case .appHelp:
            if isZh { return "\(appName) 帮助" }
            if isJa { return "\(appName) ヘルプ" }
            return "\(appName) Help"
        case .onlineDocumentation:
            if isZh { return "在线使用文档" }
            if isJa { return "オンラインドキュメント" }
            return "Online Documentation"
        case .privacyPolicy:
            if isZh { return "隐私政策" }
            if isJa { return "プライバシーポリシー" }
            return "Privacy Policy"
        case .contactSupport:
            if isZh { return "联系技术支持" }
            if isJa { return "サポートに連絡" }
            return "Contact Support"
        }
    }

    private static func localizedTitle(for standardName: String, language: AppLanguage) -> String {
        switch standardName {
        case "Edit": return L10n.string("menu.edit", language: language)
        case "View": return L10n.string("menu.view", language: language)
        case "Window": return L10n.string("menu.window", language: language)
        case "Help": return L10n.string("menu.help", language: language)
        default: return standardName
        }
    }

    private static let editAliases: Set<String> = ["Edit", "编辑", "編集", "편집", "Bearbeiten", "Édition", "Edición", "Edição"]
    private static let viewAliases: Set<String> = ["View", "显示", "表示", "보기", "Ansicht", "Affichage", "Ver", "Visualizar"]
    private static let windowAliases: Set<String> = ["Window", "窗口", "ウィンドウ", "윈도ウ", "Fenster", "Fenêtre", "Ventana", "Janela"]
    private static let helpAliases: Set<String> = ["Help", "帮助", "ヘルプ", "도움말", "Hilfe", "Aide", "Ayuda", "Ajuda"]

    private static func isEditMenu(title: String, index: Int, count: Int) -> Bool {
        editAliases.contains(title) || (index == 1 && count >= 4)
    }

    private static func isViewMenu(title: String, index: Int, count: Int) -> Bool {
        viewAliases.contains(title) || (index == 2 && count >= 4)
    }

    private static func isWindowMenu(title: String, index: Int, count: Int) -> Bool {
        windowAliases.contains(title) || (index == 3 && count >= 4)
    }

    private static func isHelpMenu(title: String, index: Int, count: Int) -> Bool {
        helpAliases.contains(title) || (index == count - 1 && count >= 4)
    }
}
