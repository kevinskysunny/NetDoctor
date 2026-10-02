import AppKit
import Foundation

/// macOS 系统菜单栏（NSApp.mainMenu 及全部子菜单）全量深度动态本地化工具
@MainActor
enum MenuLocalizer {
    enum ItemRole: String, CaseIterable {
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
        case productWebsite
        case contactSupport
    }

    /// 判断是否属于当前 NetDoctor 实用工具应用不需要的冗余项
    static func isRedundant(role: ItemRole) -> Bool {
        switch role {
        // App 菜单中对于网络体检应用无用的服务项
        case .services:
            return true

        // Edit 菜单中与网络体检无关的编辑项
        case .undo, .redo:
            return true
        case .autoFill, .autoFillContacts, .autoFillPasswords, .autoFillCreditCards:
            return true
        case .startDictation:
            return true

        // View 菜单中与多标签相关的项
        case .showTabBar, .hideTabBar, .showAllTabs:
            return true

        // Window 菜单中与单窗口诊断应用无关的多标签/窗口集项（如 Remove Window from Set）
        case .removeWindowFromGroup:
            return true
        case .showPreviousTab, .showNextTab, .moveTabToNewWindow, .mergeAllWindows:
            return true

        default:
            return false
        }
    }

    /// 本地化全部菜单与子菜单
    static func update(mainMenu: NSMenu, language: AppLanguage, appName: String) {
        let lang = language.resolvedLanguage

        // 1. 本地化顶层菜单栏（Menu Bar Items）
        localizeTopBar(mainMenu: mainMenu, language: lang, appName: appName)

        // 2. 递归本地化每一个子菜单项并剔除冗余项
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
                // 网络诊断工具无需富文本编辑，直接隐藏顶栏的“编辑”菜单，保持界面极简
                item.isHidden = true
                item.title = editText
                item.submenu?.title = editText
            }
            else if isViewMenu(title: title, index: index, count: count) {
                item.title = viewText
                item.submenu?.title = viewText
                let submenu = item.submenu ?? NSMenu(title: viewText)
                item.submenu = submenu
                ensureViewSubmenuItems(submenu, language: language, appName: appName)
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
                // 如果属于诊断工具完全用不上的冗余项，直接隐藏，保持菜单极致精简清爽
                if isRedundant(role: role) {
                    item.isHidden = true
                }

                item.title = localizedRoleTitle(role: role, language: language, appName: appName)

                // 劫持 Help 菜单中默认失效报错的 action
                if role == .appHelp {
                    item.target = AppDelegate.shared
                    item.action = #selector(AppDelegate.showHelpWindow(_:))
                }

                // 劫持 Settings 菜单项，确保无论点击还是 Cmd+, 都能百分百稳定呼出设置窗口
                if role == .settings {
                    item.target = AppDelegate.shared
                    item.action = #selector(AppDelegate.openSettingsWindow(_:))
                    item.keyEquivalent = ","
                    item.keyEquivalentModifierMask = .command
                }
            }

