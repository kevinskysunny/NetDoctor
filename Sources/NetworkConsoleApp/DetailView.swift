import Charts
import NetworkCore
import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview
    case interfaces
    case dnsRoute
    case reachability
    case timeline
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.50percent"
        case .interfaces: return "network"
        case .dnsRoute: return "point.3.filled.connected.trianglepath.dotted"
        case .reachability: return "globe"
        case .timeline: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct DetailView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab: DetailTab = .overview
    @State private var copiedToast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 现代化分段导航胶囊栏
            HStack(spacing: 6) {
                ForEach(DetailTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(tabTitle(tab))
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                                ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if copiedToast {
                    Text(model.text("detail.copiedCard"))
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button {
                    if model.copyDiagnosisCard() {
                        withAnimation { copiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedToast = false }
                        }
                    }
                } label: {
                    Label(model.text("detail.copyCard"), systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // 选项卡内容区
            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(
                        model: model,
                        isTabActive: selectedTab == .overview,
                        onSelectPipelineNode: { node in
                            switch node {
                            case .localMac:
                                selectedTab = .interfaces
                            case .gateway, .dns:
                                selectedTab = .dnsRoute
                            case .internet:
                                selectedTab = .reachability
                            }
                        }
                    )
                case .interfaces:
                    InterfacesView(model: model)
                case .dnsRoute:
                    DNSRouteView(model: model)
                case .reachability:
                    ReachabilityView(model: model)
                case .timeline:
                    DetailTimelineView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(model.text("detail.checkNow")) {
                    Task {
                        await model.runCheck()
                    }
                }
                .disabled(model.isChecking)

                Button(model.text("detail.export")) {
                    model.exportSupportPackage()
                }
            }
        }
        .sensoryFeedback(.success, trigger: model.report?.timestamp)
    }

    private func tabTitle(_ tab: DetailTab) -> String {
        switch tab {
        case .overview: return model.text("detail.tab.overview")
        case .interfaces: return model.text("detail.tab.interfaces")
        case .dnsRoute: return model.text("detail.tab.dnsRoute")
        case .reachability: return model.text("detail.tab.reachability")
        case .timeline: return model.text("detail.tab.timeline")
        case .settings: return model.text("detail.tab.settings")
        }
    }
}

