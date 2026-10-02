import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate?
    var model: AppModel?
    private var detailWindow: NSWindow?
    private var languageCancellable: AnyCancellable?
    private var menuTrackingCancellable: AnyCancellable?
    private var menuTimer: Timer?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showDetailWindow()
        attachMenuDelegates()
        updateAllMenus()

        // 监听菜单打开跟踪事件：只要用户点击菜单栏，立刻确保菜单是最新选择的语言
        menuTrackingCancellable = NotificationCenter.default
            .publisher(for: NSMenu.didBeginTrackingNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.attachMenuDelegates()
                self?.updateAllMenus()
            }

        // 定时轮询，保障系统动态插入项（如 Services、输入法等）也被本地化
        menuTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateAllMenus()
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
                    self.updateAllMenus()
                }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateAllMenus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateAllMenus()
    }

    private func attachMenuDelegates() {
        guard let mainMenu = NSApp.mainMenu else { return }
        mainMenu.delegate = self
        for item in mainMenu.items {
            item.submenu?.delegate = self
            for subItem in item.submenu?.items ?? [] {
                subItem.submenu?.delegate = self
            }
        }
    }

    func updateAllMenus() {
        MainActor.assumeIsolated {
            guard let mainMenu = NSApp.mainMenu else { return }
            let model = self.model ?? Self.shared?.model
            let raw = UserDefaults.standard.string(forKey: "netdoctor.language") ?? "system"
            let lang = model?.language ?? AppLanguage(rawValue: raw) ?? .system
            let appName = model?.text("app.name") ?? "NetDoctor"

            MenuLocalizer.update(mainMenu: mainMenu, language: lang, appName: appName)
        }
    }

    // MARK: - Help Handlers

    private var helpWindow: NSWindow?

    @objc func showHelpWindow(_ sender: Any?) {
        openHelpWindow()
    }

    @objc func openOnlineDocumentation(_ sender: Any?) {
        if let url = URL(string: "https://github.com/kevinskysunny/networkconsole-lite#readme") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openPrivacyPolicy(_ sender: Any?) {
        if let url = URL(string: "https://gist.github.com/kevinskysunny/845b67c757d7a81ae9db3cb4a7ee9213") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openContactSupport(_ sender: Any?) {
        if let url = URL(string: "mailto:kevinskysunny@gmail.com?subject=NetDoctor%20Support") {
            NSWorkspace.shared.open(url)
        }
    }

    func openHelpWindow() {
        MainActor.assumeIsolated {
            guard let model = model ?? Self.shared?.model else { return }

            if let window = helpWindow {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let hostingController = NSHostingController(
                rootView: HelpView(model: model)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = model.language == .chinese ? "\(model.text("app.name")) 帮助" : "\(model.text("app.name")) Help"
            window.setContentSize(NSSize(width: 580, height: 500))
            window.minSize = NSSize(width: 520, height: 440)
            window.center()
            window.isReleasedWhenClosed = false
            helpWindow = window
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
