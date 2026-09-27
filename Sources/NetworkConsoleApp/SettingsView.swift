import NetworkCore
import SwiftUI

/// 极客控制台与隐私透明堡垒风格设置页面
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. 顶部系统语言与版本信息栏
                topBar

                // 2. 体检探针引擎控制舱 (Diagnostic Engine Pod)
                engineControlPod

                // 3. 自动化巡检律动舱 (Auto-Pulse Telemetry Pod)
                autoPulsePod

                // 4. 隐私安全透明堡垒 (Privacy & Security Fortress Bento)
                privacyFortressPod

                // 5. 开发者与生态联动橱窗 (Ecosystem Showcase)
                ecosystemPod
            }
            .padding(20)
        }
        .navigationTitle(model.text("detail.tab.settings"))
    }

    // MARK: - 1. 顶部语言与版本栏
    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text(model.text("detail.tab.settings"))
                .font(.headline.weight(.semibold))

            Spacer()

            // 语言切换选择器
            HStack(spacing: 6) {
                Image(systemName: "character.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { model.language },
                    set: { model.updateLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName(in: model.language)).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

            // 版本号芯片
            Text(model.versionText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - 2. 体检探针引擎控制舱
    private var engineControlPod: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.cyan)

                Text(model.text("settings.engine.title"))
                    .font(.headline.weight(.semibold))

                Text(model.text("settings.engine.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                // 每端点重试次数
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.text("settings.attempts"))
                            .font(.callout.weight(.medium))
                        Text(model.text("settings.attempts.hint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            if model.settings.attemptsPerEndpoint > 1 {
                                model.updateAttempts(model.settings.attemptsPerEndpoint - 1)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.caption.bold())
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.settings.attemptsPerEndpoint <= 1)

                        Text("\(model.settings.attemptsPerEndpoint)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 28, alignment: .center)

                        Button {
                            if model.settings.attemptsPerEndpoint < 10 {
                                model.updateAttempts(model.settings.attemptsPerEndpoint + 1)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.settings.attemptsPerEndpoint >= 10)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // 超时时间滑块与预设胶囊
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.text("settings.timeout"))
                                .font(.callout.weight(.medium))
                            Text(model.text("settings.timeout.hint"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(model.text("settings.timeout.value", model.settings.timeoutSeconds))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }

                    Slider(value: Binding(
                        get: { model.settings.timeoutSeconds },
                        set: { model.updateTimeout($0) }
                    ), in: 0.5...10.0, step: 0.5)
                    .tint(.cyan)

                    // 快速场景预设胶囊
                    HStack(spacing: 8) {
                        timeoutPresetButton(title: model.text("settings.timeout.presetSpeedy"), value: 1.0)
                        timeoutPresetButton(title: model.text("settings.timeout.presetBalanced"), value: 3.0)
                        timeoutPresetButton(title: model.text("settings.timeout.presetDeep"), value: 5.0)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // 公开探测端点芯片矩阵
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.text("settings.endpoints.title"))
                            .font(.callout.weight(.medium))
                        Spacer()
                        Button(model.text("settings.resetEndpoints")) {
                            model.resetEndpoints()
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(model.settings.endpoints) { ep in
                            HStack(spacing: 8) {
                                Image(systemName: "globe.asia.australia.fill")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ep.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(ep.host)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("HTTPS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func timeoutPresetButton(title: String, value: Double) -> some View {
        let isSelected = abs(model.settings.timeoutSeconds - value) < 0.1
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                model.updateTimeout(value)
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
                .foregroundStyle(isSelected ? Color.cyan : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. 自动化巡检律动舱
    private var autoPulsePod: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)

                Text(model.text("settings.auto.title"))
                    .font(.headline.weight(.semibold))

                Text(model.text("settings.auto.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                // 自动检查开关
                Toggle(isOn: Binding(
                    get: { model.settings.autoRefreshEnabled },
                    set: { model.updateAutoRefresh($0) }
                )) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.settings.autoRefreshEnabled ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.text("settings.autoRefresh"))
                                .font(.callout.weight(.medium))
                            Text(model.text("settings.autoRefresh.hint"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(12)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // 巡检周期预设胶囊
                if model.settings.autoRefreshEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(model.text("settings.interval"))
                                .font(.callout.weight(.medium))
                            Spacer()
                            Text(model.text("settings.seconds", model.settings.refreshIntervalSeconds))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }

                        HStack(spacing: 8) {
                            intervalPresetButton(title: model.text("settings.auto.preset1m"), seconds: 60)
                            intervalPresetButton(title: model.text("settings.auto.preset5m"), seconds: 300)
                            intervalPresetButton(title: model.text("settings.auto.preset15m"), seconds: 900)
                            intervalPresetButton(title: model.text("settings.auto.preset1h"), seconds: 3600)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func intervalPresetButton(title: String, seconds: Int) -> some View {
        let isSelected = model.settings.refreshIntervalSeconds == seconds
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                model.updateRefreshInterval(seconds)
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.green.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
                .foregroundStyle(isSelected ? Color.green : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. 隐私安全透明堡垒
    private var privacyFortressPod: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue)

                Text(model.text("settings.privacy.title"))
                    .font(.headline.weight(.semibold))

                Text(model.text("settings.privacy.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 4 柱安全堡垒 Bento Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                privacyCard(
                    icon: "lock.shield",
                    color: .green,
                    title: model.text("settings.privacy.item1.title"),
                    desc: model.text("settings.privacy.item1.desc")
                )
                privacyCard(
                    icon: "externaldrive.badge.shield",
                    color: .blue,
                    title: model.text("settings.privacy.item2.title"),
                    desc: model.text("settings.privacy.item2.desc")
                )
                privacyCard(
                    icon: "xmark.seal",
                    color: .orange,
                    title: model.text("settings.privacy.item3.title"),
                    desc: model.text("settings.privacy.item3.desc")
                )
                privacyCard(
                    icon: "eye.slash",
                    color: .purple,
                    title: model.text("settings.privacy.item4.title"),
                    desc: model.text("settings.privacy.item4.desc")
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func privacyCard(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 5. 开发者与生态联动橱窗
    private var ecosystemPod: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "app.gift.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.pink)

                Text(model.text("settings.ecosystem.title"))
                    .font(.headline.weight(.semibold))
            }

            VStack(spacing: 10) {
                ecosystemCard(
                    title: model.text("settings.presenterdeck.title"),
                    desc: model.text("settings.presenterdeck.desc"),
                    icon: "sparkles.tv",
                    gradient: Color.purple.gradient,
                    url: "macappstore://apps.apple.com/app/id6805086319?mt=12"
                )

                ecosystemCard(
                    title: model.text("settings.volmix.title"),
                    desc: model.text("settings.volmix.desc"),
                    icon: "slider.vertical.3",
                    gradient: Color.accentColor.gradient,
                    url: "macappstore://apps.apple.com/app/id6806717830?mt=12"
                )

                ecosystemCard(
                    title: model.text("settings.ksicstudio.title"),
                    desc: model.text("settings.ksicstudio.desc"),
                    icon: "rectangle.grid.2x2",
                    gradient: Color.blue.gradient,
                    url: "macappstore://apps.apple.com/app/id6801325655?mt=12"
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func ecosystemCard(title: String, desc: String, icon: String, gradient: AnyGradient, url: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text("Mac App Store")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(.quaternary, in: Capsule())
                }
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if let targetURL = URL(string: url) {
                    NSWorkspace.shared.open(targetURL)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.text("common.viewInStore"))
                        .font(.caption.weight(.medium))
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
