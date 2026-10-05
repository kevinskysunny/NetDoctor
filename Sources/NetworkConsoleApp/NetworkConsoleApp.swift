import NetworkCore
import SwiftUI

@main
struct NetDoctorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        appDelegate.model = model
        AppDelegate.shared?.model = model
    }

    var body: some Scene {
        MenuBarExtra {
            QuickCheckView(model: model)
        } label: {
            Image(systemName: model.statusSymbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 500, height: 420)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(model.text("menu.about", model.text("app.name"))) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button(model.text("menu.settings")) {
                    AppDelegate.shared?.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Divider()
                Button(model.text("action.openSettings.network")) {
                    SystemSettingsNavigator.open(.network)
                }
            }
            CommandGroup(replacing: .undoRedo) {
                // 剔除只读体检工具完全用不上的 Undo / Redo
            }
            CommandGroup(replacing: .help) {
                Button("\(model.text("app.name")) \(model.text("menu.help"))") {
                    AppDelegate.shared?.openHelpWindow()
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button(model.text("menu.quit", model.text("app.name"))) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
