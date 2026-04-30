import SwiftUI

/// Mindfulness left panel — mode selector + active session view.
@MainActor
struct MindfulnessView: View {
    @Environment(AppState.self) private var appState

    enum Mode { case none, breathe, rest }
    @State private var activeMode: Mode = .none

    var body: some View {
        VStack(spacing: 0) {
            switch activeMode {
            case .none:
                modeSelector
            case .breathe:
                BreatheView { withAnimation(.easeInOut(duration: 0.3)) { activeMode = .none } }
                    .transition(.opacity)
            case .rest:
                RestView { withAnimation(.easeInOut(duration: 0.3)) { activeMode = .none } }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeMode == .none)
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        ZStack {
            AmbientAppBackground(tint: Color(hex: "#5B8DB8"), intensity: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 20) {
            Spacer()

            // Pommy hero — breathing in sync with the section
            PommyMascot(pose: .idle, size: 110, chatty: true)
                .padding(.bottom, 4)

            VStack(spacing: Spacing.sm) {
                Text("Mindfulness")
                    .font(.pommyTitle)
                    .foregroundStyle(.primary)

                Text("Step away from the void for a sec")
                    .font(.pommyBody)
                    .italic()
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            HStack(spacing: 16) {
                breatheCard
                restCard
            }
            .padding(.horizontal, 24)

            Spacer()
            }
        }
    }

    private var breatheCard: some View {
        HoverCard(glow: Color(hex: "#5B8DB8"), glowAlignment: .topLeading) {
            withAnimation(.easeInOut(duration: 0.3)) { activeMode = .breathe }
        } content: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#5B8DB8").opacity(0.18))
                        .frame(width: 52, height: 52)
                        .blur(radius: 12)
                    Image(systemName: "wind")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(width: 52, height: 52)
                }
                VStack(spacing: 4) {
                    Text("Breathe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(appState.config.breatheDurationMins) min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var restCard: some View {
        HoverCard(glow: Color(hex: "#E8A87C"), glowAlignment: .topTrailing) {
            withAnimation(.easeInOut(duration: 0.3)) { activeMode = .rest }
        } content: {
            VStack(spacing: 10) {
                PommyMascot(pose: .sleep, size: 56)
                    .shadow(color: Color(hex: "#E8A87C").opacity(0.25), radius: 12, y: 4)
                VStack(spacing: 4) {
                    Text("Rest")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(appState.config.restDurationMins) min · \(appState.config.ambientSound.rawValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Hover card

private struct HoverCard<Content: View>: View {
    let glow: Color
    let glowAlignment: Alignment
    let action: () -> Void
    @ViewBuilder let content: Content

    init(
        glow: Color,
        glowAlignment: Alignment = .topLeading,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.glow = glow
        self.glowAlignment = glowAlignment
        self.action = action
        self.content = content()
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .padding(.horizontal, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                        // Ambient glow bleeding from one corner
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        glow.opacity(isHovered ? 0.32 : 0.16),
                                        .clear
                                    ],
                                    center: glowCenter,
                                    startRadius: 0,
                                    endRadius: 180
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(
                    color: glow.opacity(isHovered ? 0.25 : 0),
                    radius: isHovered ? 20 : 0,
                    y: isHovered ? 8 : 0
                )
                .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Motion.breath, value: isHovered)
    }

    private var glowCenter: UnitPoint {
        switch glowAlignment {
        case .topLeading:     return UnitPoint(x: 0.15, y: 0.15)
        case .topTrailing:    return UnitPoint(x: 0.85, y: 0.15)
        case .bottomLeading:  return UnitPoint(x: 0.15, y: 0.85)
        case .bottomTrailing: return UnitPoint(x: 0.85, y: 0.85)
        default:              return .center
        }
    }
}
