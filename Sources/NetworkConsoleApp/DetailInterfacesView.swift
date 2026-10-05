import NetworkCore
import SwiftUI

struct InterfacesView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: InterfaceFilter = .physical

    var body: some View {
        Group {
            if let report = model.report, !report.interfaces.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 顶部遥测指示舱 (Interface Telemetry Pod)
                        InterfaceTelemetryPod(report: report, model: model)

                        // 1.5 多维分类筛选器
                        Picker("", selection: $selectedFilter) {
                            ForEach(InterfaceFilter.allCases, id: \.self) { filter in
                                Text(model.text(filter.l10nKey)).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)

                        // 2. 刀片机架卡片网格 (Blade Rack Cards)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 380), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(InterfaceFilterApplier.apply(selectedFilter, to: report.interfaces)) { iface in
                                InterfaceBladeCard(interface: iface, model: model)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    model.text("interfaces.empty.title"),
                    systemImage: "network.slash",
                    description: Text(model.text("interfaces.empty.message"))
                )
            }
        }
        .navigationTitle(model.text("detail.tab.interfaces"))
    }
}

// MARK: - 接口遥测指标舱
struct InterfaceTelemetryPod: View {
    let report: DiagnosisReport
    @ObservedObject var model: AppModel

    var body: some View {
        let activeCount = report.interfaces.filter { $0.isActive }.count
        let totalCount = report.interfaces.count
        let primaryUplink = report.interfaces.first(where: { $0.isDefaultRouteInterface })
        let hasIPv4 = report.interfaces.contains { $0.addresses.contains { $0.family == "IPv4" } }
        let hasIPv6 = report.interfaces.contains { $0.addresses.contains { $0.family == "IPv6" } }

        HStack(spacing: 14) {
            // 活动网卡
            telemetryItem(
                title: model.text("interfaces.telemetry.activeTitle"),
                value: "\(activeCount) / \(totalCount)",
                detail: model.text("interfaces.telemetry.activeDetail"),
                systemImage: "network",
                accentColor: .blue
            )

            Divider().frame(height: 32).opacity(0.3)

            // 主干出口
            telemetryItem(
                title: model.text("interfaces.telemetry.primaryTitle"),
                value: primaryUplink?.name ?? "—",
                detail: primaryUplink != nil ? model.text(for: primaryUplink!.kind) : model.text("interfaces.telemetry.none"),
                systemImage: "arrow.up.forward.circle.fill",
                accentColor: .cyan
            )

            Divider().frame(height: 32).opacity(0.3)

            // 双栈协议
            telemetryItem(
                title: model.text("interfaces.telemetry.dualStackTitle"),
                value: (hasIPv4 && hasIPv6) ? "IPv4 + IPv6" : (hasIPv4 ? "IPv4" : (hasIPv6 ? "IPv6" : "—")),
                detail: (hasIPv4 && hasIPv6) ? model.text("interfaces.telemetry.dualReady") : model.text("interfaces.telemetry.singleReady"),
                systemImage: "bolt.horizontal.fill",
                accentColor: .purple
            )
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func telemetryItem(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        accentColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 刀片网卡硬件模块卡片
struct InterfaceBladeCard: View {
    let interface: InterfaceInfo
    @ObservedObject var model: AppModel

    @State private var isHovered = false
    @State private var copiedAddress: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部 Header：硬件图标 + 名称 + 芯片类型 + 主干徽章 + 物理 Link LED
            HStack(alignment: .center, spacing: 10) {
                // 硬件图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hardwareAccentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(hardwareAccentColor.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: hardwareIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hardwareAccentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(interface.name)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))

                        // 接口类型胶囊
                        Text(model.text(InterfaceCategoryStyle.style(for: InterfaceCategoryResolver.resolve(kind: interface.kind, name: interface.name)).l10nKey))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.6), in: Capsule())

                        // 主干链路徽章 (Primary Uplink)
                        if interface.isDefaultRouteInterface {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text("PRIMARY")
                                    .font(.system(size: 9, weight: .heavy))
                            }
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }

                Spacer()

                // 物理链路状态指示灯 (Hardware Link LED)
                HStack(spacing: 5) {
                    Circle()
                        .fill(interface.linkState == .up ? Color(red: 0.2, green: 0.88, blue: 0.5) : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: interface.linkState == .up ? Color.green.opacity(0.7) : .clear,
                            radius: 3
                        )

                    Text(model.text(for: interface.linkState))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(interface.linkState == .up ? Color.green : Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (interface.linkState == .up ? Color.green : Color.secondary).opacity(0.1),
                    in: Capsule()
                )

                // 系统设置快捷跳转
                Button {
                    let pane: SystemSettingsPane
                    switch interface.kind {
                    case .wifi:
                        pane = .wifi
                    case .wired:
                        pane = .ethernet
                    default:
                        pane = .network
                    }
                    SystemSettingsNavigator.open(pane)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help(settingsHelpText)
            }

            Divider()
                .opacity(0.5)

            // Wi-Fi 专属无线电舱 (SSID + 天线)
            if let ssid = interface.ssid {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("SSID:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(ssid)
                        .font(.callout.weight(.semibold))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        SystemSettingsNavigator.open(.wifi)
                    } label: {
                        HStack(spacing: 3) {
                            Text(model.text("action.openSettings.wifi"))
                                .font(.caption2.weight(.medium))
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(Color.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // IP 地址芯片列表 (IPv4 / IPv6 Chip Tags with instant copy)
            VStack(alignment: .leading, spacing: 8) {
                if interface.addresses.isEmpty {
                    Text(model.text("interfaces.noAddress"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(interface.addresses, id: \.address) { addr in
                        ipAddressChip(addr: addr)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHovered ? hardwareAccentColor.opacity(0.4) : Color.white.opacity(0.1),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func ipAddressChip(addr: IPAddressInfo) -> some View {
        let isIPv4 = addr.family == "IPv4"
        let chipColor = isIPv4 ? Color.blue : Color.purple
        let isCopied = copiedAddress == addr.address

        return HStack(spacing: 8) {
            // 协议版本徽章
            Text(addr.family)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(chipColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(chipColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            // IP 地址文本
            Text(addr.address)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .textSelection(.enabled)

            Spacer()

            // 快捷复制按钮（带反馈）
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(addr.address, forType: .string)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    copiedAddress = addr.address
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        if copiedAddress == addr.address {
                            copiedAddress = nil
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10))
                    if isCopied {
                        Text(model.text("interfaces.copied"))
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundStyle(isCopied ? Color.green : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((isCopied ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var hardwareIconName: String {
        InterfaceCategoryStyle.style(for: InterfaceCategoryResolver.resolve(kind: interface.kind, name: interface.name)).sfSymbol
    }

    private var hardwareAccentColor: Color {
        if interface.isDefaultRouteInterface {
            return .cyan
        }
        return InterfaceCategoryStyle.style(for: InterfaceCategoryResolver.resolve(kind: interface.kind, name: interface.name)).accentColor
    }

    private var settingsHelpText: String {
        switch interface.kind {
        case .wifi:
            return model.text("action.openSettings.wifi")
        case .wired:
            return model.text("action.openSettings.ethernet")
        default:
            return model.text("action.openSettings.network")
        }
    }
}