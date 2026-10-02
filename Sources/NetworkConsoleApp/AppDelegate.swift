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

    func applicationDidFinishLaunching(_ notification: Notification) {
        showDetailWindow()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
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
        guard let mainMenu = NSApp.mainMenu else { return }

        let raw = UserDefaults.standard.string(forKey: "netdoctor.language") ?? "system"
        let lang = (AppLanguage(rawValue: raw) ?? .system).resolvedLanguage

        let editText = L10n.string("menu.edit", language: lang)
        let viewText = L10n.string("menu.view", language: lang)
        let windowText = L10n.string("menu.window", language: lang)
        let helpText = L10n.string("menu.help", language: lang)

        for menuItem in mainMenu.items.dropFirst() {
            guard let submenu = menuItem.submenu else { continue }
            let actions = Set(submenu.items.compactMap { $0.action })

            if actions.contains(#selector(UndoManager.undo)) || actions.contains(Selector(("copy:"))) {
                menuItem.title = editText
            }
            else if actions.contains(Selector(("toggleFullScreen:"))) {
                menuItem.title = viewText
            }
            else if actions.contains(#selector(NSWindow.performMiniaturize(_:))) || actions.contains(#selector(NSWindow.performZoom(_:))) {
                menuItem.title = windowText
            }
            else if actions.contains(Selector(("showHelp:"))) || actions.contains(Selector(("helpClicked:"))) {
                menuItem.title = helpText
            }
            else {
                let title = menuItem.title
                if title.contains("Help") || title.contains("帮助") || title.contains("ヘルプ") || title.contains("도움말") || title.contains("Hilfe") || title.contains("Aide") || title.contains("Ayuda") || title.contains("Ajuda") {
                    menuItem.title = helpText
                }
            }
        }
    }
}
