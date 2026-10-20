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
        case .profile: return "person.crop.circle.fill"
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

                // Intentionally empty: each section will be built in a later step.
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)

                bottomBar
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 7) {
                        tabIcon(tab)
                            .frame(height: 25)
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                            .tracking(0.35)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 5)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: MainTab) -> some View {
        if tab == .cpp {
            Text("C++")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(-0.8)
                .frame(width: 34, height: 25)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(selectedTab == tab ? 0.9 : 0.42), lineWidth: 1.2)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(selectedTab == tab ? 0.12 : 0.035))
                        )
                }
        } else {
            Image(systemName: tab.symbol)
                .font(.system(size: 20, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 25)
        }
    }
}

private struct SpiderWebBackground: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            if animate {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
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
            let points = webPoints(in: canvasSize, time: time)
            let spacing: CGFloat = 104
            let columns = max(1, Int(canvasSize.width / spacing))
            let rows = max(1, Int(canvasSize.height / spacing))

            // Fine mesh: short links keep the pattern organic rather than grid-like.
            for first in points.indices {
                for second in points.indices where second > first {
                    let distance = hypot(points[first].x - points[second].x, points[first].y - points[second].y)
                    guard distance < spacing * 1.48 else { continue }
                    var strand = Path()
                    strand.move(to: points[first])
                    strand.addLine(to: points[second])
                    let shimmer = 0.34 + 0.20 * sin(time * 0.55 + Double(first + second) * 0.21)
                    context.stroke(strand, with: .color(.white.opacity(shimmer)), lineWidth: 0.55)
                }
            }

            // A few brighter anchor points give the web depth and a subtle premium shimmer.
            for index in points.indices where index % max(1, columns / 3) == 0 {
                let point = points[index]
                let pulse = 1.2 + 0.7 * (0.5 + 0.5 * sin(time * 0.8 + Double(index)))
                let glowRect = CGRect(x: point.x - pulse, y: point.y - pulse, width: pulse * 2, height: pulse * 2)
                context.fill(Path(ellipseIn: glowRect), with: .color(.white.opacity(0.62)))
            }

            // Sparse radial arcs suggest classic spider silk without cluttering the screen.
            let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.46)
            let radius = min(canvasSize.width, canvasSize.height) * 0.42
            for ring in 1...5 {
                let ringRadius = radius * CGFloat(ring) / 5
                var arc = Path()
                arc.addEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
                context.stroke(arc, with: .color(.white.opacity(0.055)), lineWidth: 0.7)
            }

            // A soft vignette maintains a clean, nearly-black center for future content.
            let vignette = Gradient(colors: [.black.opacity(0.12), .black.opacity(0.5), .black.opacity(0.18)])
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .linearGradient(vignette, startPoint: .zero, endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height))
            )
            _ = rows
        }
    }

    private func webPoints(in size: CGSize, time: TimeInterval) -> [CGPoint] {
        let spacing: CGFloat = 104
        let columns = max(2, Int(ceil(size.width / spacing)) + 1)
        let rows = max(3, Int(ceil(size.height / spacing)) + 1)
        var points: [CGPoint] = []
        points.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let seed = Double(row * 37 + column * 19)
                let x = CGFloat(column) * spacing + CGFloat(sin(time * 0.32 + seed) * 9)
                let y = CGFloat(row) * spacing + CGFloat(cos(time * 0.27 + seed * 0.7) * 9)
                points.append(CGPoint(x: x, y: y))
            }
        }
        return points
    }
}
