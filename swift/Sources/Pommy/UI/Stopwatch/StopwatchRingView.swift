import SwiftUI

/// Concentric ring visualization for the stopwatch.
///
/// Visual language:
/// - Ghost tracks for all 6 rings are always faintly visible (shows capacity).
/// - The mascot always runs on the outer ring.
/// - When a ring completes, it shrinks inward and a fresh outer ring starts.
/// - Elapsed time and session label float in the empty center core.
/// - When all 6 rings complete, they spring-collapse to a point, then the
///   next set springs outward from center. A small ×N badge counts cycles.
///
/// Ring geometry (6 rings, baseRadius=30, gap=14, lineWidth=5):
///   Ring 0 → ⌀ 200  |  Ring 5 → ⌀ 60   Total frame ≈ 210 × 210
@MainActor
struct StopwatchRingView: View {
    let elapsedSeconds: Int
    let color:          Color
    let minsPerRing:    Int
    /// Pose for the small mascot riding the active ring tip. Pass `nil` to
    /// hide the rider entirely (e.g. for break sessions where a chill Pommy
    /// already lives in the center).
    var ridingPose:     MascotPose? = .focus

    private let maxRings:   Int     = 6
    private let lineWidth:  CGFloat = 5
    private let baseRadius: CGFloat = 30
    private let ringGap:    CGFloat = 14

    @State private var isCollapsing:   Bool    = false
    @State private var displayedCycle: Int     = 0
    @State private var collapseScale:  CGFloat = 1.0

    // MARK: - Derived values

    private var secondsPerRing:  Int { minsPerRing * 60 }
    private var secondsPerCycle: Int { secondsPerRing * maxRings }
    private var currentCycle:    Int { elapsedSeconds / secondsPerCycle }

    /// When collapsing, pin display to the final second of the completed cycle
    /// so all 6 rings appear fully filled as they shrink.
    private var positionInCycle: Int {
        isCollapsing
            ? secondsPerCycle - 1
            : elapsedSeconds % secondsPerCycle
    }

    private var completedRings: Int {
        min(positionInCycle / secondsPerRing, maxRings)
    }

    private var activeRingProgress: Double {
        if isCollapsing { return 1.0 }
        guard completedRings < maxRings else { return 1.0 }
        let posInRing = positionInCycle % secondsPerRing
        return Double(posInRing) / Double(secondsPerRing)
    }

    private var outerDiameter: CGFloat {
        (baseRadius + CGFloat(maxRings - 1) * ringGap) * 2 + lineWidth + 2
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Ghost track only for the active ring — shows its target arc.
            // Future rings are invisible until they start filling.
            Circle()
                .stroke(Surface.topHighlight, lineWidth: lineWidth)
                .frame(width: ringDiameter(forSlot: 0), height: ringDiameter(forSlot: 0))

            // Completed rings — fully filled, dimmed
            ForEach(Array(0..<completedRings), id: \.self) { i in
                let completedSlot = completedRingSlot(for: i)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        color.opacity(0.32),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter(forSlot: completedSlot), height: ringDiameter(forSlot: completedSlot))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .spring(response: 0.36, dampingFraction: 0.82),
                        value: completedRings
                    )
            }

            // Active ring — full brightness with angular gradient + glow
            if completedRings < maxRings {
                let dia = ringDiameter(forSlot: 0)

                // Glow halo
                Circle()
                    .trim(from: 0, to: activeRingProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: dia, height: dia)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
                    .opacity(0.5)
                    .animation(.linear(duration: 1), value: elapsedSeconds)

                Circle()
                    .trim(from: 0, to: activeRingProgress)
                    .stroke(color.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: dia, height: dia)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: elapsedSeconds)

                if let pose = ridingPose {
                    let angleRad = (-90.0 + activeRingProgress * 360.0) * .pi / 180.0
                    let r        = dia / 2
                    PommyMascot(pose: pose, size: 22, cheekTint: color)
                        .shadow(color: color.opacity(0.45), radius: 6)
                        .offset(
                            x: CGFloat(cos(angleRad)) * r,
                            y: CGFloat(sin(angleRad)) * r
                        )
                        .animation(.linear(duration: 1), value: elapsedSeconds)
                        .animation(.easeInOut(duration: 0.3), value: pose)
                }
            }

            // Cycle badge — small ×N in center after first collapse
            if displayedCycle > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                    Text("×\(displayedCycle)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .scaleEffect(collapseScale)
        .frame(width: outerDiameter, height: outerDiameter)
        .onChange(of: currentCycle) { old, new in
            guard new > old else { return }
            triggerCollapse(newCycle: new)
        }
    }

    // MARK: - Collapse animation

    /// All rings collapse to center, cycle badge updates, fresh rings spring out.
    private func triggerCollapse(newCycle: Int) {
        // Pin display to "all rings full" immediately before scale animation starts.
        isCollapsing = true

        withAnimation(.easeIn(duration: 0.35)) {
            collapseScale = 0.01
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            // Swap to fresh cycle state while invisible.
            isCollapsing   = false
            displayedCycle = newCycle
            collapseScale  = 0.01

            // Spring the fresh rings outward.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) {
                collapseScale = 1.0
            }
        }
    }

    // MARK: - Helpers

    /// Slot 0 is the outer mascot lane. Higher slots move inward.
    private func ringDiameter(forSlot slot: Int) -> CGFloat {
        let clamped = min(max(slot, 0), maxRings - 1)
        let reversedIndex = (maxRings - 1) - clamped
        return (baseRadius + CGFloat(reversedIndex) * ringGap) * 2
    }

    /// Completed rings stack inward over time:
    /// - newest completed ring sits just inside the outer lane (slot 1)
    /// - older completed rings shift deeper inward
    private func completedRingSlot(for completedIndex: Int) -> Int {
        completedRings - completedIndex
    }
}
