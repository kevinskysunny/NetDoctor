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

            Section(model.text("settings.section.developer")) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.vertical.3")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.text("settings.volmix.title"))
                                    .font(.headline)
                                Text("App Store")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(.quaternary, in: Capsule())
                            }
                            Text(model.text("settings.volmix.desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            if let url = URL(string: "macappstore://apps.apple.com/app/id6806717830?mt=12") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(model.text("common.viewInStore"))
                                Image(systemName: "arrow.up.forward.app")
                            }
                        }
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.text("settings.ksicstudio.title"))
                                    .font(.headline)
                                Text("Free")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(.quaternary, in: Capsule())
                            }
                            Text(model.text("settings.ksicstudio.desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            if let url = URL(string: "macappstore://apps.apple.com/app/id6801325655?mt=12") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(model.text("common.viewInStore"))
                                Image(systemName: "arrow.up.forward.app")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(model.text("detail.tab.settings"))
    }
}
