import SwiftUI

/// Standalone mindfulness breathing session — expanding circle, timed.
@MainActor
struct BreatheView: View {
    @Environment(AppState.self) private var appState

    let onDismiss: () -> Void

    @State private var scale:      CGFloat     = 0.55
    @State private var phase:      BreathPhase = .inhale
    @State private var elapsed:    Int         = 0
    @State private var isRunning:  Bool        = false
    @State private var isPaused:   Bool        = false
    @State private var timer:      Timer?      = nil

    private var totalSeconds: Int { appState.config.breatheDurationMins * 60 }
    private var remaining:    Int { max(0, totalSeconds - elapsed) }

    var body: some View {
        ZStack {
            // Deep radial backdrop — ethereal, focuses attention on the circle.
            RadialGradient(
                colors: [
                    Color(hex: "#0E1116"),
                    Color(hex: "#16161A")
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                BreathCircleView(scale: scale, phaseDuration: phase.duration)
                    .padding(.bottom, 36)

                Text(isRunning ? phase.label : "Ready")
                    .font(.system(size: 28, weight: .ultraLight))
                    .tracking(0.5)
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(height: 34)
                    .animation(.easeInOut(duration: 0.25), value: phase)
                    .padding(.bottom, 14)

                Text(formatTime(remaining))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary.opacity(0.5))

                Spacer()

                controls
                    .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear  { startSession() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            if isRunning {
                if isPaused {
                    actionButton("play.fill",  label: "Resume") { resumeSession() }
                } else {
                    actionButton("pause.fill", label: "Pause")  { pauseSession() }
                }
                actionButton("stop.fill",  label: "Stop")   { stopSession() }
            } else {
                actionButton("arrow.clockwise", label: "Restart") { startSession() }
            }

            actionButton("xmark", label: "Quit") { stopSession(); onDismiss() }
        }
    }

    private func actionButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pommyPress()
        .help(label)
    }

    // MARK: - Session lifecycle

    private func startSession() {
        elapsed   = 0
        isRunning = true
        isPaused  = false
        runPhase(.inhale)
        startTimer()
    }

    private func pauseSession() {
        guard isRunning else { return }
        isPaused = true
        stopTimer()
    }

    private func resumeSession() {
        guard isRunning, isPaused else { return }
        isPaused = false
        startTimer()
        runPhase(phase)
    }

    private func stopSession() {
        isRunning = false
        isPaused  = false
        stopTimer()
        withAnimation(.easeInOut(duration: 0.4)) { scale = 0.55 }
    }

    // MARK: - Breath cycle

    private func runPhase(_ p: BreathPhase) {
        guard isRunning, !isPaused else { return }
        phase = p
        switch p {
        case .inhale:
            scale = 1.0
            after(p.duration) { runPhase(.exhale) }
        case .exhale:
            scale = 0.55
            after(p.duration) { runPhase(.inhale) }
        }
    }

    // MARK: - Countdown timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
                if elapsed >= totalSeconds {
                    stopSession()
                    onDismiss()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func after(_ delay: Double, block: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                block()
            }
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
