import NetworkCore
import SwiftUI

/// 0~100 环形发光健康评分仪表盘组件
struct HealthScoreGaugeView: View {
    let score: Int
    let grade: HealthGrade
    let verdict: String
    var size: CGFloat = 130
    var lineWidth: CGFloat = 10
    var showVerdict: Bool = true

    @State private var animatedScore: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 背景空槽圆环
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

                // 发光渐变进度环
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, animatedScore / 100.0))))
                    .stroke(
                        gaugeGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: size > 60 ? themeColor.opacity(0.3) : .clear, radius: size > 60 ? 4 : 0, x: 0, y: 0)

                // 中间得分与等级
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(Int(animatedScore.rounded()))")
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("分")
                            .font(.system(size: size * 0.12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: grade.symbolName)
                            .font(.system(size: size * 0.09, weight: .bold))
                        Text(grade.displayName)
                            .font(.system(size: size * 0.1, weight: .semibold))
                    }
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeColor.opacity(0.12), in: Capsule())
                }
            }
            .frame(width: size, height: size)

            if showVerdict && !verdict.isEmpty {
                Text(verdict)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(themeColor.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .onAppear {
            animatedScore = 0
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
                animatedScore = Double(score)
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedScore = Double(newScore)
            }
        }
    }

    private var themeColor: Color {
        switch grade {
        case .healthy:
            return Color(red: 0.2, green: 0.88, blue: 0.5)
        case .warning:
            return Color.orange
        case .critical:
            return Color.red
        case .checking:
            return Color.cyan
        }
    }

    private var gaugeGradient: AngularGradient {
        switch grade {
        case .healthy:
            return AngularGradient(
                colors: [Color(red: 0.3, green: 0.75, blue: 0.4), Color(red: 0.2, green: 0.95, blue: 0.55)],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        case .warning:
            return AngularGradient(
                colors: [Color.yellow, Color.orange],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        case .critical:
            return AngularGradient(
                colors: [Color.orange, Color.red],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        case .checking:
            return AngularGradient(
                colors: [Color.blue, Color.cyan],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }
    }
}
