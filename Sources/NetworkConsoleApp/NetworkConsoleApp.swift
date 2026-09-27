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
    }
}
