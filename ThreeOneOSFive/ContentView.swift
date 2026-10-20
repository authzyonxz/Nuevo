import SwiftUI
import UIKit

private enum MainTab: Int, CaseIterable, Identifiable {
    case aim
    case cpp
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .aim: return "Aim"
        case .cpp: return "C++"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .aim: return "scope"
        case .cpp: return "chevron.left.forwardslash.chevron.right"
        case .profile: return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: MainTab = .aim

    var body: some View {
        ZStack {
            SpiderWebBackground(animate: !reduceMotion)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                tabNavigation
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var tabNavigation: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        tabIcon(tab)
                            .frame(height: 23)
                        Text(tab.title.uppercased())
                            .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                            .tracking(1.35)
                        Capsule()
                            .fill(Color.white.opacity(selectedTab == tab ? 0.8 : 0))
                            .frame(width: selectedTab == tab ? 13 : 3, height: 1.5)
                            .padding(.top, 1)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 3)
        .background(Color.black.opacity(0.18))
    }

    private func tabIcon(_ tab: MainTab) -> some View {
        Image(systemName: tab.symbol)
            .font(.system(size: tab == .cpp ? 18 : 19, weight: selectedTab == tab ? .medium : .regular))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 28, height: 23)
    }
}

private struct SpiderWebBackground: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            if animate {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
                    webCanvas(size: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                webCanvas(size: proxy.size, time: 0)
            }
        }
        .background(Color.black)
        .accessibilityHidden(true)
    }

    private func webCanvas(size: CGSize, time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            let clusters: [(x: CGFloat, y: CGFloat, radius: CGFloat, spokes: Int, opacity: Double)] = [
                (0.14, 0.20, 76, 10, 0.17),
                (0.82, 0.27, 57, 9, 0.13),
                (0.29, 0.61, 50, 9, 0.105),
                (0.76, 0.78, 81, 11, 0.145),
                (0.52, 0.40, 39, 8, 0.075)
            ]

            for (index, cluster) in clusters.enumerated() {
                drawWeb(
                    in: &context,
                    size: canvasSize,
                    centerX: cluster.x,
                    centerY: cluster.y,
                    radius: cluster.radius,
                    spokeCount: cluster.spokes,
                    opacity: cluster.opacity,
                    seed: index,
                    time: time
                )
            }

            drawDriftingParticles(in: &context, size: canvasSize, time: time)

            let vignette = Gradient(colors: [
                .black.opacity(0.03),
                .black.opacity(0.31),
                .black.opacity(0.08)
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .linearGradient(
                    vignette,
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                )
            )
        }
    }

    private func drawWeb(
        in context: inout GraphicsContext,
        size: CGSize,
        centerX: CGFloat,
        centerY: CGFloat,
        radius: CGFloat,
        spokeCount: Int,
        opacity: Double,
        seed: Int,
        time: TimeInterval
    ) {
        let drift = time * 0.075
        let center = CGPoint(
            x: size.width * centerX + CGFloat(sin(drift + Double(seed) * 2.1)) * 4.2,
            y: size.height * centerY + CGFloat(cos(drift * 0.83 + Double(seed) * 1.7)) * 4.2
        )
        let phase = drift * 0.42 + Double(seed) * 0.63
        let ringCount = 6
        var intersections: [[CGPoint]] = Array(repeating: [], count: ringCount)

        for spoke in 0..<spokeCount {
            let angle = (Double(spoke) / Double(spokeCount)) * .pi * 2
                + 0.035 * sin(phase + Double(spoke) * 0.7)
            let outerVariation = 0.89 + 0.09 * sin(Double(spoke) * 1.8 + phase)
            let edgeRadius = radius * outerVariation
            let edge = CGPoint(
                x: center.x + CGFloat(cos(angle)) * edgeRadius,
                y: center.y + CGFloat(sin(angle)) * edgeRadius
            )

            var strand = Path()
            strand.move(to: center)
            strand.addLine(to: edge)
            context.stroke(
                strand,
                with: .color(.white.opacity(opacity * (0.76 + 0.12 * sin(phase + Double(spoke))))),
                lineWidth: 0.62
            )

            for ring in 0..<ringCount {
                let fraction = CGFloat(ring + 1) / CGFloat(ringCount)
                let ripple = 1 + 0.035 * CGFloat(sin(phase + Double(spoke) * 0.9 + Double(ring) * 0.6))
                let distance = edgeRadius * fraction * ripple
                intersections[ring].append(CGPoint(
                    x: center.x + CGFloat(cos(angle)) * distance,
                    y: center.y + CGFloat(sin(angle)) * distance
                ))
            }
        }

        for ring in 0..<ringCount {
            let nodes = intersections[ring]
            guard nodes.count > 1 else { continue }
            var silk = Path()
            silk.move(to: nodes[0])
            for node in nodes.dropFirst() { silk.addLine(to: node) }
            silk.closeSubpath()
            context.stroke(
                silk,
                with: .color(.white.opacity(opacity * (0.54 - Double(ring) * 0.025))),
                lineWidth: ring == ringCount - 1 ? 0.48 : 0.58
            )

            for (nodeIndex, node) in nodes.enumerated() where (nodeIndex + ring + seed) % 2 == 0 {
                let dotSize: CGFloat = ring == ringCount - 1 ? 1.8 : 1.35
                let dot = CGRect(x: node.x - dotSize / 2, y: node.y - dotSize / 2, width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(opacity * 2.25)))
            }
        }

        let anchorSize: CGFloat = 2.6
        let anchor = CGRect(x: center.x - anchorSize / 2, y: center.y - anchorSize / 2, width: anchorSize, height: anchorSize)
        context.fill(Path(ellipseIn: anchor), with: .color(.white.opacity(opacity * 3.3)))
    }

    private func drawDriftingParticles(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<38 {
            let seed = Double(index)
            let baseX = (seed * 0.61803398875).truncatingRemainder(dividingBy: 1)
            let baseY = (seed * 0.41421356237 + 0.17).truncatingRemainder(dividingBy: 1)
            let speed = 0.0014 + Double(index % 5) * 0.00028
            let xFraction = (baseX + time * speed).truncatingRemainder(dividingBy: 1)
            let yFraction = (baseY + 0.018 * sin(time * 0.09 + seed * 2.4)).truncatingRemainder(dividingBy: 1)
            let x = size.width * CGFloat(xFraction)
            let y = size.height * CGFloat(yFraction)
            let radius = index % 9 == 0 ? 1.45 : 0.75
            let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let shimmer = 0.19 + 0.12 * (0.5 + 0.5 * sin(time * 0.13 + seed))
            context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(shimmer)))
        }
    }
}
