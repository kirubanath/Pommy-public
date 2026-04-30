import SwiftUI

/// Full-screen breathing animation shown before focus starts (if enabled).
/// Drives through N breath cycles, then calls `session.beginFocus()`.
/// The user can skip at any time.
@MainActor
struct BreathingGateView: View {
    @Environment(AppState.self) private var appState

    @State private var scale:      CGFloat     = 0.55
    @State private var phase:      BreathPhase = .inhale
    @State private var cyclesDone: Int         = 0

    private var tint: Color {
        appState.config.color(for: appState.session.category)
    }

    var body: some View {
        ZStack {
            // Radial backdrop anchored on the breath circle — the room dims to focus you.
            RadialGradient(
                colors: [
                    tint.opacity(0.18),
                    Surface.base
                ],
                center: .center,
                startRadius: 60,
                endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                BreathCircleView(scale: scale, phaseDuration: phase.duration)
                    .padding(.bottom, 40)

                VStack(spacing: 12) {
                    Text(phase.label)
                        .font(.system(size: 28, weight: .ultraLight))
                        .tracking(0.5)
                        .foregroundStyle(.primary.opacity(0.85))
                        .frame(height: 34)
                        .animation(.easeInOut(duration: 0.25), value: phase)

                    Text("\(cyclesDone) of \(appState.config.breathCycles)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }

                Spacer()

                Button("Skip") {
                    appState.session.beginFocus()
                }
                .font(.system(size: 11, weight: .medium))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary.opacity(0.55))
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(cyclesDone >= 1 ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: cyclesDone)
            }
        }
        .onAppear { startCycle() }
    }

    // MARK: - Cycle engine

    private func startCycle() {
        runPhase(.inhale)
    }

    private func runPhase(_ p: BreathPhase) {
        phase = p
        switch p {
        case .inhale:
            scale = 1.0
            after(p.duration) { runPhase(.exhale) }
        case .exhale:
            scale = 0.55
            after(p.duration) {
                cyclesDone += 1
                if cyclesDone >= appState.config.breathCycles {
                    appState.session.beginFocus()
                } else {
                    runPhase(.inhale)
                }
            }
        }
    }

    private func after(_ delay: Double, block: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                block()
            }
        }
    }
}
