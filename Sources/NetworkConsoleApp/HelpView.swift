import AppKit
import NetworkCore
import SwiftUI

struct HelpView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.text("menu.about", model.text("app.name")))
                        .font(.title2.weight(.bold))
                    Text(model.language == .chinese ? "快速使用指南与技术支持" : "Quick Guide & Support")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(model.versionText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 使用指南
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            model.language == .chinese ? "如何使用" : "How to Use",
                            systemImage: "lightbulb"
                        )
                        .font(.headline)
                        .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            helpItem(
                                icon: "menubar.rectangle",
                                title: model.language == .chinese ? "菜单栏快捷检查" : "Menu Bar Quick Check",
                                desc: model.language == .chinese ? "点击屏幕右上角菜单栏图标，实时预览网络健康评分与当前主要网卡。" : "Click the menu bar icon for instant network score and active interface overview."
                            )
                            helpItem(
                                icon: "macwindow.on.rectangle",
                                title: model.language == .chinese ? "深度网络诊断" : "Full Diagnostics",
                                desc: model.language == .chinese ? "打开主详情窗口，深入排查物理网卡、虚拟隧道、DNS 解析、默认路由与公网探针时延。" : "Open Details for in-depth inspection of physical interfaces, tunnels, DNS, routes, and latency probes."
                            )
                            helpItem(
                                icon: "square.and.arrow.up",
                                title: model.language == .chinese ? "一键导出支持包" : "Export Support Package",
                                desc: model.language == .chinese ? "点击“Export Support”导出脱敏后的诊断 JSON 文件，便于向网络管理员反馈。" : "Click 'Export Support' to generate a redacted diagnostic JSON for network troubleshooting."
                            )
                        }
                    }

                    Divider()

                    // 2. 安全与隐私承诺
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            model.language == .chinese ? "安全与隐私" : "Safety & Privacy",
                            systemImage: "shield.checkerboard"
                        )
                        .font(.headline)
                        .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            helpItem(
                                icon: "lock.shield",
                                title: model.language == .chinese ? "100% 只读体检" : "100% Read-Only",
                                desc: model.language == .chinese ? "纯被动只读探测，绝不修改系统 DNS、路由表、代理或 VPN 设置。" : "Purely read-only diagnostics. Never modifies system DNS, routing tables, proxies, or VPNs."
                            )
                            helpItem(
                                icon: "hand.raised",
                                title: model.language == .chinese ? "沙盒保护与零遥测" : "Sandboxed & Zero Telemetry",
                                desc: model.language == .chinese ? "严格运行在 macOS 沙盒内，不需要管理员特权，绝不在后台上传诊断数据。" : "Operates within macOS App Sandbox without root privileges. Never uploads telemetry."
                            )
                        }
                    }

                    Divider()

                    // 3. 外部链接
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            model.language == .chinese ? "在线支持与资源" : "Online Support & Resources",
                            systemImage: "link"
                        )
                        .font(.headline)

                        HStack(spacing: 12) {
                            linkButton(
                                title: model.language == .chinese ? "在线使用文档" : "Online Documentation",
                                icon: "book",
                                url: "https://github.com/kevinskysunny/networkconsole-lite#readme"
                            )
                            linkButton(
                                title: model.language == .chinese ? "隐私政策" : "Privacy Policy",
                                icon: "hand.raised.fill",
                                url: "https://gist.github.com/kevinskysunny/845b67c757d7a81ae9db3cb4a7ee9213"
                            )
                            linkButton(
                                title: model.language == .chinese ? "邮件反馈" : "Email Support",
                                icon: "envelope",
                                url: "mailto:kevinskysunny@gmail.com?subject=NetDoctor%20Support"
                            )
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button(model.language == .chinese ? "关闭" : "Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 500)
    }

    private func helpItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linkButton(title: String, icon: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
