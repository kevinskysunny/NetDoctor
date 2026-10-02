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
                    Text("\(model.text("app.name")) \(model.text("menu.help"))")
                        .font(.title2.weight(.bold))
                    Text(headerSubtitle(for: model.language))
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
                            howToUseTitle(for: model.language),
                            systemImage: "lightbulb"
                        )
                        .font(.headline)
                        .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            helpItem(
                                icon: "menubar.rectangle",
                                title: menuBarCheckTitle(for: model.language),
                                desc: menuBarCheckDesc(for: model.language)
                            )
                            helpItem(
                                icon: "macwindow.on.rectangle",
                                title: fullDiagTitle(for: model.language),
                                desc: fullDiagDesc(for: model.language)
                            )
                            helpItem(
                                icon: "square.and.arrow.up",
                                title: exportTitle(for: model.language),
                                desc: exportDesc(for: model.language)
                            )
                        }
                    }

                    Divider()

                    // 2. 安全与隐私承诺
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            safetyTitle(for: model.language),
                            systemImage: "shield.checkerboard"
                        )
                        .font(.headline)
                        .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            helpItem(
                                icon: "lock.shield",
                                title: readOnlyTitle(for: model.language),
                                desc: readOnlyDesc(for: model.language)
                            )
                            helpItem(
                                icon: "hand.raised",
                                title: sandboxedTitle(for: model.language),
                                desc: sandboxedDesc(for: model.language)
                            )
                        }
                    }

                    Divider()

                    // 3. 外部链接
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            onlineResourcesTitle(for: model.language),
                            systemImage: "link"
                        )
                        .font(.headline)

                        HStack(spacing: 12) {
                            linkButton(
                                title: docsButtonTitle(for: model.language),
                                icon: "book",
                                url: "https://support.kevinlabs.app/netdoctor/support.html"
                            )
                            linkButton(
                                title: privacyButtonTitle(for: model.language),
                                icon: "hand.raised.fill",
                                url: "https://support.kevinlabs.app/netdoctor/privacy.html"
                            )
                            linkButton(
                                title: websiteButtonTitle(for: model.language),
                                icon: "globe",
                                url: "https://support.kevinlabs.app/netdoctor/"
                            )
                            linkButton(
                                title: emailButtonTitle(for: model.language),
                                icon: "envelope",
                                url: "mailto:support@kevinlabs.app?subject=NetDoctor%20Support"
                            )
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button(closeButtonTitle(for: model.language)) {
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

    private func headerSubtitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "快速使用指南与技术支持"
        case .japanese: return "クイックスタートガイドとサポート"
        case .korean: return "빠른 시작 안내 및 기술 지원"
        case .german: return "Schnellstartanleitung & Support"
        case .french: return "Guide de démarrage rapide et assistance"
        case .spanish: return "Guía de inicio rápido y soporte"
        case .portuguese: return "Guia Rápido e Suporte"
        default: return "Quick Guide & Support"
        }
    }

    private func howToUseTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "如何使用"
        case .japanese: return "使用方法"
        case .korean: return "사용 방법"
        case .german: return "Verwendung"
        case .french: return "Utilisation"
        case .spanish: return "Cómo utilizar"
        case .portuguese: return "Como Usar"
        default: return "How to Use"
        }
    }

    private func menuBarCheckTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "菜单栏快捷检查"
        case .japanese: return "メニューバー簡易診断"
        case .korean: return "메뉴 막대 빠른 확인"
        case .german: return "Menüleisten-Schnellprüfung"
        case .french: return "Vérification rapide dans la barre des menus"
        case .spanish: return "Comprobación rápida en la barra de menús"
        case .portuguese: return "Verificação Rápida na Barra de Menus"
        default: return "Menu Bar Quick Check"
        }
    }

    private func menuBarCheckDesc(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "点击屏幕右上角菜单栏图标，实时预览网络健康评分与当前主要网卡。"
        case .japanese: return "画面右上のメニューバーアイコンをクリックして、ネットワークスコアと主要インターフェースをリアルタイムで確認。"
        case .korean: return "화면 상단의 메뉴 막대 아이콘을 클릭하여 실시간 네트워크 상태 점수와 활성 인터페이스를 확인하세요."
        case .german: return "Klicken Sie auf das Menüleistensymbol für sofortige Netzwerkbewertung und aktive Schnittstellenübersicht."
        case .french: return "Cliquez sur l'icône de la barre des menus pour un aperçu instantané du score réseau et des interfaces actives."
        case .spanish: return "Haga clic en el icono de la barra de menús para ver la puntuación de red y las interfaces activas."
        case .portuguese: return "Clique no ícone da barra de menus para ver a pontuação da rede e a interface ativa em tempo real."
        default: return "Click the menu bar icon for instant network score and active interface overview."
        }
    }

    private func fullDiagTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "深度网络诊断"
        case .japanese: return "詳細ネットワーク診断"
        case .korean: return "정밀 네트워크 진단"
        case .german: return "Ausführliche Diagnose"
        case .french: return "Diagnostic réseau complet"
        case .spanish: return "Diagnóstico completo"
        case .portuguese: return "Diagnóstico Completo"
        default: return "Full Diagnostics"
        }
    }

    private func fullDiagDesc(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "打开主详情窗口，深入排查物理网卡、虚拟隧道、DNS 解析、默认路由与公网探针时延。"
        case .japanese: return "メインウィンドウを開き、物理NIC、トンネル、DNS、ルート、レイテンシプローブを徹底調査。"
        case .korean: return "메인 창을 열어 물리 인터페이스, 가상 터널, DNS 확인, 기본 경로 및 지연 시간 프로브를 심층 점검하세요."
        case .german: return "Öffnen Sie das Hauptfenster für detaillierte Prüfungen von Schnittstellen, Tunneln, DNS, Routen und Latenz."
        case .french: return "Ouvrez la fenêtre principale pour inspecter les interfaces physiques, tunnels, DNS, routes et latences."
        case .spanish: return "Abra la ventana principal para una inspección detallada de interfaces, túneles, DNS, rutas y latencia."
        case .portuguese: return "Abra a janela principal para inspeção detalhada de interfaces físicas, túneis, DNS, rotas e latência."
        default: return "Open Details for in-depth inspection of physical interfaces, tunnels, DNS, routes, and latency probes."
        }
    }

    private func exportTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "一键导出支持包"
        case .japanese: return "診断レポート書き出し"
        case .korean: return "지원 패키지 내보내기"
        case .german: return "Supportpaket exportieren"
        case .french: return "Exporter le pack d'assistance"
        case .spanish: return "Exportar paquete de soporte"
        case .portuguese: return "Exportar Pacote de Suporte"
        default: return "Export Support Package"
        }
    }

    private func exportDesc(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "点击“Export Support”导出脱敏后的诊断 JSON 文件，便于向网络管理员反馈。"
        case .japanese: return "「Export Support」をクリックして、管理者に送信可能なマスク済み診断JSONを書き出し。"
        case .korean: return "'Export Support'를 클릭하여 네트워크 관리자에게 전달할 익명화된 진단 JSON을 생성하세요."
        case .german: return "Klicken Sie auf 'Export Support', um ein anonymisiertes Diagnose-JSON für Fehlersuche zu erstellen."
        case .french: return "Cliquez sur 'Export Support' pour générer un fichier JSON de diagnostic anonymisé pour le dépannage."
        case .spanish: return "Haga clic en 'Export Support' para generar un archivo JSON de diagnóstico anonimizado."
        case .portuguese: return "Clique em 'Export Support' para gerar um JSON de diagnóstico anonimizado para suporte técnico."
        default: return "Click 'Export Support' to generate a redacted diagnostic JSON for network troubleshooting."
        }
    }

    private func safetyTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "安全与隐私"
        case .japanese: return "安全性とプライバシー"
        case .korean: return "보안 및 개인정보 보호"
        case .german: return "Sicherheit & Datenschutz"
        case .french: return "Sécurité et confidentialité"
        case .spanish: return "Seguridad y privacidad"
        case .portuguese: return "Segurança e Privacidade"
        default: return "Safety & Privacy"
        }
    }

    private func readOnlyTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "100% 只读体检"
        case .japanese: return "完全読み取り専用"
        case .korean: return "100% 읽기 전용 진단"
        case .german: return "100% schreibgeschützt"
        case .french: return "100% lecture seule"
        case .spanish: return "100% solo lectura"
        case .portuguese: return "100% Somente Leitura"
        default: return "100% Read-Only"
        }
    }

    private func readOnlyDesc(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "纯被动只读探测，绝不修改系统 DNS、路由表、代理或 VPN 设置。"
        case .japanese: return "受動的な診断のみを行い、システムのDNS、ルーティング、プロキシ、VPNは一切変更しません。"
        case .korean: return "순수 읽기 전용 검사로, 시스템 DNS, 라우팅 테이블, 프록시 또는 VPN 설정을 일절 변경하지 않습니다."
        case .german: return "Rein passive Diagnose. Verändert niemals System-DNS, Routing-Tabellen, Proxys oder VPNs."
        case .french: return "Diagnostic passif en lecture seule. Ne modifie jamais le DNS système, les tables de routage, les proxys ou les VPN."
        case .spanish: return "Diagnóstico pasivo de solo lectura. Nunca modifica DNS del sistema, tablas de enrutamiento, proxies ni VPNs."
        case .portuguese: return "Diagnóstico totalmente somente leitura. Nunca modifica DNS, tabelas de roteamento, proxies ou VPNs do sistema."
        default: return "Purely read-only diagnostics. Never modifies system DNS, routing tables, proxies, or VPNs."
        }
    }

    private func sandboxedTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "沙盒保护与零遥测"
        case .japanese: return "サンドボックス保護＆テレメトリなし"
        case .korean: return "샌드박스 보호 및 텔레메트리 없음"
        case .german: return "Sandboxed & keine Telemetrie"
        case .french: return "Sandboxé et zéro télémétrie"
        case .spanish: return "Aislamiento y cero telemetría"
        case .portuguese: return "Sandboxed e Sem Telemetria"
        default: return "Sandboxed & Zero Telemetry"
        }
    }

    private func sandboxedDesc(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "严格运行在 macOS 沙盒内，不需要管理员特权，绝不在后台上传诊断数据。"
        case .japanese: return "macOS App Sandbox内で動作し、管理者権限不要。バックグラウンドでのデータ送信は一切行いません。"
        case .korean: return "macOS 앱 샌드박스 내에서 실행되며 관리자 권限이 필요하지 않고 백그라운드 데이터 전송이 없습니다."
        case .german: return "Läuft in der macOS-Sandbox ohne Root-Rechte. Überträgt niemals Diagnosedaten im Hintergrund."
        case .french: return "Fonctionne dans le bac à sable macOS sans privilèges root. Ne transmet aucune télémétrie."
        case .spanish: return "Funciona dentro del Sandbox de macOS sin privilegios root. Jamás envía datos de diagnóstico."
        case .portuguese: return "Opera dentro do Sandbox do macOS sem privilégios root. Nunca envia telemetria em segundo plano."
        default: return "Operates within macOS App Sandbox without root privileges. Never uploads telemetry."
        }
    }

    private func onlineResourcesTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "官方在线支持与资源"
        case .japanese: return "公式オンラインサポートとリソース"
        case .korean: return "공식 온라인 지원 및 리소스"
        case .german: return "Offizielle Online-Ressourcen & Support"
        case .french: return "Ressources et support officiels en ligne"
        case .spanish: return "Recursos y soporte oficial en línea"
        case .portuguese: return "Recursos Oficiais e Suporte Online"
        default: return "Official Online Support & Resources"
        }
    }

    private func docsButtonTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "使用帮助指南"
        case .japanese: return "サポートガイド"
        case .korean: return "사용 설명서"
        case .german: return "Support-Handbuch"
        case .french: return "Guide d'assistance"
        case .spanish: return "Guía de ayuda"
        case .portuguese: return "Guia de Suporte"
        default: return "Support Guide"
        }
    }

    private func privacyButtonTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "应用隐私政策"
        case .japanese: return "プライバシーポリシー"
        case .korean: return "개인정보 처리방침"
        case .german: return "Datenschutz"
        case .french: return "Confidentialité"
        case .spanish: return "Privacidad"
        case .portuguese: return "Privacidade"
        default: return "Privacy Policy"
        }
    }

    private func websiteButtonTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "官方产品主页"
        case .japanese: return "製品公式サイト"
        case .korean: return "제품 공식 웹사이트"
        case .german: return "Produkt-Website"
        case .french: return "Site du produit"
        case .spanish: return "Sitio web del producto"
        case .portuguese: return "Site do Produto"
        default: return "Product Website"
        }
    }

    private func emailButtonTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "邮件技术支持"
        case .japanese: return "メールサポート"
        case .korean: return "이메일 지원"
        case .german: return "E-Mail-Support"
        case .french: return "Support par e-mail"
        case .spanish: return "Soporte por correo"
        case .portuguese: return "Suporte por E-mail"
        default: return "Email Support"
        }
    }

    private func closeButtonTitle(for lang: AppLanguage) -> String {
        switch lang.resolvedLanguage {
        case .chinese: return "关闭"
        case .japanese: return "閉じる"
        case .korean: return "닫기"
        case .german: return "Schließen"
        case .french: return "Fermer"
        case .spanish: return "Cerrar"
        case .portuguese: return "Fechar"
        default: return "Close"
        }
    }
}
