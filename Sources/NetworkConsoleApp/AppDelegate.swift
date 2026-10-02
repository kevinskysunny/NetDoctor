import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    var model: AppModel?
    private var detailWindow: NSWindow?
    private var languageCancellable: AnyCancellable?

    override init() {
        super.init()
        Self.shared = self
    }

    private static let knownSettingsTitles: Set<String> = [
        "设置...", "设置…", "Settings...", "Settings…",
        "設定...", "設定…", "설정...", "설정…",
        "Einstellungen...", "Einstellungen…",
        "Réglages...", "Réglages…",
        "Configuración...", "Configuración…",
        "Configurações...", "Configurações…"
    ]

    private static let knownEditTitles: Set<String> = [
        "Edit", "编辑", "編集", "편집", "Bearbeiten", "Édition", "Edición", "Edição"
    ]

    private static let knownViewTitles: Set<String> = [
        "View", "显示", "表示", "보기", "Ansicht", "Affichage", "Ver", "Visualizar"
    ]

    private static let knownWindowTitles: Set<String> = [
        "Window", "窗口", "ウィンドウ", "윈도우", "Fenster", "Fenêtre", "Ventana", "Janela"
    ]

    private static let knownHelpTitles: Set<String> = [
        "Help", "帮助", "ヘルプ", "도움말", "Hilfe", "Aide", "Ayuda", "Ajuda"
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        showDetailWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateMainMenu()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showDetailWindow()
        return true
    }

    func showDetailWindow() {
        MainActor.assumeIsolated {
            guard let model = model ?? Self.shared?.model else { return }

            if let window = detailWindow {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let hostingController = NSHostingController(
                rootView: DetailView(model: model)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = model.text("detail.window.title")
            window.setContentSize(NSSize(width: 980, height: 700))
            window.minSize = NSSize(width: 840, height: 560)
            window.center()
            window.isReleasedWhenClosed = false
            detailWindow = window
            languageCancellable = model.$language
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self, let window = self.detailWindow, let model = self.model ?? Self.shared?.model else { return }
                    window.title = model.text("detail.window.title")
                    self.updateMainMenu()
                }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateMainMenu() {
        MainActor.assumeIsolated {
            guard let model, let mainMenu = NSApp.mainMenu else { return }
            let appName = model.text("app.name")

            if let appMenuItem = mainMenu.item(at: 0), let submenu = appMenuItem.submenu {
                appMenuItem.title = appName
                submenu.title = appName

                for item in submenu.items {
                    if item.isSeparatorItem { continue }
                    let title = item.title

                    if title.contains("关于") || title.hasPrefix("About ") || title.contains("について") || title.contains("정보") || title.contains("Über") || title.contains("À propos") || title.contains("Acerca") || title.contains("Sobre") {
                        item.title = model.text("menu.about", appName)
                    }
                    else if title.contains("设置") || title.contains("Setting") || title.contains("設定") || title.contains("설정") || title.contains("Einstellung") || title.contains("Réglage") || title.contains("Configur") {
                        item.title = model.text("menu.settings")
                    }
                    else if title.contains("退出") || title.hasPrefix("Quit ") || title.contains("終了") || title.contains("종료") || title.contains("beenden") || title.contains("Quitter") || title.contains("Salir") || title.contains("Sair") {
                        item.title = model.text("menu.quit", appName)
                    }
                }
            }

            for menuItem in mainMenu.items.dropFirst() {
                if Self.knownEditTitles.contains(menuItem.title) {
                    menuItem.title = model.text("menu.edit")
                }
                if Self.knownViewTitles.contains(menuItem.title) {
                    menuItem.title = model.text("menu.view")
                }
                if Self.knownWindowTitles.contains(menuItem.title) {
                    menuItem.title = model.text("menu.window")
                }
                if Self.knownHelpTitles.contains(menuItem.title) {
                    menuItem.title = model.text("menu.help")
                }
            }
        }
    }
}
