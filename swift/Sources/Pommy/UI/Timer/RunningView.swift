import SwiftUI

/// Shown during focus/break running, paused, overflow, and post-session states.
/// The ring is the scene — no decorative visuals, just the arc, countdown, and controls.
@MainActor
struct RunningView: View {
    @Environment(AppState.self) private var appState

    // Drives the subtle terminus dot pulse.
    @State private var terminusPulse: Bool = false
    @State private var ringBreath:    Bool = false
    @State private var overflowGlow:  Bool = false

    @State private var windowIsKey: Bool = true

    private static let ringDiameter: CGFloat = 220
    private static let lineWidth:    CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            taskLabel
                .padding(.bottom, 16)

            ringStack
                .padding(.bottom, 10)

            milestoneCaption
                .padding(.bottom, 6)

            endsAtLabel
                .padding(.bottom, 20)

            Spacer(minLength: 8)

            controls
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            windowIsKey = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ringBreath   = true
                overflowGlow = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            windowIsKey = false
            withAnimation(.none) {
                ringBreath   = false
                overflowGlow = false
            }
        }
        .onAppear { startTerminusPulse() }
    }

    // MARK: - Mid-session encouragement

    private var milestoneCaption: some View {
        let key = milestoneKey
        return Text(milestoneText)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(milestoneTint)
            .opacity(milestoneText.isEmpty ? 0 : 0.85)
            .id(key)
            .transition(.opacity.combined(with: .offset(y: 4)))
            .animation(.easeInOut(duration: 0.6), value: key)
    }

    private var milestoneTint: Color {
        let s = appState.session
        return s.isOverflow ? Color(hex: "#F0A020") : ringColor
    }

    /// A coarse identifier for the current milestone band, used to drive transitions.
    private var milestoneKey: String {
        guard appState.session.sessionType == .focus else {
            return appState.session.isOverflow ? "break-overflow" : "break-running"
        }

        if appState.session.isOverflow { return "overflow" }
        let progress = sessionProgress
        switch progress {
        case ..<0.20:  return "start"
        case ..<0.45:  return "settling"
        case ..<0.55:  return "halfway"
        case ..<0.78:  return "stretching"
        case ..<0.92:  return "final"
        default:       return "almost"
        }
    }

    private var milestoneText: String {
        guard appState.session.sessionType == .focus else { return "" }
        if appState.session.isOverflow { return "" }
        switch milestoneKey {
        case "start":      return ""
        case "settling":   return "Finding the vibe..."
        case "halfway":    return "Halfway — don't blow it"
        case "stretching": return "Almost there, hold on"
        case "final":      return "So close. Don't tab out."
        case "almost":     return "Literally one more minute"
        default:           return ""
        }
    }

    private var sessionProgress: Double {
        let s = appState.session
        guard s.targetSeconds > 0 else { return 0 }
        return min(1.0, Double(s.elapsedSeconds) / Double(s.targetSeconds))
    }

    @ViewBuilder
    private var endsAtLabel: some View {
        let s = appState.session
        if !s.isOverflow && s.remainingSeconds > 0 {
            let endsAt = Date().addingTimeInterval(TimeInterval(s.remainingSeconds))
            HStack(spacing: 6) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ringColor.opacity(0.85))
                Text("ends")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary.opacity(0.7))
                Text(formatEndTime(endsAt))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(ringColor.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
    }

    private func formatEndTime(_ date: Date) -> String {
        let f      = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }

    private var isPaused: Bool {
        appState.session.state == .focusPaused || appState.session.state == .breakPaused
    }

    // MARK: - Ring + countdown

    private var ringStack: some View {
        ZStack {
            // Inner soft breath glow — pauses with the session
            RadialGradient(
                colors: [ringColor.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: Self.ringDiameter * 0.55
            )
            .frame(width: Self.ringDiameter, height: Self.ringDiameter)
            .scaleEffect(ringBreath && !isPaused && windowIsKey ? 1.06 : 0.94)
            .opacity(isPaused ? 0.4 : 1.0)
            .blur(radius: 8)
            .animation(
                windowIsKey ? .easeInOut(duration: 4).repeatForever(autoreverses: true) : .linear(duration: 0),
                value: ringBreath
            )

            // Background track
            Circle()
                .stroke(Surface.fillFaint, lineWidth: Self.lineWidth)
                .frame(width: Self.ringDiameter, height: Self.ringDiameter)

            // Soft outer glow behind the arc
            ringArc
                .blur(radius: 12)
                .opacity(isPaused ? 0.0 : 0.55)
                .scaleEffect(appState.session.isOverflow && overflowGlow && windowIsKey ? 1.05 : 1.0)
                .animation(
                    windowIsKey && appState.session.isOverflow
                        ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                        : .default,
                    value: overflowGlow
                )

            ringArc
                .opacity(isPaused ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: isPaused)

            // Pommy rides the leading tip of the focus arc instead of a dot.
            // Skip when overflow (full ring, no leading tip) or when target is
            // too short for a meaningful traversal.
            if appState.session.sessionType == .focus,
               !appState.session.isOverflow,
               appState.session.targetSeconds >= 60 {
                terminusPommy
                    .opacity(isPaused ? 0.85 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isPaused)
            }

            centerDisplay
        }
    }

    @ViewBuilder
    private var ringArc: some View {
        let s = appState.session
        if s.isOverflow {
            // Solid full ring for overflow — warm warning, with breath glow above.
            Circle()
                .stroke(
                    overflowColor.ringGradient,
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .frame(width: Self.ringDiameter, height: Self.ringDiameter)
        } else {
            let fraction = min(1.0, CGFloat(s.elapsedSeconds) / CGFloat(max(1, s.targetSeconds)))
            let trimFrom = s.sessionType == .focus ? 0.0           : (1.0 - fraction)
            let trimTo   = s.sessionType == .focus ? fraction      : 1.0
            Circle()
                .trim(from: trimFrom, to: trimTo)
                .stroke(
                    ringColor.ringGradient,
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .frame(width: Self.ringDiameter, height: Self.ringDiameter)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: s.elapsedSeconds)
        }
    }

    /// Small filled circle at the leading tip of the progress arc.
    private var terminusDot: some View {
        let s        = appState.session
        let fraction = min(1.0, Double(s.elapsedSeconds) / Double(max(1, s.targetSeconds)))
        let angleDeg = s.sessionType == .focus
            ? -90.0 + fraction * 360.0
            :  270.0 - fraction * 360.0
        let angleRad = angleDeg * .pi / 180.0
        let r        = Self.ringDiameter / 2
        let dx       = CGFloat(cos(angleRad)) * r
        let dy       = CGFloat(sin(angleRad)) * r

        return Circle()
            .fill(ringColor)
            .frame(width: Self.lineWidth + 2, height: Self.lineWidth + 2)
            .shadow(color: ringColor.opacity(0.7), radius: 6)
            .offset(x: dx, y: dy)
            .animation(.linear(duration: 1), value: s.elapsedSeconds)
    }

    /// A tiny Pommy mascot that rides the leading tip of the focus arc.
    /// Pose follows session state so the user gets a glance of intent.
    private var terminusPommy: some View {
        let s        = appState.session
        let fraction = min(1.0, Double(s.elapsedSeconds) / Double(max(1, s.targetSeconds)))
        let angleDeg = -90.0 + fraction * 360.0
        let angleRad = angleDeg * .pi / 180.0
        let r        = Self.ringDiameter / 2
        let dx       = CGFloat(cos(angleRad)) * r
        let dy       = CGFloat(sin(angleRad)) * r

        let pose: MascotPose = isPaused ? .curious : .focus

        return PommyMascot(pose: pose, size: 26)
            .shadow(color: ringColor.opacity(0.45), radius: 8)
            .offset(x: dx, y: dy)
            .animation(.linear(duration: 1), value: s.elapsedSeconds)
            .animation(.easeInOut(duration: 0.3), value: pose)
    }

    private var centerDisplay: some View {
        let s        = appState.session
        let isBreak  = s.sessionType == .break
        let overflow = s.isOverflow

        return VStack(spacing: 6) {
            if isBreak {
                // Break: relaxing Pommy hero, time underneath. No leading dot.
                PommyMascot(pose: .sleep, size: 64, cheekTint: Color(hex: "#7CB893"))
                    .frame(height: 70)
            } else if overflow {
                // Overflow: headband Pommy, focusing hard.
                PommyMascot(
                    pose: .focusHard,
                    size: 64,
                    cheekTint: appState.config.color(for: s.category)
                )
                .frame(height: 70)
            }

            Group {
                if overflow {
                    Text("+\(formatTime(s.overflowSeconds))")
                        .foregroundStyle(overflowColor)
                } else {
                    Text(formatTime(s.remainingSeconds))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95),
                                         Color.white.opacity(0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .font(.system(size: (isBreak || overflow) ? 32 : 56, weight: .ultraLight).monospacedDigit())

            Text(centerCaption)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }

    private var centerCaption: String {
        let s = appState.session
        if s.sessionType == .focus {
            return s.isOverflow ? "bonus round" : "focus"
        } else {
            return "taking a break"
        }
    }

    private var ringColor: Color {
        appState.session.sessionType == .focus
            ? appState.config.color(for: appState.session.category)
            : Color(white: 0.43)
    }

    private var overflowColor: Color {
        appState.session.sessionType == .focus
            ? Color(hex: "#F0A020")
            : Color(hex: "#F0A020")
    }

    // MARK: - Task label

    @ViewBuilder
    private var taskLabel: some View {
        if !appState.session.task.isEmpty {
            Text(appState.session.task)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch appState.session.state {
        case .focusRunning, .focusOverflow:
            runningRow(showFocusShortcut: false)
        case .breakRunning, .breakOverflow:
            runningRow(showFocusShortcut: true)
        case .focusPaused, .breakPaused:
            pausedRow
        case .afterFocusSaved:
            afterFocusRow
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        default:
            EmptyView()
        }
    }

    private func runningRow(showFocusShortcut: Bool) -> some View {
        HStack(spacing: 16) {
            iconButton("pause.fill", label: "Pause", shortcut: .init(" ", modifiers: [])) {
                appState.session.pause()
            }
            iconButton("stop.fill", label: "Stop", shortcut: .init(".", modifiers: .command)) {
                appState.requestStop()
            }
            if showFocusShortcut {
                iconButton("target", label: "Focus Now", shortcut: nil) {
                    appState.requestStop()
                }
            }
        }
    }

    private var pausedRow: some View {
        HStack(spacing: 16) {
            iconButton("play.fill", label: "Resume", shortcut: .init(" ", modifiers: [])) {
                appState.session.resume()
            }
            iconButton("stop.fill", label: "Stop", shortcut: .init(".", modifiers: .command)) {
                appState.requestStop()
            }
        }
    }

    private var afterFocusRow: some View {
        Button {
            appState.session.targetSeconds = appState.config.breakDuration * 60
            appState.takeBreak(category: appState.session.category)
        } label: {
            Label("You've earned a break", systemImage: "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(Color(white: 0.5).verticalGradient)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Surface.fillStrong, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .pommyPress()
    }

    // MARK: - Icon button helper

    private func iconButton(
        _ symbol: String,
        label: String,
        shortcut: KeyboardShortcut?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Surface.topHighlight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .pommyPress()
        .ifLet(shortcut) { view, sc in
            view.keyboardShortcut(sc)
        }
    }

    // MARK: - Terminus pulse

    private func startTerminusPulse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            terminusPulse = true
            ringBreath    = true
            overflowGlow  = true
        }
    }

    // MARK: - Helpers

    private func formatTime(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }
}

// MARK: - View extension helper

private extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
