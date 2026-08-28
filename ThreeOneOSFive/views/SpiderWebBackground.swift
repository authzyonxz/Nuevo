import SwiftUI

/// Fundo decorativo de partículas alongadas. Não captura toques e fica atrás do conteúdo.
struct SpiderWebBackground: View {
    private struct Particle {
        let x: CGFloat
        let y: CGFloat
        let length: CGFloat
        let thickness: CGFloat
        let angle: Double
        let speed: Double
        let phase: Double
        let brightness: Double
    }

    private let particles: [Particle] = [
        Particle(x: 0.10, y: 0.13, length: 22, thickness: 3.0, angle: -0.30, speed: 0.55, phase: 0.4, brightness: 0.78),
        Particle(x: 0.25, y: 0.08, length: 14, thickness: 2.6, angle: 0.16, speed: 0.38, phase: 1.8, brightness: 0.55),
        Particle(x: 0.44, y: 0.18, length: 20, thickness: 3.2, angle: -0.18, speed: 0.48, phase: 2.7, brightness: 0.64),
        Particle(x: 0.70, y: 0.11, length: 17, thickness: 2.8, angle: 0.28, speed: 0.60, phase: 3.5, brightness: 0.72),
        Particle(x: 0.90, y: 0.20, length: 25, thickness: 3.2, angle: -0.42, speed: 0.42, phase: 4.1, brightness: 0.58),
        Particle(x: 0.06, y: 0.34, length: 16, thickness: 2.7, angle: 0.30, speed: 0.44, phase: 5.0, brightness: 0.60),
        Particle(x: 0.19, y: 0.44, length: 24, thickness: 3.4, angle: -0.12, speed: 0.52, phase: 0.9, brightness: 0.70),
        Particle(x: 0.82, y: 0.39, length: 18, thickness: 2.8, angle: 0.20, speed: 0.50, phase: 2.1, brightness: 0.62),
        Particle(x: 0.95, y: 0.51, length: 23, thickness: 3.0, angle: -0.26, speed: 0.36, phase: 3.0, brightness: 0.54),
        Particle(x: 0.12, y: 0.68, length: 19, thickness: 3.1, angle: 0.22, speed: 0.58, phase: 4.4, brightness: 0.66),
        Particle(x: 0.31, y: 0.82, length: 26, thickness: 3.3, angle: -0.34, speed: 0.46, phase: 5.2, brightness: 0.76),
        Particle(x: 0.55, y: 0.72, length: 15, thickness: 2.6, angle: 0.12, speed: 0.40, phase: 1.1, brightness: 0.55),
        Particle(x: 0.75, y: 0.86, length: 22, thickness: 3.2, angle: -0.20, speed: 0.53, phase: 2.8, brightness: 0.68),
        Particle(x: 0.93, y: 0.76, length: 16, thickness: 2.7, angle: 0.35, speed: 0.45, phase: 4.9, brightness: 0.60),
        Particle(x: 0.42, y: 0.50, length: 12, thickness: 2.5, angle: -0.40, speed: 0.33, phase: 3.8, brightness: 0.46),
        Particle(x: 0.61, y: 0.35, length: 13, thickness: 2.5, angle: 0.42, speed: 0.57, phase: 0.2, brightness: 0.50)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let purple = Color(red: 0.66, green: 0.18, blue: 1.0)
                let softPurple = Color(red: 0.82, green: 0.44, blue: 1.0)

                for particle in particles {
                    drawParticle(
                        in: &context,
                        particle: particle,
                        size: size,
                        time: time,
                        color: particle.brightness > 0.68 ? softPurple : purple
                    )
                }

                let glowPulse = 0.10 + 0.06 * ((sin(time * 0.85) + 1.0) / 2.0)
                let center = CGPoint(x: size.width / 2.0, y: size.height * 0.48)
                let glowRadius = min(size.width, size.height) * 0.34
                let glowRect = CGRect(
                    x: center.x - glowRadius,
                    y: center.y - glowRadius,
                    width: glowRadius * 2.0,
                    height: glowRadius * 2.0
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [purple.opacity(glowPulse), purple.opacity(0.0)]),
                        center: center,
                        startRadius: 0,
                        endRadius: glowRadius
                    )
                )
            }
            .drawingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticle(
        in context: inout GraphicsContext,
        particle: Particle,
        size: CGSize,
        time: TimeInterval,
        color: Color
    ) {
        let phase = time * particle.speed + particle.phase
        let breathing = 0.72 + 0.28 * ((sin(phase * 1.35) + 1.0) / 2.0)
        let stretch = 0.72 + 0.42 * ((sin(phase * 0.92 + 1.1) + 1.0) / 2.0)
        let driftX = CGFloat(sin(phase * 0.72) * 12.0)
        let driftY = CGFloat(cos(phase * 0.58) * 10.0)
        let center = CGPoint(
            x: size.width * particle.x + driftX,
            y: size.height * particle.y + driftY
        )
        let length = particle.length * stretch
        let thickness = particle.thickness * (0.85 + 0.20 * breathing)
        let halfLength = length / 2.0
        let direction = CGVector(dx: cos(particle.angle), dy: sin(particle.angle))
        let start = CGPoint(
            x: center.x - direction.dx * halfLength,
            y: center.y - direction.dy * halfLength
        )
        let end = CGPoint(
            x: center.x + direction.dx * halfLength,
            y: center.y + direction.dy * halfLength
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
            path,
            with: .color(color.opacity((0.20 + particle.brightness * 0.34) * breathing)),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round)
        )

        let dotSize = max(2.0, thickness * 0.80)
        let dotRect = CGRect(
            x: center.x - dotSize / 2.0,
            y: center.y - dotSize / 2.0,
            width: dotSize,
            height: dotSize
        )
        context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.48 * breathing)))
    }
}
