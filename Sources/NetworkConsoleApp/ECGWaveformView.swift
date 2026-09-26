import NetworkCore
import SwiftUI

/// 赛博心电波形组件：体检中动态脉冲流转，稳态下零 CPU 功耗
struct ECGWaveformView: View {
    let grade: HealthGrade
    let isChecking: Bool
    let latestRTT: Double?
    var height: CGFloat = 52

    @State private var scanPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // 静态暗网格背景
            StaticECGGrid(step: 16)

            if isChecking {
                // 仅在体检探测期间运行轻量级 15fps 扫描动效（通常持续 1~2 秒）
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        drawDynamicWave(in: &context, size: size, time: time)
                    }
                }
            } else {
                // 稳态下纯静态绘制一条精致抗锯齿心电波形，完全零 CPU/GPU 循环开销
                Canvas { context, size in
                    drawStaticWave(in: &context, size: size)
                }
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

    // MARK: - 静态高质量心电波形（稳态零开销）
    private func drawStaticWave(in context: inout GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return }
        let midY = height * 0.5

        var path = Path()
        let step: CGFloat = 2.5
        var x: CGFloat = 0

        while x <= width {
            let y = calculateWaveHeight(at: x + 40, midY: midY, height: height, isChecking: false)
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        // 发光辉光底层
        context.stroke(
            path,
            with: .color(waveColor.opacity(0.3)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
        // 核心线条
        context.stroke(
            path,
            with: .color(waveColor),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - 动态扫描心电波形（仅体检期间运行）
    private func drawDynamicWave(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return }
        let midY = height * 0.5

        let phase = CGFloat(time * 100.0)
        var path = Path()
        let step: CGFloat = 3.0
        var x: CGFloat = 0
        var lastPt = CGPoint.zero

        while x <= width {
            let y = calculateWaveHeight(at: x + phase, midY: midY, height: height, isChecking: true)
            let pt = CGPoint(x: x, y: y)
            if x == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
            lastPt = pt
            x += step
        }

        context.stroke(
            path,
            with: .color(waveColor.opacity(0.35)),
            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(waveColor),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        )

        if lastPt != .zero {
            let dotRect = CGRect(x: lastPt.x - 3, y: lastPt.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dotRect), with: .color(Color.white))
        }
    }

    private func calculateWaveHeight(at x: CGFloat, midY: CGFloat, height: CGFloat, isChecking: Bool) -> CGFloat {
        let cycle: CGFloat = isChecking ? 110 : (grade == .critical ? 300 : 160)
        let normalized = (x.truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle)

        if grade == .critical && !isChecking {
            let microNoise = sin(x * 0.08) * 0.8
            return midY + microNoise
        }

        let maxAmp = height * 0.38
        var dy: CGFloat = 0

        if normalized < 20 {
            dy = 0
        } else if normalized < 36 {
            let pProgress = (normalized - 20) / 16
            dy = sin(pProgress * .pi) * (maxAmp * 0.18)
        } else if normalized < 45 {
            dy = 0
        } else if normalized < 50 {
            let qProgress = (normalized - 45) / 5
            dy = -sin(qProgress * .pi) * (maxAmp * 0.15)
        } else if normalized < 62 {
            let rProgress = (normalized - 50) / 12
            dy = sin(rProgress * .pi) * maxAmp
        } else if normalized < 70 {
            let sProgress = (normalized - 62) / 8
            dy = -sin(sProgress * .pi) * (maxAmp * 0.35)
        } else if normalized < 90 {
            dy = 0
        } else if normalized < 120 {
            let tProgress = (normalized - 90) / 30
            dy = sin(tProgress * .pi) * (maxAmp * 0.28)
        } else {
            dy = 0
        }

        if grade == .warning {
            let jitter = sin(x * 0.4) * 1.8 + cos(x * 0.9) * 1.0
            dy += jitter
        } else if isChecking {
            let scanMod = sin(x * 0.15) * 2.0
            dy += scanMod
        }

        return midY - dy
    }
}

/// 静态暗网格背景：完全脱离重绘循环
private struct StaticECGGrid: View {
    let step: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
        }
    }
}
