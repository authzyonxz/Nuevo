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
            ParticleNetworkBackground(animate: !reduceMotion)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                tabNavigation
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.025))
        .preferredColorScheme(.dark)
    }

    private var tabNavigation: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: tab == .cpp ? 18 : 20, weight: selectedTab == tab ? .medium : .regular))
                            .symbolRenderingMode(.hierarchical)
                            .frame(height: 23)
                        Text(tab.title.uppercased())
                            .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                            .tracking(1.35)
                        Capsule()
                            .fill(Color.white.opacity(selectedTab == tab ? 0.78 : 0))
                            .frame(width: selectedTab == tab ? 13 : 3, height: 1.5)
                            .padding(.top, 1)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.44))
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
    }
}

private struct ParticleNetworkBackground: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            if animate {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    draw(size: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                draw(size: proxy.size, time: 0)
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.025))
        .accessibilityHidden(true)
    }

    private func draw(size: CGSize, time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            let nodes = Self.makeNodes(for: canvasSize)
            let positions = nodes.map { Self.reflectedPosition(of: $0, in: canvasSize, time: time) }
            let connectionDistance: CGFloat = 150

            for first in positions.indices {
                for second in positions.indices where second > first {
                    let dx = positions[first].x - positions[second].x
                    let dy = positions[first].y - positions[second].y
                    let distance = hypot(dx, dy)
                    guard distance < connectionDistance else { continue }

                    let opacity = (1 - Double(distance / connectionDistance)) * 0.45
                    var link = Path()
                    link.move(to: positions[first])
                    link.addLine(to: positions[second])
                    context.stroke(link, with: .color(.white.opacity(opacity)), lineWidth: 0.8)
                }
            }

            for position in positions {
                let diameter: CGFloat = 3.2
                let point = CGRect(
                    x: position.x - diameter / 2,
                    y: position.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: point), with: .color(.white.opacity(0.82)))
            }
        }
    }

    private static func makeNodes(for size: CGSize) -> [ParticleNode] {
        let count = min(110, max(1, Int((size.width * size.height) / 17_000)))
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        var random = StableRandom(seed: UInt64(width) &* 73_856_093 ^ UInt64(height) &* 19_349_663)

        return (0..<count).map { _ in
            ParticleNode(
                origin: CGPoint(x: random.nextUnit() * size.width, y: random.nextUnit() * size.height),
                velocity: CGPoint(
                    x: (random.nextUnit() - 0.5) * 13.5,
                    y: (random.nextUnit() - 0.5) * 13.5
                )
            )
        }
    }

    private static func reflectedPosition(of node: ParticleNode, in size: CGSize, time: TimeInterval) -> CGPoint {
        let elapsed = CGFloat(time)
        return CGPoint(
            x: reflected(node.origin.x + node.velocity.x * elapsed, limit: size.width),
            y: reflected(node.origin.y + node.velocity.y * elapsed, limit: size.height)
        )
    }

    private static func reflected(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0 else { return 0 }
        let period = Double(limit) * 2
        var position = Double(value).truncatingRemainder(dividingBy: period)
        if position < 0 { position += period }
        return CGFloat(position <= Double(limit) ? position : period - position)
    }

    private struct ParticleNode {
        let origin: CGPoint
        let velocity: CGPoint
    }

    private struct StableRandom {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        }

        mutating func nextUnit() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(state >> 11) / 9_007_199_254_740_992.0
            return CGFloat(unit)
        }
    }
}
