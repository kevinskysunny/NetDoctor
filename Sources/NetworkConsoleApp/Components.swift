import NetworkCore
import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let systemImage {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

/// 现代化 Bento Box 风格指标卡片，支持微光边框与 Hover 悬浮交互
struct MetricCard: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    var accentColor: Color? = nil

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let accentColor {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                }
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isHovered ? (accentColor ?? Color.white).opacity(0.45) : Color.white.opacity(0.09),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct HealthBadge: View {
    let grade: HealthGrade
    let title: String

    var body: some View {
        Label(title, systemImage: grade.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    private var color: Color {
        switch grade {
        case .checking:
            return .secondary
        case .healthy:
            return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

/// 声呐水波纹动效组件：仅在体检中或激活时渲染，闲置时彻底释放动画开销
struct SonarWaveEffect: View {
    let isActive: Bool
    var tintColor: Color = .cyan

    @State private var wave1 = false
    @State private var wave2 = false

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(tintColor.opacity(wave1 ? 0.0 : 0.6), lineWidth: 2)
                    .scaleEffect(wave1 ? 2.2 : 0.9)
                    .opacity(wave1 ? 0.0 : 0.8)

                Circle()
                    .stroke(tintColor.opacity(wave2 ? 0.0 : 0.4), lineWidth: 1.5)
                    .scaleEffect(wave2 ? 2.6 : 0.9)
                    .opacity(wave2 ? 0.0 : 0.6)
            }
        }
        .onAppear {
            if isActive { triggerWaves() }
        }
        .onChange(of: isActive) { _, active in
            if active {
                triggerWaves()
            } else {
                wave1 = false
                wave2 = false
            }
        }
    }

    private func triggerWaves() {
        guard isActive else { return }
        wave1 = false
        wave2 = false
        withAnimation(.easeOut(duration: 1.2).repeatCount(2, autoreverses: false)) {
            wave1 = true
        }
        withAnimation(.easeOut(duration: 1.2).repeatCount(2, autoreverses: false).delay(0.3)) {
            wave2 = true
        }
    }
}
