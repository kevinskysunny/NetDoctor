import NetworkCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.text("settings.section.probe")) {
                Stepper(value: Binding(
                    get: { model.settings.attemptsPerEndpoint },
                    set: { model.updateAttempts($0) }
                ), in: 1...10) {
                    LabeledContent(model.text("settings.attempts"), value: "\(model.settings.attemptsPerEndpoint)")
                }

                HStack {
                    Text(model.text("settings.timeout"))
                    Slider(value: Binding(
                        get: { model.settings.timeoutSeconds },
                        set: { model.updateTimeout($0) }
                    ), in: 0.5...10, step: 0.5)
                    Text(model.settings.timeoutSeconds, format: .number.precision(.fractionLength(1)))
                        .frame(width: 42, alignment: .trailing)
                        .monospacedDigit()
                }

                LabeledContent(model.text("settings.defaultEndpoints")) {
                    Text(model.settings.endpoints.map(\.displayName).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Button(model.text("settings.resetEndpoints")) {
                    model.resetEndpoints()
                }
            }

            Section(model.text("settings.section.auto")) {
                Toggle(model.text("settings.autoRefresh"), isOn: Binding(
                    get: { model.settings.autoRefreshEnabled },
                    set: { model.updateAutoRefresh($0) }
                ))

                Stepper(value: Binding(
                    get: { model.settings.refreshIntervalSeconds },
                    set: { model.updateRefreshInterval($0) }
                ), in: 60...3_600, step: 30) {
                    LabeledContent(model.text("settings.interval"), value: model.text("settings.seconds", model.settings.refreshIntervalSeconds))
                }
                .disabled(!model.settings.autoRefreshEnabled)
            }

            Section(model.text("settings.section.privacy")) {
                Label(model.text("settings.privacy.local"), systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Label(model.text("settings.privacy.redacted"), systemImage: "doc.badge.gearshape")
                    .foregroundStyle(.secondary)
            }

            Section(model.text("settings.section.language")) {
                Picker(model.text("settings.language"), selection: Binding(
                    get: { model.language },
                    set: { model.updateLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                LabeledContent(model.text("settings.version"), value: model.versionText)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(model.text("detail.tab.settings"))
    }
}
