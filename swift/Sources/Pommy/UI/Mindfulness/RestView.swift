import SwiftUI
import AVFoundation

/// Mindfulness rest screen — tomato mascot on grass with ambient audio.
@MainActor
struct RestView: View {
    @Environment(AppState.self) private var appState

    let onDismiss: () -> Void

    @State private var elapsed:   Int    = 0
    @State private var isRunning: Bool   = false
    @State private var isPaused:  Bool   = false
    @State private var ticker:    Timer? = nil
    @State private var player:    AVAudioPlayer? = nil

    // Grass blade animation phases (different per blade for natural feel)
    @State private var grassPhase: Double = 0
    @State private var grassTimer: Timer? = nil

    private var totalSeconds: Int { appState.config.restDurationMins * 60 }
    private var remaining:    Int { max(0, totalSeconds - elapsed) }
    private var isVisualsActive: Bool { appState.effectiveAnimationMode != .frozen }
    private var moteInterval: Double {
        switch appState.effectiveAnimationMode {
        case .full: return 1.0 / 15.0
        case .throttled: return 1.0 / 6.0
        case .frozen: return 60.0
        }
    }

    var body: some View {
        ZStack {
            // Warm sunset backdrop with faint star specks
            LinearGradient(
                colors: [
                    Color(hex: "#2A1F1A"),
                    Color(hex: "#1B1410"),
                    Color(hex: "#16110E")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Drifting ambient motes — fireflies + dust
            TimelineView(.animation(minimumInterval: moteInterval)) { context in
                let moteDrift = context.date.timeIntervalSinceReferenceDate
                ForEach(0..<8, id: \.self) { i in
                    ambientMote(index: i, moteDrift: moteDrift)
                }
            }

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                mascotScene
                    .padding(.bottom, 18)

                VStack(spacing: 8) {
                    Text(formatTime(remaining))
                        .font(.system(size: 16, weight: .light).monospacedDigit())
                        .tracking(1.0)
                        .foregroundStyle(Color.secondary.opacity(0.42))
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 10)

                Spacer()

                controls
                    .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startGrassAnimation()
            startSession()
        }
        .onChange(of: appState.effectiveAnimationMode) { _, _ in
            startGrassAnimation()
        }
        .onDisappear { stopAll() }
    }

    private func ambientMote(index i: Int, moteDrift: Double) -> some View {
        let baseXs: [CGFloat] = [-180, -110, -40, 30, 90, 150, 200, -200]
        let baseYs: [CGFloat] = [-200, -140, -180, -110, -160, -90, -210, -120]
        let phase  = Double(i) * 0.7
        let x      = baseXs[i % baseXs.count] + CGFloat(sin(moteDrift + phase) * 14)
        let y      = baseYs[i % baseYs.count] + CGFloat(cos(moteDrift * 0.8 + phase) * 10)
        let pulse  = (sin(moteDrift * 1.2 + phase) + 1) / 2
        let opacity = 0.04 + pulse * 0.08

        return Circle()
            .fill(Color(hex: "#F5C892").opacity(opacity))
            .frame(width: 3 + CGFloat(pulse * 2), height: 3 + CGFloat(pulse * 2))
            .blur(radius: 0.5)
            .offset(x: x, y: y)
    }

    // MARK: - Mascot scene

    private var mascotScene: some View {
        ZStack(alignment: .bottom) {
            // Animated grass blades
            HStack(spacing: 5) {
                ForEach(0..<10, id: \.self) { i in
                    grassBlade(index: i)
                }
            }
            .frame(width: 280, height: 64)
            .offset(y: 42)

            // Sleeping Pommy with soft drop shadow so it sits "on" the grass
            PommyMascot(
                pose: .sleep,
                size: 180,
                cadence: .hero,
                activityMode: appState.effectiveAnimationMode
            )
                .shadow(color: Color.black.opacity(0.4), radius: 24, y: 8)
                .offset(y: -4)
        }
        .frame(width: 300, height: 260)
    }

    private func grassBlade(index: Int) -> some View {
        let phase   = Double(index) * 0.4
        let heights: [CGFloat] = [28, 22, 32, 18, 30, 24, 20, 26, 34, 19]
        let height  = heights[index % heights.count]
        let windAmp = 4.0 + Double(index % 3)
        let offset  = sin(grassPhase + phase) * windAmp

        // Layered green tones — slightly different per blade for depth
        let palette: [Color] = [
            Color(hex: "#3F6B4D"),
            Color(hex: "#4A7C59"),
            Color(hex: "#5C8C6B")
        ]
        let color = palette[index % palette.count]

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.62), color.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: height)
            .offset(x: CGFloat(offset), y: 0)
            .rotationEffect(.degrees(sin(grassPhase + phase) * 8), anchor: .bottom)
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
            actionButton("xmark", label: "Quit") { stopAll(); onDismiss() }
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
        startAudio()
        startTicker()
    }

    private func pauseSession() {
        guard isRunning else { return }
        isPaused = true
        player?.pause()
        stopTicker()
    }

    private func resumeSession() {
        guard isRunning, isPaused else { return }
        isPaused = false
        player?.play()
        startTicker()
    }

    private func stopSession() {
        isRunning = false
        isPaused  = false
        elapsed   = 0
        stopAudio()
        stopTicker()
    }

    private func stopAll() {
        stopSession()
        stopGrassAnimation()
    }

    // MARK: - Grass animation

    private func startGrassAnimation() {
        stopGrassAnimation()
        guard isVisualsActive else { return }
        let interval: Double = appState.effectiveAnimationMode == .full ? 0.05 : 0.16
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                grassPhase += interval
            }
        }
        RunLoop.main.add(t, forMode: .common)
        grassTimer = t
    }

    private func stopGrassAnimation() {
        grassTimer?.invalidate()
        grassTimer = nil
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
                if elapsed >= totalSeconds {
                    stopAll()
                    onDismiss()
                }
            }
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - Audio

    private func startAudio() {
        guard let filename = appState.config.ambientSound.filename,
              let url = AppPaths.audio(named: filename)
        else { return }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1  // loop indefinitely
            p.volume        = Float(appState.config.ambientVolume)
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // Audio file unavailable — silent fallback, not fatal.
        }
    }

    private func stopAudio() {
        player?.stop()
        player = nil
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
