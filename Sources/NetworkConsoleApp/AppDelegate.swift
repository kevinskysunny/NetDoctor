import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    private var detailWindow: NSWindow?
    private var languageCancellable: AnyCancellable?

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        showDetailWindow()
        updateMainMenu()
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
            guard let model else { return }

            if let detailWindow, detailWindow.isVisible {
                detailWindow.makeKeyAndOrderFront(nil)
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
                    guard let self, let window = self.detailWindow, let model = self.model else { return }
                    window.title = model.text("detail.window.title")
                    self.updateMainMenu()
                }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateMainMenu() {
        MainActor.assumeIsolated {
            guard let model, let mainMenu = NSApp.mainMenu else { return }
            let appName = model.text("app.name")

            if let appMenuItem = mainMenu.item(at: 0) {
                appMenuItem.title = appName
                if let submenu = appMenuItem.submenu {
                    for item in submenu.items {
                        if item.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) {
                            item.title = model.text("menu.about", appName)
                        }
                        if item.action == #selector(NSApplication.terminate(_:)) {
                            item.title = model.text("menu.quit", appName)
                        }
                        if Self.knownSettingsTitles.contains(item.title) {
                            item.title = model.text("menu.settings")
                        }
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
            }
        }
    }
}
