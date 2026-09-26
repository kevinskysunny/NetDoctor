import NetworkCore
import SwiftUI

/// 赛博心电波形组件：纯 SwiftUI Canvas + TimelineView 实时自绘，展现网络生命体征
struct ECGWaveformView: View {
    let grade: HealthGrade
    let isChecking: Bool
    let latestRTT: Double?
    var height: CGFloat = 64

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawWaveform(in: &context, size: size, time: time)
            }
        }
        .frame(height: height)
        .clipped()
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(waveColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var waveColor: Color {
        if isChecking {
            return Color.cyan
        }
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

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let width = size.width
        let height = size.height
        let midY = height * 0.5

        // 背景网格线（极客心电监护仪暗网格）
        var gridPath = Path()
        let step: CGFloat = 16
        var x: CGFloat = 0
        while x <= width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: height))
            x += step
        }
        var y: CGFloat = 0
        while y <= height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: width, y: y))
            y += step
        }
        context.stroke(gridPath, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)

        // 决定心电波形速度与频率
        let speed: CGFloat = isChecking ? 140 : (grade == .critical ? 20 : 80)
        let phase = CGFloat(time * Double(speed))

        var wavePath = Path()
        var points: [CGPoint] = []

        let sampleStep: CGFloat = 2
        var currentX: CGFloat = 0
        while currentX <= width {
            let sampleX = currentX + phase
            let waveVal = calculateWaveHeight(at: sampleX, midY: midY, height: height)
            let pt = CGPoint(x: currentX, y: waveVal)
            points.append(pt)
            currentX += sampleStep
        }

        guard let first = points.first else { return }
        wavePath.move(to: first)
        for pt in points.dropFirst() {
            wavePath.addLine(to: pt)
        }

        // 发光辉光底层
        context.stroke(
            wavePath,
            with: .color(waveColor.opacity(0.35)),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        // 核心高亮线条
        context.stroke(
            wavePath,
            with: .color(waveColor),
            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        )

        // 心电探测领先光点（Leading pulse dot）
        if let lastPoint = points.last {
            let dotRect = CGRect(x: lastPoint.x - 3.5, y: lastPoint.y - 3.5, width: 7, height: 7)
            context.fill(Path(ellipseIn: dotRect), with: .color(Color.white))
            let haloRect = CGRect(x: lastPoint.x - 7, y: lastPoint.y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: haloRect), with: .color(waveColor.opacity(0.4)))
        }
    }

    private func calculateWaveHeight(at x: CGFloat, midY: CGFloat, height: CGFloat) -> CGFloat {
        // 心跳周期宽度
        let cycle: CGFloat = isChecking ? 120 : (grade == .critical ? 300 : 200)
        let normalized = (x.truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle)

        if grade == .critical && !isChecking {
            // 心跳停顿（Flatline），伴随极其微弱的基线颤动
            let microNoise = sin(x * 0.08) * 1.2
            return midY + microNoise
        }

        let ampScale: CGFloat = isChecking ? 1.2 : (grade == .warning ? 0.9 : 1.0)
        let maxAmp = height * 0.38 * ampScale

        // 标准心电复合波形 (P - Q - R - S - T)
        var dy: CGFloat = 0

        if normalized < 25 {
            // 基线平稳
            dy = 0
        } else if normalized < 45 {
            // P 波（心房去极化，平缓小波峰）
            let pProgress = (normalized - 25) / 20
            dy = sin(pProgress * .pi) * (maxAmp * 0.18)
        } else if normalized < 55 {
            // PR 间期平线
            dy = 0
        } else if normalized < 60 {
            // Q 谷（微探底）
            let qProgress = (normalized - 55) / 5
            dy = -sin(qProgress * .pi) * (maxAmp * 0.15)
        } else if normalized < 72 {
            // R 锐峰（心室去极化，高频陡峭大波峰）
            let rProgress = (normalized - 60) / 12
            dy = sin(rProgress * .pi) * maxAmp
        } else if normalized < 80 {
            // S 谷（快速深下探）
            let sProgress = (normalized - 72) / 8
            dy = -sin(sProgress * .pi) * (maxAmp * 0.35)
        } else if normalized < 105 {
            // ST 段平线
            dy = 0
        } else if normalized < 140 {
            // T 波（心室复极化，圆润平滑波峰）
            let tProgress = (normalized - 105) / 35
            dy = sin(tProgress * .pi) * (maxAmp * 0.28)
        } else {
            // TP 间期平静基线
            dy = 0
        }

        // 若处于警告状态，叠加轻微抖动/毛刺（Jitter）
        if grade == .warning {
            let jitter = sin(x * 0.4) * 2.2 + cos(x * 0.9) * 1.5
            dy += jitter
        } else if isChecking {
            // 体检扫描时伴随脉冲扫描调制
            let scanMod = sin(x * 0.15) * 3.0
            dy += scanMod
        }

        return midY - dy
    }
}