            if let sub = item.submenu {
                localizeSubmenu(sub, language: language, appName: appName)
            }
        }
    }

    private static func ensureViewSubmenuItems(_ menu: NSMenu, language: AppLanguage, appName: String) {
        let showWindowText: String

        switch language.resolvedLanguage {
        case .chinese:
            showWindowText = "显示 \(appName) 窗口"
        case .japanese:
            showWindowText = "\(appName) ウィンドウを表示"
        case .korean:
            showWindowText = "\(appName) 윈도우 표시"
        case .german:
            showWindowText = "\(appName)-Fenster anzeigen"
        case .french:
            showWindowText = "Afficher la fenêtre \(appName)"
        case .spanish:
            showWindowText = "Mostrar ventana de \(appName)"
        case .portuguese:
            showWindowText = "Mostrar Janela do \(appName)"
        default:
            showWindowText = "Show \(appName) Window"
        }

        var hasShowWindow = false

        for item in menu.items {
            if item.action == #selector(AppDelegate.showMainWindow(_:)) {
                hasShowWindow = true
                item.title = showWindowText
                item.keyEquivalent = "0"
                item.keyEquivalentModifierMask = .command
                item.target = AppDelegate.shared
                item.isHidden = false
            } else if item.action == #selector(AppDelegate.openSettingsWindow(_:)) {
                item.isHidden = true
            }
        }

        if !hasShowWindow {
            let showItem = NSMenuItem(
                title: showWindowText,
                action: #selector(AppDelegate.showMainWindow(_:)),
                keyEquivalent: "0"
            )
            showItem.keyEquivalentModifierMask = .command
            showItem.target = AppDelegate.shared
            menu.insertItem(showItem, at: 0)
        }
    }

    private static func ensureHelpSubmenuItems(_ menu: NSMenu, language: AppLanguage, appName: String) {
        let docsTitle: String
        let privacyTitle: String
        let websiteTitle: String
        let contactTitle: String

        switch language.resolvedLanguage {
        case .chinese:
            docsTitle = "在线使用帮助"
            privacyTitle = "应用隐私政策"
            websiteTitle = "官方产品主页"
            contactTitle = "联系技术支持"
        case .japanese:
            docsTitle = "サポートガイド"
            privacyTitle = "プライバシーポリシー"
            websiteTitle = "製品公式サイト"
            contactTitle = "サポートに連絡"
        case .korean:
            docsTitle = "온라인 지원 설명서"
            privacyTitle = "개인정보 처리방침"
            websiteTitle = "제품 공식 웹사이트"
            contactTitle = "기술 지원 문의"
        case .german:
            docsTitle = "Online-Support-Handbuch"
            privacyTitle = "Datenschutzerklärung"
            websiteTitle = "Produkt-Website"
            contactTitle = "Support kontaktieren"
        case .french:
            docsTitle = "Guide d'assistance en ligne"
            privacyTitle = "Politique de confidentialité"
            websiteTitle = "Site officiel du produit"
            contactTitle = "Contacter l'assistance"
        case .spanish:
            docsTitle = "Guía de ayuda en línea"
            privacyTitle = "Política de privacidad"
            websiteTitle = "Sitio web del producto"
            contactTitle = "Contactar con soporte"
        case .portuguese:
            docsTitle = "Guia de Suporte Online"
            privacyTitle = "Política de Privacidade"
            websiteTitle = "Site Oficial do Produto"
            contactTitle = "Entrar em Contato com o Suporte"
        default:
            docsTitle = "Online Support Guide"
            privacyTitle = "Privacy Policy"
            websiteTitle = "Official Product Website"
            contactTitle = "Contact Support"
        }

        var hasDocs = false
        var hasPrivacy = false
        var hasWebsite = false
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
            if item.action == #selector(AppDelegate.openProductWebsite(_:)) {
                hasWebsite = true
                item.title = websiteTitle
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

        if !hasWebsite {
            let websiteItem = NSMenuItem(title: websiteTitle, action: #selector(AppDelegate.openProductWebsite(_:)), keyEquivalent: "")
            websiteItem.target = AppDelegate.shared
            menu.addItem(websiteItem)
        }

        if !hasContact {
            let contactItem = NSMenuItem(title: contactTitle, action: #selector(AppDelegate.openContactSupport(_:)), keyEquivalent: "")
            contactItem.target = AppDelegate.shared
            menu.addItem(contactItem)
        }
    }

    private static func buildAllKnownTitles() -> [String: ItemRole] {
        var map = [String: ItemRole]()
        let languages: [AppLanguage] = [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]
        for role in ItemRole.allCases {
            for lang in languages {
                let title = localizedRoleTitle(role: role, language: lang, appName: "NetDoctor")
                map[title] = role
                let generic = localizedRoleTitle(role: role, language: lang, appName: "%@")
                map[generic] = role
            }
        }
        return map
    }

    private static let allKnownTitles: [String: ItemRole] = buildAllKnownTitles()

    private static func identifyRole(for item: NSMenuItem) -> ItemRole? {
        if let raw = item.representedObject as? String, let role = ItemRole(rawValue: raw) {
            // 特殊处理全屏状态切换：若全屏状态发生改变，根据当前标题特征重新判定进入/退出
            if role == .enterFullScreen || role == .exitFullScreen {
                let actionStr = item.action?.description ?? ""
                if actionStr == "toggleFullScreen:" {
                    let title = item.title
                    let isExit = title.contains("Exit") || title.contains("退出") || title.contains("解除") || title.contains("verlassen") || title.contains("Quitter") || title.contains("Salir")
                    let updatedRole: ItemRole = isExit ? .exitFullScreen : .enterFullScreen
                    item.representedObject = updatedRole.rawValue
                    return updatedRole
                }
            }
            return role
        }

        let role = resolveRole(for: item)
        if let role {
            item.representedObject = role.rawValue
        }
        return role
    }

    private static func resolveRole(for item: NSMenuItem) -> ItemRole? {
        let actionStr = item.action?.description ?? ""
        let title = item.title

        // 1. 如果此前被任何一种语言本地化过，直接从 8 语言全量字典中反查（覆盖中/英/日/韩/德/法/西/葡）
        if let role = allKnownTitles[title] {
            return role
        }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let role = allKnownTitles[trimmed] {
            return role
        }

        // 2. 根据 Action Selector 识别
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
        case "removeWindowFromGroup:", "removeWindowFromSet:", "removeWindowFromSet", "removeFromSet:", "removeFromGroup:":
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
        case "openProductWebsite:":
            return .productWebsite
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
        if title.contains("Remove Window from") ||
            title.contains("Window from Set") ||
            title.contains("Window from Group") ||
            title.contains("从组中移") ||
            title.contains("从组合中移") ||
            title.contains("从集合中移") ||
            title.contains("セットからウインドウ") ||
            title.contains("ウインドウをセットから") ||
            title.contains("グループからウインドウ") ||
            title.contains("세트에서 윈도우") ||
            title.contains("Fenster aus Set") ||
            title.contains("Fenster aus Gruppe") ||
            title.contains("la fenêtre de l’ensemble") ||
            title.contains("la fenêtre du groupe") ||
            title.contains("ventana del conjunto") ||
            title.contains("ventana del grupo") ||
            title.contains("Janela do Conjunto") ||
            title.contains("Janela do Grupo") {
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
        if title.contains("Online Documentation") || title.contains("在线使用文档") || title.contains("在线使用帮助") || title.contains("サポートガイド") {
            return .onlineDocumentation
        }
        if title.contains("Privacy Policy") || title.contains("隐私政策") || title.contains("プライバシーポリシー") {
            return .privacyPolicy
        }
        if title.contains("Website") || title.contains("官方产品主页") || title.contains("製品公式サイト") {
            return .productWebsite
        }
        if title.contains("Contact Support") || title.contains("联系技术支持") || title.contains("サポートに連絡") {
            return .contactSupport
        }
        if title.contains("Help") || title.contains("帮助") || title.contains("ヘルプ") || title.contains("Hilfe") || title.contains("Aide") {
            return .appHelp
        }

        return nil
    }

    private static func localizedRoleTitle(role: ItemRole, language: AppLanguage, appName: String) -> String {
        let lang = language.resolvedLanguage
        switch role {
        // App Menu
        case .about:
            let format = L10n.string("menu.about", language: language)
            return String(format: format, locale: language.locale, appName)
        case .settings:
            return L10n.string("menu.settings", language: language)
        case .services:
            switch lang {
            case .chinese: return "服务"
            case .japanese: return "サービス"
            case .korean: return "서비스"
            case .german: return "Dienste"
            case .french: return "Services"
            case .spanish: return "Servicios"
            case .portuguese: return "Serviços"
            default: return "Services"
            }
        case .hideApp:
            switch lang {
            case .chinese: return "隐藏 \(appName)"
            case .japanese: return "\(appName)を非表示"
            case .korean: return "\(appName) 가리기"
            case .german: return "\(appName) ausblenden"
            case .french: return "Masquer \(appName)"
            case .spanish: return "Ocultar \(appName)"
            case .portuguese: return "Ocultar \(appName)"
            default: return "Hide \(appName)"
            }
        case .hideOthers:
            switch lang {
            case .chinese: return "隐藏其他"
            case .japanese: return "ほかを非表示"
            case .korean: return "기타 가리기"
            case .german: return "Andere ausblenden"
            case .french: return "Masquer les autres"
            case .spanish: return "Ocultar otros"
            case .portuguese: return "Ocultar Outros"
            default: return "Hide Others"
            }
        case .showAll:
            switch lang {
            case .chinese: return "全部显示"
            case .japanese: return "すべてを表示"
            case .korean: return "모두 보기"
            case .german: return "Alle einblenden"
            case .french: return "Tout afficher"
            case .spanish: return "Mostrar todo"
            case .portuguese: return "Mostrar Tudo"
            default: return "Show All"
            }
        case .quitApp:
            let format = L10n.string("menu.quit", language: language)
            return String(format: format, locale: language.locale, appName)

        // Edit Menu
        case .undo:
            switch lang {
            case .chinese: return "撤销"
            case .japanese: return "取り消す"
            case .korean: return "실행 취소"
            case .german: return "Widerrufen"
            case .french: return "Annuler"
            case .spanish: return "Deshacer"
            case .portuguese: return "Desfazer"
            default: return "Undo"
            }
        case .redo:
            switch lang {
            case .chinese: return "重做"
            case .japanese: return "やり直す"
            case .korean: return "실행 복귀"
            case .german: return "Wiederholen"
            case .french: return "Rétablir"
            case .spanish: return "Rehacer"
            case .portuguese: return "Refazer"
            default: return "Redo"
            }
        case .cut:
            switch lang {
            case .chinese: return "剪切"
            case .japanese: return "カット"
            case .korean: return "오려두기"
            case .german: return "Ausschneiden"
            case .french: return "Couper"
            case .spanish: return "Cortar"
            case .portuguese: return "Cortar"
            default: return "Cut"
            }
        case .copy:
            switch lang {
            case .chinese: return "拷贝"
            case .japanese: return "コピー"
            case .korean: return "복사"
            case .german: return "Kopieren"
            case .french: return "Copier"
            case .spanish: return "Copiar"
            case .portuguese: return "Copiar"
            default: return "Copy"
            }
        case .paste:
            switch lang {
            case .chinese: return "粘贴"
            case .japanese: return "ペースト"
            case .korean: return "붙여넣기"
            case .german: return "Einsetzen"
            case .french: return "Coller"
            case .spanish: return "Pegar"
            case .portuguese: return "Colar"
            default: return "Paste"
            }
        case .pasteAndMatchStyle:
            switch lang {
            case .chinese: return "粘贴并匹配样式"
            case .japanese: return "スタイルに合わせてペースト"
            case .korean: return "스타일 일치시켜 붙여넣기"
            case .german: return "Einsetzen und Stil anpassen"
            case .french: return "Coller et adapter le style"
            case .spanish: return "Pegar con el mismo estilo"
            case .portuguese: return "Colar com o Mesmo Estilo"
            default: return "Paste and Match Style"
            }
        case .delete:
            switch lang {
            case .chinese: return "删除"
            case .japanese: return "削除"
            case .korean: return "삭제"
            case .german: return "Löschen"
            case .french: return "Supprimer"
            case .spanish: return "Eliminar"
            case .portuguese: return "Apagar"
            default: return "Delete"
            }
        case .selectAll:
            switch lang {
            case .chinese: return "全选"
            case .japanese: return "すべてを選択"
            case .korean: return "전체 선택"
            case .german: return "Alles auswählen"
            case .french: return "Tout sélectionner"
            case .spanish: return "Seleccionar todo"
            case .portuguese: return "Selecionar Tudo"
            default: return "Select All"
            }
        case .autoFill:
            switch lang {
            case .chinese: return "自动填充"
            case .japanese: return "自動入力"
            case .korean: return "자동 완성"
            case .german: return "Automatisches Ausfüllen"
            case .french: return "Remplissage automatique"
            case .spanish: return "Rellenar automáticamente"
            case .portuguese: return "Preenchimento Automático"
            default: return "AutoFill"
            }
        case .autoFillContacts:
            switch lang {
            case .chinese: return "联系人..."
            case .japanese: return "連絡先..."
            case .korean: return "연락처..."
            case .german: return "Kontakte..."
            case .french: return "Contacts..."
            case .spanish: return "Contactos..."
            case .portuguese: return "Contatos..."
            default: return "Contact Info..."
            }
        case .autoFillPasswords:
            switch lang {
            case .chinese: return "密码..."
            case .japanese: return "パスワード..."
            case .korean: return "암호..."
            case .german: return "Passwörter..."
            case .french: return "Mots de passe..."
            case .spanish: return "Contraseñas..."
            case .portuguese: return "Senhas..."
            default: return "Passwords..."
            }
        case .autoFillCreditCards:
            switch lang {
            case .chinese: return "信用卡..."
            case .japanese: return "クレジットカード..."
            case .korean: return "신용 카드..."
            case .german: return "Kreditkarten..."
            case .french: return "Cartes de crédit..."
            case .spanish: return "Tarjetas de crédito..."
            case .portuguese: return "Cartões de Crédito..."
            default: return "Credit Cards..."
            }
        case .startDictation:
            switch lang {
            case .chinese: return "开始听写..."
            case .japanese: return "音声入力を開始..."
            case .korean: return "받아쓰기 시작..."
            case .german: return "Diktat starten..."
            case .french: return "Démarrer la dictée..."
            case .spanish: return "Iniciar dictado..."
            case .portuguese: return "Iniciar Ditado..."
            default: return "Start Dictation..."
            }
        case .emojiAndSymbols:
            switch lang {
            case .chinese: return "表情与符号"
            case .japanese: return "絵文字と記号"
            case .korean: return "이모티콘 및 기호"
            case .german: return "Emojis & Symbole"
            case .french: return "Emoji et symboles"
            case .spanish: return "Emojis y símbolos"
            case .portuguese: return "Emoji e Símbolos"
            default: return "Emoji & Symbols"
            }

        // View Menu
        case .showTabBar:
            switch lang {
            case .chinese: return "显示标签页栏"
            case .japanese: return "タブバーを表示"
            case .korean: return "탭 막대 보기"
            case .german: return "Tabelleiste einblenden"
            case .french: return "Afficher la barre d'onglets"
            case .spanish: return "Mostrar barra de pestañas"
            case .portuguese: return "Mostrar Barra de Abas"
            default: return "Show Tab Bar"
            }
        case .hideTabBar:
            switch lang {
            case .chinese: return "隐藏标签页栏"
            case .japanese: return "タブバーを非表示"
            case .korean: return "탭 막대 가리기"
            case .german: return "Tabelleiste ausblenden"
            case .french: return "Masquer la barre d'onglets"
            case .spanish: return "Ocultar barra de pestañas"
            case .portuguese: return "Ocultar Barra de Abas"
            default: return "Hide Tab Bar"
            }
        case .showAllTabs:
            switch lang {
            case .chinese: return "显示所有标签页"
            case .japanese: return "すべてのタブを表示"
            case .korean: return "모든 탭 보기"
            case .german: return "Alle Tabs einblenden"
            case .french: return "Afficher tous les onglets"
            case .spanish: return "Mostrar todas las pestañas"
            case .portuguese: return "Mostrar Todas as Abas"
            default: return "Show All Tabs"
            }
        case .enterFullScreen:
            switch lang {
            case .chinese: return "进入全屏幕"
            case .japanese: return "フルスクリーンにする"
            case .korean: return "전체 화면 시작"
            case .german: return "Vollbildmodus aktivieren"
            case .french: return "Activer le mode plein écran"
            case .spanish: return "Activar pantalla completa"
            case .portuguese: return "Entrar em Tela Cheia"
            default: return "Enter Full Screen"
            }
        case .exitFullScreen:
            switch lang {
            case .chinese: return "退出全屏幕"
            case .japanese: return "フルスクリーンを解除"
            case .korean: return "전체 화면 종료"
            case .german: return "Vollbildmodus verlassen"
            case .french: return "Quitter le mode plein écran"
            case .spanish: return "Salir de pantalla completa"
            case .portuguese: return "Sair da Tela Cheia"
            default: return "Exit Full Screen"
            }

        // Window Menu
        case .close:
            switch lang {
            case .chinese: return "关闭"
            case .japanese: return "閉じる"
            case .korean: return "닫기"
            case .german: return "Schließen"
            case .french: return "Fermer"
            case .spanish: return "Cerrar"
            case .portuguese: return "Fechar"
            default: return "Close"
            }
        case .minimize:
            switch lang {
            case .chinese: return "最小化"
            case .japanese: return "しまう"
            case .korean: return "최소화"
            case .german: return "Minimieren"
            case .french: return "Réduire"
            case .spanish: return "Minimizar"
            case .portuguese: return "Minimizar"
            default: return "Minimize"
            }
        case .zoom:
            switch lang {
            case .chinese: return "缩放"
            case .japanese: return "拡大/縮小"
            case .korean: return "확대/축소"
            case .german: return "Zoomen"
            case .french: return "Agrandir"
            case .spanish: return "Zoom"
            case .portuguese: return "Zoom"
            default: return "Zoom"
            }
        case .fill:
            switch lang {
            case .chinese: return "填充"
            case .japanese: return "フルスクリーン"
            case .korean: return "채우기"
            case .german: return "Ausfüllen"
            case .french: return "Remplir"
            case .spanish: return "Llenar"
            case .portuguese: return "Preencher"
            default: return "Fill"
            }
        case .center:
            switch lang {
            case .chinese: return "居中"
            case .japanese: return "中央に配置"
            case .korean: return "가운데 정렬"
            case .german: return "Zentrieren"
            case .french: return "Centrer"
            case .spanish: return "Centrar"
            case .portuguese: return "Centralizar"
            default: return "Center"
            }
        case .moveAndResize:
            switch lang {
            case .chinese: return "移动与调整大小"
            case .japanese: return "移動とサイズ変更"
            case .korean: return "이동 및 크기 조절"
            case .german: return "Verschieben und Größe ändern"
            case .french: return "Déplacer et redimensionner"
            case .spanish: return "Mover y cambiar tamaño"
            case .portuguese: return "Mover e Redimensionar"
            default: return "Move & Resize"
            }
        case .tile:
            switch lang {
            case .chinese: return "全屏幕平铺"
            case .japanese: return "タイル"
            case .korean: return "타일"
            case .german: return "Kacheln"
            case .french: return "Mosaïque"
            case .spanish: return "Mosaico"
            case .portuguese: return "Lado a Lado"
            default: return "Tile"
            }
        case .bringAllToFront:
            switch lang {
            case .chinese: return "前置全部窗口"
            case .japanese: return "すべてを手前に表示"
            case .korean: return "모두 앞으로 가져오기"
            case .german: return "Alle nach vorne bringen"
            case .french: return "Tout ramener au premier plan"
            case .spanish: return "Traer todo al frente"
            case .portuguese: return "Trazer Todas para a Frente"
            default: return "Bring All to Front"
            }
        case .removeWindowFromGroup:
            switch lang {
            case .chinese: return "从组中移出窗口"
            case .japanese: return "セットからウインドウを削除"
            case .korean: return "세트에서 윈도우 제거"
            case .german: return "Fenster aus Set entfernen"
            case .french: return "Supprimer la fenêtre de l’ensemble"
            case .spanish: return "Eliminar ventana del conjunto"
            case .portuguese: return "Remover Janela do Conjunto"
            default: return "Remove Window from Set"
            }
        case .showPreviousTab:
            switch lang {
            case .chinese: return "显示上一个标签页"
            case .japanese: return "前のタブを表示"
            case .korean: return "이전 탭 보기"
            case .german: return "Vorherigen Tab einblenden"
            case .french: return "Afficher l'onglet précédent"
            case .spanish: return "Mostrar pestaña anterior"
            case .portuguese: return "Mostrar Aba Anterior"
            default: return "Show Previous Tab"
            }
        case .showNextTab:
            switch lang {
            case .chinese: return "显示下一个标签页"
            case .japanese: return "次のタブを表示"
            case .korean: return "다음 탭 보기"
            case .german: return "Nächsten Tab einblenden"
            case .french: return "Afficher l'onglet suivant"
            case .spanish: return "Mostrar pestaña siguiente"
            case .portuguese: return "Mostrar Próxima Aba"
            default: return "Show Next Tab"
            }
        case .moveTabToNewWindow:
            switch lang {
            case .chinese: return "将标签页移到新窗口"
            case .japanese: return "タブを新規ウインドウに移動"
            case .korean: return "탭을 새 윈도우로 이동"
            case .german: return "Tab in ein neues Fenster bewegen"
            case .french: return "Déplacer l'onglet vers une nouvelle fenêtre"
            case .spanish: return "Mover pestaña a una ventana nueva"
            case .portuguese: return "Mover Aba para Nova Janela"
            default: return "Move Tab to New Window"
            }
        case .mergeAllWindows:
            switch lang {
            case .chinese: return "合并所有窗口"
            case .japanese: return "すべてのウインドウを統合"
            case .korean: return "모든 윈도우 통합"
            case .german: return "Alle Fenster zusammenführen"
            case .french: return "Fusionner toutes les fenêtres"
            case .spanish: return "Combinar todas las ventanas"
            case .portuguese: return "Agrupar Todas as Janelas"
            default: return "Merge All Windows"
            }

        // Help Menu
        case .appHelp:
            switch lang {
            case .chinese: return "\(appName) 帮助"
            case .japanese: return "\(appName) ヘルプ"
            case .korean: return "\(appName) 도움말"
            case .german: return "\(appName)-Hilfe"
            case .french: return "Aide \(appName)"
            case .spanish: return "Ayuda de \(appName)"
            case .portuguese: return "Ajuda do \(appName)"
            default: return "\(appName) Help"
            }
        case .onlineDocumentation:
            switch lang {
            case .chinese: return "在线使用帮助"
            case .japanese: return "サポートガイド"
            case .korean: return "온라인 지원 설명서"
            case .german: return "Online-Support-Handbuch"
            case .french: return "Guide d'assistance en ligne"
            case .spanish: return "Guía de ayuda en línea"
            case .portuguese: return "Guia de Suporte Online"
            default: return "Online Support Guide"
            }
        case .privacyPolicy:
            switch lang {
            case .chinese: return "应用隐私政策"
            case .japanese: return "プライバシーポリシー"
            case .korean: return "개인정보 처리방침"
            case .german: return "Datenschutzerklärung"
            case .french: return "Politique de confidentialité"
            case .spanish: return "Política de privacidad"
            case .portuguese: return "Política de Privacidade"
            default: return "Privacy Policy"
            }
        case .productWebsite:
            switch lang {
            case .chinese: return "官方产品主页"
            case .japanese: return "製品公式サイト"
            case .korean: return "제품 공식 웹사이트"
            case .german: return "Produkt-Website"
            case .french: return "Site officiel du produit"
            case .spanish: return "Sitio web del producto"
            case .portuguese: return "Site Oficial do Produto"
            default: return "Official Product Website"
            }
        case .contactSupport:
            switch lang {
            case .chinese: return "联系技术支持"
            case .japanese: return "サポートに連絡"
            case .korean: return "기술 지원 문의"
            case .german: return "Support kontaktieren"
            case .french: return "Contacter l'assistance"
            case .spanish: return "Contactar con soporte"
            case .portuguese: return "Entrar em Contato com o Suporte"
            default: return "Contact Support"
            }
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
