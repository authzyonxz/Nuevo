import SwiftUI

/// Fundo decorativo animado. A camada não captura toques e fica atrás do conteúdo.
struct SpiderWebBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let purple = Color(red: 0.66, green: 0.18, blue: 1.0)
                let brightPurple = Color(red: 0.86, green: 0.48, blue: 1.0)
                let anchors = [
                    CGPoint(x: size.width * 0.02, y: size.height * 0.06),
                    CGPoint(x: size.width * 0.98, y: size.height * 0.13),
                    CGPoint(x: size.width * 0.04, y: size.height * 0.91),
                    CGPoint(x: size.width * 0.96, y: size.height * 0.84)
                ]

                for (index, anchor) in anchors.enumerated() {
                    let phase = time * 0.42 + Double(index) * 1.37
                    let drift = CGFloat(sin(phase) * 10.0)
                    let center = CGPoint(x: anchor.x + drift, y: anchor.y + CGFloat(cos(phase * 0.8) * 8.0))
                    let rotation = phase * 0.11
                    let radius = min(size.width, size.height) * 0.49
                    let pulse = 0.70 + 0.30 * ((sin(phase * 1.6) + 1.0) / 2.0)

                    drawWeb(
                        in: &context,
                        center: center,
                        radius: radius,
                        rotation: rotation,
                        opacity: 0.27 * pulse,
                        lineWidth: 1.05,
                        purple: purple
                    )

                    drawMovingBeads(
                        in: &context,
                        center: center,
                        radius: radius,
                        rotation: rotation,
                        phase: phase,
                        opacity: 0.92,
                        color: brightPurple
                    )
                }

                let glowPulse = 0.18 + 0.10 * ((sin(time * 1.2) + 1.0) / 2.0)
                drawCenterGlow(in: &context, size: size, color: purple, opacity: glowPulse)
            }
            .drawingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawWeb(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        rotation: Double,
        opacity: Double,
        lineWidth: CGFloat,
        purple: Color
    ) {
        let rays = 14
        let rings = 6
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        for ray in 0..<rays {
            let angle = rotation + (Double(ray) / Double(rays)) * .pi * 2.0
            let end = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            var path = Path()
            path.move(to: center)
            path.addLine(to: end)
            context.stroke(path, with: .color(purple.opacity(opacity)), style: stroke)
        }

        for ring in 1...rings {
            let ringRadius = radius * CGFloat(ring) / CGFloat(rings + 1)
            var path = Path()
            for ray in 0..<rays {
                let angle = rotation + (Double(ray) / Double(rays)) * .pi * 2.0
                let point = CGPoint(x: center.x + cos(angle) * ringRadius, y: center.y + sin(angle) * ringRadius)
                if ray == 0 {
                    path.move(to: point)
                } else {
                    let previousAngle = rotation + (Double(ray - 1) / Double(rays)) * .pi * 2.0
                    let previous = CGPoint(x: center.x + cos(previousAngle) * ringRadius, y: center.y + sin(previousAngle) * ringRadius)
                    let control = CGPoint(x: (previous.x + point.x) / 2.0, y: (previous.y + point.y) / 2.0)
                    path.addQuadCurve(to: point, control: control)
                }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(purple.opacity(opacity * 0.88)), style: stroke)
        }
    }

    private func drawMovingBeads(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        rotation: Double,
        phase: Double,
        opacity: Double,
        color: Color
    ) {
        let beads = 9
        for index in 0..<beads {
            let progress = (phase * 0.12 + Double(index) / Double(beads)).truncatingRemainder(dividingBy: 1.0)
            let angle = rotation + progress * .pi * 2.0
            let beadRadius = radius * (0.30 + 0.055 * CGFloat(index % 3))
            let point = CGPoint(x: center.x + cos(angle) * beadRadius, y: center.y + sin(angle) * beadRadius)
            let size = CGFloat(2.8 + 1.2 * ((sin(phase + Double(index)) + 1.0) / 2.0))
            let rect = CGRect(x: point.x - size / 2.0, y: point.y - size / 2.0, width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
        }

        let centerSize = CGFloat(5.0 + 2.0 * ((sin(phase * 1.4) + 1.0) / 2.0))
        let centerRect = CGRect(x: center.x - centerSize / 2.0, y: center.y - centerSize / 2.0, width: centerSize, height: centerSize)
        context.fill(Path(ellipseIn: centerRect), with: .color(color.opacity(opacity * 0.95)))
    }

    private func drawCenterGlow(in context: inout GraphicsContext, size: CGSize, color: Color, opacity: Double) {
        let center = CGPoint(x: size.width / 2.0, y: size.height * 0.47)
        let glowRadius = min(size.width, size.height) * 0.32
        let rect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2.0, height: glowRadius * 2.0)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0.0)]),
            center: center,
            startRadius: 0,
            endRadius: glowRadius
        ))
    }
}
