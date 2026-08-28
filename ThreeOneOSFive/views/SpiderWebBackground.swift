import SwiftUI

/// Fundo decorativo de baixo custo: linhas radiais e arcos suaves em roxo.
/// Não intercepta toques e deve permanecer atrás do conteúdo.
struct SpiderWebBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = time.truncatingRemainder(dividingBy: 12.0) / 12.0

            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.06, y: size.height * 0.08),
                    CGPoint(x: size.width * 0.94, y: size.height * 0.16),
                    CGPoint(x: size.width * 0.02, y: size.height * 0.82),
                    CGPoint(x: size.width * 0.98, y: size.height * 0.88)
                ]

                for (index, point) in points.enumerated() {
                    let localPhase = phase + Double(index) * 0.17
                    let pulse = 0.72 + 0.28 * sin(localPhase * .pi * 2.0)
                    let radius = min(size.width, size.height) * (0.42 + 0.025 * sin(localPhase * .pi * 2.0))
                    drawWeb(
                        in: &context,
                        center: point,
                        radius: radius,
                        opacity: 0.16 * pulse,
                        lineWidth: 0.8
                    )
                }
            }
            .drawingGroup()
            .opacity(0.9)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawWeb(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        opacity: Double,
        lineWidth: CGFloat
    ) {
        let rays = 12
        let rings = 5
        let purple = Color(red: 0.62, green: 0.22, blue: 0.95)
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        for ray in 0..<rays {
            let angle = (Double(ray) / Double(rays)) * .pi * 2.0
            let end = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            var path = Path()
            path.move(to: center)
            path.addLine(to: end)
            context.stroke(path, with: .color(purple.opacity(opacity)), style: stroke)
        }

        for ring in 1...rings {
            let ringRadius = radius * CGFloat(ring) / CGFloat(rings + 1)
            var path = Path()
            for ray in 0..<rays {
                let angle = (Double(ray) / Double(rays)) * .pi * 2.0
                let point = CGPoint(
                    x: center.x + cos(angle) * ringRadius,
                    y: center.y + sin(angle) * ringRadius
                )
                if ray == 0 {
                    path.move(to: point)
                } else {
                    let previousAngle = (Double(ray - 1) / Double(rays)) * .pi * 2.0
                    let previous = CGPoint(
                        x: center.x + cos(previousAngle) * ringRadius,
                        y: center.y + sin(previousAngle) * ringRadius
                    )
                    let midpoint = CGPoint(
                        x: (previous.x + point.x) / 2.0,
                        y: (previous.y + point.y) / 2.0
                    )
                    path.addQuadCurve(to: point, control: midpoint)
                }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(purple.opacity(opacity * 0.82)), style: stroke)
        }
    }
}
