import SwiftUI

// MARK: - Shared breath phase model

enum BreathPhase: Equatable {
    case inhale, exhale

    var label: String {
        switch self {
        case .inhale: return "Breathe in"
        case .exhale: return "Breathe out"
        }
    }

    var duration: Double {
        switch self {
        case .inhale: return 5.5
        case .exhale: return 6.5
        }
    }
}

// MARK: - Shared breath circle visual

/// Multiple nested circles that scale together with a soft offset stagger,
/// creating an ethereal "many lungs" effect. Controlled externally via
/// `scale` (0.55 = exhale, 1.0 = inhale).
@MainActor
struct BreathCircleView: View {
    var scale: CGFloat
    var phaseDuration: Double

    /// Soft 3-stop radial gradient: calm teal core, indigo midrange,
    /// transparent edge.
    private static let palette: [Color] = [
        Color(hex: "#7CC1D8"),
        Color(hex: "#5B8DB8"),
        Color(hex: "#5B6DB8")
    ]

    var body: some View {
        ZStack {
            ring(diameter: 260, opacity: 0.06, color: Self.palette[2], delay: 0.0)
            ring(diameter: 220, opacity: 0.10, color: Self.palette[1], delay: 0.1)
            ring(diameter: 170, opacity: 0.14, color: Self.palette[1], delay: 0.2)
            ring(diameter: 120, opacity: 0.22, color: Self.palette[0], delay: 0.3)

            // Inner glowing core — solid radial gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.palette[0].opacity(0.5),
                            Self.palette[1].opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 80 * scale, height: 80 * scale)
                .blur(radius: 4)
        }
        // Keep a stable footprint so surrounding text does not shift vertically.
        .frame(width: 260, height: 260)
        .animation(.easeInOut(duration: phaseDuration), value: scale)
    }

    @ViewBuilder
    private func ring(diameter: CGFloat, opacity: Double, color: Color, delay: Double) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: diameter * scale, height: diameter * scale)
            .blur(radius: 0.5)
            .animation(
                .easeInOut(duration: phaseDuration).delay(delay),
                value: scale
            )
    }
}
