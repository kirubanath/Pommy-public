import SwiftUI

/// A cute growing plant that lives in a terracotta pot.
///
/// `growth` drives the entire animation:
/// - 0.00 → bare soil
/// - 0.18 → first leaf sprouts
/// - 0.45 → second leaf
/// - 0.68 → third leaf
/// - 0.82 → flower blooms
/// - 1.00 → fully bloomed, flower gently sways
///
/// The parent is responsible for animating `growth` over time.
/// In timer mode: `growth = elapsed / target` (caps at 1.0).
/// In stopwatch mode: `growth = min(1, elapsed / (30 * 60))` (blooms at 30 min).
///
/// All content is guaranteed to stay within the declared `size × size` frame
/// at every growth stage (verified against the stem/flower geometry constants).
@MainActor
struct PlantView: View {
    var growth: Double
    var size: CGFloat = 100

    @Environment(AppState.self) private var appState
    @State private var sway: Bool = false

    // Convenience: clamped growth [0, 1]
    private var g: Double { min(1.0, max(0.0, growth)) }

    // Stem geometry.
    // soilDY = 22% down from centre leaves 28% of frame below for the pot
    // and allows a 0.46-unit stem + flower to stay within the top of the frame.
    private var stemH: CGFloat { CGFloat(g) * size * 0.46 }

    // All positions expressed as offset from ZStack centre (+ = down in SwiftUI).
    // Soil sits 22% of size below the ZStack centre.
    private var soilDY: CGFloat { size * 0.22 }

    var body: some View {
        ZStack {
            potLayer
            stemLayer
            leafLayer(g: g, threshold: 0.18, span: 0.25, xSign: -1, stemFrac: 0.30)
            leafLayer(g: g, threshold: 0.45, span: 0.25, xSign:  1, stemFrac: 0.62)
            leafLayer(g: g, threshold: 0.68, span: 0.20, xSign: -1, stemFrac: 0.84)
            flowerLayer
        }
        .frame(width: size, height: size)
        .onAppear {
            // Start the gentle sway once mounted; it drives the flower oscillation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if appState.effectiveAnimationMode != .frozen { sway = true }
            }
        }
        .onChange(of: appState.effectiveAnimationMode) { _, mode in
            // Cancel the .repeatForever animation when frozen so the SwiftUI graph
            // stops scheduling updates; restart cleanly when active again.
            if mode == .frozen {
                withAnimation(.none) { sway = false }
            } else if !sway {
                sway = true
            }
        }
    }

    // MARK: - Pot

    private var potLayer: some View {
        ZStack {
            // Rim
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#C08B6A"))
                .frame(width: size * 0.50, height: size * 0.065)
            // Body
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(hex: "#A07050"))
                .frame(width: size * 0.46, height: size * 0.24)
                .offset(y: size * 0.046)
            // Soil
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#3A2010"))
                .frame(width: size * 0.42, height: size * 0.065)
                .offset(y: size * 0.005)
        }
        // Place pot so its top (soil level) lines up with soilDY
        .offset(y: soilDY + size * 0.095)
    }

    // MARK: - Stem

    private var stemLayer: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color(hex: "#5A8C6A"))
            .frame(width: max(1, size * 0.040), height: max(1, stemH))
            // Centre of stem is at (soilDY - stemH/2) from ZStack centre
            .offset(y: soilDY - stemH / 2)
            .animation(.linear(duration: 1.0), value: g)
    }

    // MARK: - Leaves (parameterised)

    private func leafLayer(
        g: Double,
        threshold: Double,
        span: Double,
        xSign: Double,
        stemFrac: Double
    ) -> some View {
        let f   = CGFloat(min(1.0, max(0.0, (g - threshold) / span)))
        let lDY = soilDY - stemH * CGFloat(stemFrac)

        return Ellipse()
            .fill(Color(hex: "#4A8C5A"))
            .frame(width: max(1, size * 0.23 * f), height: max(1, size * 0.10 * f))
            .offset(x: CGFloat(xSign) * size * 0.14 * f, y: lDY)
            .opacity(Double(f))
            .animation(.linear(duration: 1.0), value: g)
    }

    // MARK: - Flower

    private var flowerLayer: some View {
        let f    = CGFloat(min(1.0, max(0.0, (g - 0.82) / 0.18)))
        // Flower group sits just above the stem tip; offset reduced so the
        // petals stay inside the declared frame at full growth.
        let fDY  = soilDY - stemH - size * 0.07
        let swayDeg: Double = sway ? 5 : -5

        return ZStack {
            // 5 petals
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(Color(hex: "#F0A8B8"))
                    .frame(width: size * 0.105, height: size * 0.12)
                    .offset(y: -(size * 0.07))
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            // Centre
            Circle()
                .fill(Color(hex: "#F5D060"))
                .frame(width: size * 0.12)
        }
        .scaleEffect(max(0.001, f))
        .opacity(Double(f))
        .offset(y: fDY)
        // Gentle sway once fully bloomed
        .rotationEffect(
            .degrees(g >= 0.95 ? swayDeg : 0),
            anchor: UnitPoint(x: 0.5, y: 1.3)
        )
        .animation(.linear(duration: 1.0), value: g)
        .animation(
            g >= 0.95
                ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                : .default,
            value: sway
        )
    }
}
