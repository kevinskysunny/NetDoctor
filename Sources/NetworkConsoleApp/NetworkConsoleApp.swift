import NetworkCore
import SwiftUI

@main
struct NetworkConsoleLiteApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            QuickCheckView(model: model)
        } label: {
            Image(systemName: model.statusSymbolName)
        }
        .menuBarExtraStyle(.window)

        Window("网络体检", id: "detail") {
            DetailView(model: model)
                .frame(minWidth: 840, minHeight: 560)
        }
        .defaultSize(width: 980, height: 700)

        Settings {
            SettingsView(model: model)
                .frame(width: 500, height: 420)
        }
    }
}
