import NetworkCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("外网探测") {
                Stepper(value: Binding(
                    get: { model.settings.attemptsPerEndpoint },
                    set: { model.updateAttempts($0) }
                ), in: 1...10) {
                    LabeledContent("每端点尝试次数", value: "\(model.settings.attemptsPerEndpoint)")
                }

                HStack {
                    Text("超时")
                    Slider(value: Binding(
                        get: { model.settings.timeoutSeconds },
                        set: { model.updateTimeout($0) }
                    ), in: 0.5...10, step: 0.5)
                    Text(model.settings.timeoutSeconds, format: .number.precision(.fractionLength(1)))
                        .frame(width: 42, alignment: .trailing)
                        .monospacedDigit()
                }

                LabeledContent("默认端点") {
                    Text(model.settings.endpoints.map(\.displayName).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Button("恢复默认端点") {
                    model.resetEndpoints()
                }
            }

            Section("自动巡检") {
                Toggle("网络变化后自动检查", isOn: Binding(
                    get: { model.settings.autoRefreshEnabled },
                    set: { model.updateAutoRefresh($0) }
                ))

                Stepper(value: Binding(
                    get: { model.settings.refreshIntervalSeconds },
                    set: { model.updateRefreshInterval($0) }
                ), in: 60...3_600, step: 30) {
                    LabeledContent("周期巡检间隔", value: "\(model.settings.refreshIntervalSeconds) 秒")
                }
                .disabled(!model.settings.autoRefreshEnabled)
            }

            Section("隐私") {
                Label("诊断数据只保存在本机，不会自动上传。", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Label("支持包导出会脱敏 Wi-Fi SSID，不包含用户名、路径、Cookie 或密钥。", systemImage: "doc.badge.gearshape")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}
