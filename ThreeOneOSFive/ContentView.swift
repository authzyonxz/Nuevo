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
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: MainTab = .aim
    @State private var authorizedAccess: KeyAuthAccess?
    @State private var revalidationInFlight = false

    var body: some View {
        ZStack {
            ParticleNetworkBackground(animate: !reduceMotion)
                .ignoresSafeArea()

            if authorizedAccess != nil {
                mainTabs
                    .transition(.opacity)
            } else {
                KeyLoginView { access in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        authorizedAccess = access
                    }
                }
                .transition(.opacity)
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.025))
        .preferredColorScheme(.dark)
        .task(id: authorizedAccess?.grant) {
            guard var currentAccess = authorizedAccess else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 45_000_000_000) } catch { return }
                guard let latestAccess = authorizedAccess,
                      latestAccess.grant == currentAccess.grant else { return }
                await revalidateSilently(latestAccess, clearOnDefinitiveFailure: true)
                guard let refreshed = authorizedAccess, refreshed.grant != latestAccess.grant else { continue }
                currentAccess = refreshed
            }
        }
        .onChange(of: scenePhase) { phase in
            guard let access = authorizedAccess else { return }
            switch phase {
            case .active:
                Task { await revalidateSilently(access, clearOnDefinitiveFailure: true) }
            case .background:
                let taskID = UIApplication.shared.beginBackgroundTask(withName: "KeyAuthRevalidation", expirationHandler: nil)
                Task {
                    await revalidateSilently(access, clearOnDefinitiveFailure: false)
                    if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
                }
            default:
                break
            }
        }
    }

    private func revalidateSilently(_ access: KeyAuthAccess, clearOnDefinitiveFailure: Bool) async {
        guard !revalidationInFlight else { return }
        revalidationInFlight = true
        defer { revalidationInFlight = false }
        do {
            let refreshed = try await KeyAuthClient().revalidate(access)
            guard authorizedAccess?.grant == access.grant else { return }
            authorizedAccess = refreshed
            log("keyauth: silent revalidation succeeded")
        } catch {
            log("keyauth: silent revalidation failed: \(String(describing: error))")
            if clearOnDefinitiveFailure { handleRevalidationFailure(error, using: access) }
        }
    }

    private func handleRevalidationFailure(_ error: Error, using access: KeyAuthAccess) {
        guard authorizedAccess?.grant == access.grant else { return }
        let isTransient: Bool
        if let failure = error as? KeyAuthFailure {
            switch failure {
            case .network:
                isTransient = true
            case .server(let code) where code == "RATE_LIMITED" || code == "DATABASE_UNAVAILABLE":
                isTransient = true
            default:
                isTransient = false
            }
        } else {
            isTransient = false
        }
        guard !isTransient else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            authorizedAccess = nil
        }
    }

    private var mainTabs: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .aim:
                    if let access = authorizedAccess {
                        AimView(access: access, onAccessUpdated: { refreshed in
                            authorizedAccess = refreshed
                        }, functions: AimFunctionCatalog.all.filter { $0.id != "mod-menu" })
                    }
                case .cpp:
                    if let access = authorizedAccess {
                        AimView(
                            access: access,
                            onAccessUpdated: { refreshed in
                            authorizedAccess = refreshed
                            },
                            functions: AimFunctionCatalog.all.filter { $0.id == "mod-menu" },
                            tutorialText: "Ative a função Mod Menu antes de entrar no jogo. Após ativar e entrar no jogo e chegar no lobby, desative a função."
                        )
                    }
                case .profile:
                    if let access = authorizedAccess {
                        ProfileTabView(access: access)
                    } else {
                        TabPlaceholderView(
                            title: "Profile",
                            symbol: "person.crop.circle",
                            detail: "Entre com sua key para ver as informações do perfil."
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabNavigation
        }
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

private struct TabPlaceholderView: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.75))
            Text(detail)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProfileTabView: View {
    let access: KeyAuthAccess

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MEU PROFILE")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Informações da licença e do dispositivo")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.56))
                }
                .padding(.top, 12)

                profileCard(title: "INFORMAÇÕES DA KEY", symbol: "key.fill") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(access.licenseExpiresAt.timeIntervalSince(context.date)))
                        let days = remaining / 86_400
                        let hours = (remaining % 86_400) / 3_600
                        let minutes = (remaining % 3_600) / 60
                        ProfileInfoRow(
                            title: "DURAÇÃO DA KEY",
                            value: remaining == 0 ? "Expirada" : String(format: "%d d %02d h %02d min", days, hours, minutes),
                            detail: "Licença de \(access.licenseDurationDays) dias · expira em \(access.licenseExpiresAt.formatted(date: .abbreviated, time: .shortened)).",
                            symbol: "clock"
                        )
                    }
                    profileDivider
                    ProfileInfoRow(title: "PACOTE", value: access.packageName, symbol: "shippingbox.fill")
                    profileDivider
                    ProfileInfoRow(title: "KEY MASCARADA", value: access.keyPreview, symbol: "key.horizontal")
                }

                profileCard(title: "DISPOSITIVO", symbol: "iphone") {
                    ProfileInfoRow(title: "VERSÃO DO iOS", value: AppInfo.osVersion, symbol: "gearshape")
                    profileDivider
                    ProfileInfoRow(title: "BUILD DO iOS", value: AppInfo.osBuild, symbol: "number")
                }

                profileCard(title: "VERSÕES DO IOS LISTADAS", symbol: "checkmark.seal") {
                    ForEach(Array(ExploitSupportPolicy.listedIOSVersions.enumerated()), id: \.offset) { item in
                        if item.offset > 0 {
                            profileDivider
                        }
                        ProfileInfoRow(
                            title: "COMPATIBILIDADE DO APP",
                            value: item.element,
                            detail: "O app pode abrir nesta versão. O acesso privilegiado só é liberado quando o exploit correspondente estiver verificado.",
                            symbol: "checkmark.circle"
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(height: 1)
            .padding(.leading, 42)
    }

    private func profileCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct ProfileInfoRow: View {
    let title: String
    let value: String
    var detail: String? = nil
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(.white.opacity(0.46))
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
        let count = min(110, max(1, Int((size.width * size.height) / 13_000)))
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let horizontalInset = size.width * 0.10
        let verticalInset = size.height * 0.12
        let contentWidth = max(1, size.width - horizontalInset * 2)
        let contentHeight = max(1, size.height - verticalInset * 2)
        var random = StableRandom(seed: UInt64(width) &* 73_856_093 ^ UInt64(height) &* 19_349_663)

        return (0..<count).map { _ in
            ParticleNode(
                origin: CGPoint(
                    x: horizontalInset + random.nextUnit() * contentWidth,
                    y: verticalInset + random.nextUnit() * contentHeight
                ),
                velocity: CGPoint(
                    x: (random.nextUnit() - 0.5) * 13.5,
                    y: (random.nextUnit() - 0.5) * 13.5
                )
            )
        }
    }

    private static func reflectedPosition(of node: ParticleNode, in size: CGSize, time: TimeInterval) -> CGPoint {
        let elapsed = CGFloat(time)
        let horizontalInset = size.width * 0.10
        let verticalInset = size.height * 0.12
        return CGPoint(
            x: reflected(
                node.origin.x + node.velocity.x * elapsed,
                between: horizontalInset,
                and: size.width - horizontalInset
            ),
            y: reflected(
                node.origin.y + node.velocity.y * elapsed,
                between: verticalInset,
                and: size.height - verticalInset
            )
        )
    }

    private static func reflected(_ value: CGFloat, between lowerBound: CGFloat, and upperBound: CGFloat) -> CGFloat {
        let range = max(1, upperBound - lowerBound)
        let period = Double(range) * 2
        var position = Double(value - lowerBound).truncatingRemainder(dividingBy: period)
        if position < 0 { position += period }
        return lowerBound + CGFloat(position <= Double(range) ? position : period - position)
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
