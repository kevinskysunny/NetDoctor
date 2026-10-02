import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    var model: AppModel?
    private var detailWindow: NSWindow?
    private var languageCancellable: AnyCancellable?
    private var menuTimer: Timer?

    override init() {
        super.init()
        Self.shared = self
    }

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
        menuTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMenuTitles()
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
                    self.updateMenuTitles()
                }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateMenuTitles() {
        MainActor.assumeIsolated {
            guard let model, let mainMenu = NSApp.mainMenu else { return }

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
