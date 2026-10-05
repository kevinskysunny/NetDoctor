import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate?
    var model: AppModel? {
        didSet {
            setupLanguageBinding()
        }
    }
    private var detailWindow: NSWindow?
    private var languageCancellable: AnyCancellable?
    private var menuTrackingCancellable: AnyCancellable?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 关闭自动窗口标签化，避免系统为单窗口实用工具应用自动生成无意义的多标签与窗口集合菜单项
        NSWindow.allowsAutomaticWindowTabbing = false

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

        setupLanguageBinding()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        attachMenuDelegates()
        updateAllMenus()
    }

    private func setupLanguageBinding() {
        MainActor.assumeIsolated {
            guard let model = model ?? Self.shared?.model else { return }
            languageCancellable = model.$language
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if let window = self.detailWindow, let model = self.model ?? Self.shared?.model {
                            window.title = model.text("detail.window.title")
                        }
                        self.attachMenuDelegates()
                        self.updateAllMenus()
                    }
                }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showDetailWindow()
        return true
    }

    @objc func showMainWindow(_ sender: Any?) {
        showDetailWindow()
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
            setupLanguageBinding()
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        attachMenuDelegates()
        updateAllMenus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateAllMenus()
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
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

    // MARK: - Settings Handlers

    private var settingsWindow: NSWindow?

    @objc func showSettingsWindow(_ sender: Any?) {
        openSettingsWindow(sender)
    }

    @objc func showPreferencesWindow(_ sender: Any?) {
        openSettingsWindow(sender)
    }

    @objc func openSettingsWindow(_ sender: Any? = nil) {
        MainActor.assumeIsolated {
            guard let model = model ?? Self.shared?.model else { return }

            if let window = settingsWindow {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let hostingController = NSHostingController(
                rootView: SettingsView(model: model)
                    .frame(width: 500, height: 420)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = model.text("menu.settings").replacingOccurrences(of: "...", with: "")
            window.setContentSize(NSSize(width: 500, height: 420))
            window.minSize = NSSize(width: 480, height: 380)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Help Handlers

    private var helpWindow: NSWindow?

    @objc func showHelpWindow(_ sender: Any?) {
        openHelpWindow()
    }

    @objc func openOnlineDocumentation(_ sender: Any?) {
        if let url = URL(string: "https://support.kevinlabs.app/netdoctor/support.html") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openPrivacyPolicy(_ sender: Any?) {
        if let url = URL(string: "https://support.kevinlabs.app/netdoctor/privacy.html") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openProductWebsite(_ sender: Any?) {
        if let url = URL(string: "https://support.kevinlabs.app/netdoctor/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openContactSupport(_ sender: Any?) {
        if let url = URL(string: "mailto:support@kevinlabs.app?subject=NetDoctor%20Support") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openSystemNetworkSettings(_ sender: Any?) {
        SystemSettingsNavigator.open(.network)
    }

    @objc func openSystemWifiSettings(_ sender: Any?) {
        SystemSettingsNavigator.open(.wifi)
    }

    @objc func openSystemEthernetSettings(_ sender: Any?) {
        SystemSettingsNavigator.open(.ethernet)
    }

    @objc func openSystemDNSSettings(_ sender: Any?) {
        SystemSettingsNavigator.open(.dns)
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
