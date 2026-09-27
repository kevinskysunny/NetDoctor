import NetworkCore
import SwiftUI

struct DetailTimelineView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: TimelineFilter = .all

    enum TimelineFilter: String, CaseIterable, Identifiable {
        case all
        case pathChanges
        case checks
        case exports

        var id: String { rawValue }
    }

    private var filteredEvents: [TimelineEvent] {
        let events = model.timelineEvents.reversed()
        switch selectedFilter {
        case .all:
            return Array(events)
        case .pathChanges:
            return events.filter { $0.kind == .pathChanged }
        case .checks:
            return events.filter { $0.kind == .checkStarted || $0.kind == .checkFinished }
        case .exports:
            return events.filter { $0.kind == .exportCreated || $0.kind == .diagnostic }
        }
    }

    var body: some View {
        Group {
            if model.timelineEvents.isEmpty {
                ContentUnavailableView(
                    model.text("timeline.empty.title"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.text("timeline.empty.message"))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 顶部事件过滤胶囊栏 (Filter Chips)
                        filterBar

                        // 2. 垂直时空铁轨事件流 (Chronological Railway)
                        if filteredEvents.isEmpty {
                            ContentUnavailableView(
                                model.text("timeline.filterEmpty.title"),
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text(model.text("timeline.filterEmpty.message"))
                            )
                            .frame(maxWidth: .infinity, minHeight: 240)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                    TimelineRailwayItem(
                                        event: event,
                                        isLast: index == filteredEvents.count - 1,
                                        model: model
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(model.text("detail.tab.timeline"))
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(TimelineFilter.allCases) { filter in
                let count = count(for: filter)
                let isSelected = selectedFilter == filter

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filterIcon(filter))
                            .font(.system(size: 11, weight: .bold))

                        Text(filterTitle(filter))
                            .font(.caption.weight(.medium))

                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                (isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15)),
                                in: Capsule()
                            )
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? filterColor(filter) : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? filterColor(filter).opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func count(for filter: TimelineFilter) -> Int {
        switch filter {
        case .all:
            return model.timelineEvents.count
        case .pathChanges:
            return model.timelineEvents.filter { $0.kind == .pathChanged }.count
        case .checks:
            return model.timelineEvents.filter { $0.kind == .checkStarted || $0.kind == .checkFinished }.count
        case .exports:
            return model.timelineEvents.filter { $0.kind == .exportCreated || $0.kind == .diagnostic }.count
        }
    }

    private func filterTitle(_ filter: TimelineFilter) -> String {
        switch filter {
        case .all: return model.text("timeline.filter.all")
        case .pathChanges: return model.text("timeline.filter.pathChanges")
        case .checks: return model.text("timeline.filter.checks")
        case .exports: return model.text("timeline.filter.exports")
        }
    }

    private func filterIcon(_ filter: TimelineFilter) -> String {
        switch filter {
        case .all: return "tray.full.fill"
        case .pathChanges: return "arrow.triangle.swap"
        case .checks: return "stethoscope"
        case .exports: return "square.and.arrow.up.fill"
        }
    }

    private func filterColor(_ filter: TimelineFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .pathChanges: return .orange
        case .checks: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .exports: return .purple
        }
    }
}

// MARK: - 垂直发光时间轨道节点与事件卡片
struct TimelineRailwayItem: View {
    let event: TimelineEvent
    let isLast: Bool
    @ObservedObject var model: AppModel

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 左侧：时空节点光圈 (Glowing Pip) + 垂直轨道 (Connecting Rail)
            VStack(spacing: 0) {
                // 节点发光圆环
                ZStack {
                    Circle()
                        .fill(nodeColor.opacity(0.18))
                        .frame(width: 30, height: 30)

                    Circle()
                        .stroke(nodeColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 30, height: 30)

                    Image(systemName: symbolName(for: event.kind))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(nodeColor)
                }
                .shadow(color: nodeColor.opacity(0.5), radius: 4)

                // 垂直连线导轨
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [nodeColor.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .frame(minHeight: 36)
                }
            }
            .frame(width: 30)

            // 右侧：时空胶囊卡片 (Event Capsule Card)
            VStack(alignment: .leading, spacing: 8) {
                // 卡片头部：分类徽标 + 相对时间 + 绝对时间戳
                HStack(alignment: .center, spacing: 8) {
                    Text(model.text(for: event.kind))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(nodeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(nodeColor.opacity(0.12), in: Capsule())

                    Text(relativeTimeString(for: event.timestamp))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(event.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                // 核心事件描述
                if !event.message.isEmpty {
                    Text(event.message)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }

                // 结构化黑匣子解密详情 (Arguments Inspection)
                if !event.arguments.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(event.arguments.enumerated()), id: \.offset) { _, arg in
                            Text(arg)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isHovered ? nodeColor.opacity(0.35) : Color.white.opacity(0.08),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onHover { isHovered = $0 }
            .padding(.bottom, isLast ? 0 : 10)
        }
    }

    private var nodeColor: Color {
        switch event.kind {
        case .pathChanged: return .orange
        case .checkStarted: return .blue
        case .checkFinished: return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .exportCreated: return .purple
        case .diagnostic: return .cyan
        }
    }

    private func symbolName(for kind: TimelineEventKind) -> String {
        switch kind {
        case .pathChanged: return "arrow.triangle.swap"
        case .checkStarted: return "play.fill"
        case .checkFinished: return "checkmark"
        case .exportCreated: return "square.and.arrow.up"
        case .diagnostic: return "stethoscope"
        }
    }

    private func relativeTimeString(for date: Date) -> String {
        let now = Date()
        let interval = max(0, now.timeIntervalSince(date))

        if interval < 45 {
            return model.text("time.justNow")
        } else if interval < 3600 {
            let mins = max(1, Int(interval / 60))
            return model.text("time.minutesAgo", mins)
        } else if Calendar.current.isDateInToday(date) {
            let hours = Int(interval / 3600)
            return model.text("time.hoursAgo", hours)
        } else if Calendar.current.isDateInYesterday(date) {
            return model.text("time.yesterday") + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}