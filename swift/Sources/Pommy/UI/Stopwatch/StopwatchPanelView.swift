import SwiftUI

/// Left-panel content for the Stopwatch page.
///
/// Open-ended session with no dial and no target. The elapsed time is the hero.
@MainActor
struct StopwatchPanelView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedCat: String = "Work"
    @State private var task: String = ""
    @State private var idleBreath: Bool = false

    // 24-hour target → no overflow in practice.
    private static let openEndedTarget = 24 * 3600

    var body: some View {
        ZStack {
            panelBackground
                .animation(.easeInOut(duration: 0.5), value: appState.session.state)

            Group {
                switch appState.session.state {
                case .idle, .afterFocusSaved, .afterBreakSaved:
                    idleContent
                        .transition(.opacity)
                default:
                    if appState.isStopwatchSession {
                        runningContent
                            .transition(.opacity)
                    } else {
                        blockedByTimerView
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: stateGroup)

            if appState.showStopSheet {
                StopSheet()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.showStopSheet)
        .onAppear { syncFromConfig() }
        .onChange(of: appState.session.state) { _, new in
            if new == .idle { syncFromConfig() }
        }
        .onChange(of: appState.effectiveAnimationMode) { _, mode in
            idleBreath = mode == .full
        }
    }

    // MARK: - Background tint

    private var panelBackground: some View {
        ZStack {
            tintColor.opacity(tintOpacity * 0.55)

            LinearGradient(
                colors: [
                    tintColor.opacity(tintOpacity * 0.75),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: 380)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var tintColor: Color {
        switch appState.session.state {
        case .breakRunning, .breakOverflow, .breakPaused:
            return Color(white: 0.43)
        default:
            return appState.config.color(for: currentCategory)
        }
    }

    private var tintOpacity: Double {
        switch appState.session.state {
        case .focusRunning:  return 0.20
        case .focusPaused:   return 0.15
        case .breakRunning:  return 0.15
        case .breakPaused:   return 0.10
        default:             return 0.10
        }
    }

    private var currentCategory: String {
        appState.session.state == .idle
            ? appState.config.defaultCategory
            : appState.session.category
    }

    private var stateGroup: Int {
        switch appState.session.state {
        case .idle, .afterFocusSaved, .afterBreakSaved: return 0
        default: return appState.isStopwatchSession ? 1 : 2
        }
    }

    private var blockedByTimerView: some View {
        VStack(spacing: 20) {
            PommyMascot(
                pose: .curious,
                size: 52,
                cadence: .hero,
                activityMode: appState.effectiveAnimationMode
            )
            VStack(spacing: 6) {
                Text("Timer is running.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                Text("Stop it there before starting the stopwatch.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button {
                withAnimation(Motion.springSoft) { appState.selectedPage = .timer }
            } label: {
                Label("Go to timer", systemImage: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Surface.topHighlight, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .pommyPress()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle content

    private var idleContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                greetingHeader
                    .padding(.top, 4)

                categoryPills
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    Text("0:00")
                        .font(.system(size: 56, weight: .ultraLight).monospacedDigit())
                        .foregroundStyle(Color.secondary.opacity(idleBreath ? 0.45 : 0.30))
                        .scaleEffect(idleBreath ? 1.015 : 1.0)
                        .animation(
                            appState.effectiveAnimationMode == .full
                                ? .easeInOut(duration: 5).repeatForever(autoreverses: true)
                                : .linear(duration: 0),
                            value: idleBreath
                        )
                    Text("freeform · no timer, just you")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 28)
                .onAppear { idleBreath = appState.effectiveAnimationMode == .full }

                taskField

                HStack(spacing: 10) {
                    startBtn(type: .focus)
                    startBtn(type: .break)
                }

                quickShortcut
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .overlay(alignment: .bottomTrailing) {
            PommyMascot(
                pose: .peek,
                size: 56,
                chatty: true,
                cadence: .decorative,
                activityMode: appState.effectiveAnimationMode
            )
                .opacity(0.85)
                .padding(.trailing, 20)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Greeting header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeOfDayGreeting)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary.opacity(0.6))
                Text(greetingSubtitle)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.primary.opacity(0.9))
            }
            Spacer()
        }
    }

    private var timeOfDayGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Morning."
        case 12..<17: return "Afternoon."
        case 17..<22: return "Evening."
        default:      return "It's late."
        }
    }

    private var greetingSubtitle: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "No timer. No rules. Just vibes."
        case 12..<17: return "Whenever you're ready, chief"
        case 17..<22: return "Let's wrap this one up"
        default:      return "You're still up. Respect."
        }
    }

    // MARK: - Running content

    private var runningContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            StopwatchRingView(
                elapsedSeconds: appState.session.elapsedSeconds,
                color: appState.session.sessionType == .focus
                    ? appState.config.color(for: appState.session.category)
                    : Color(white: 0.43),
                minsPerRing: appState.config.stopwatchMinsPerRing,
                ridingPose: appState.session.sessionType == .break
                    ? nil
                    : stopwatchRiderPose
            )

            VStack(spacing: 6) {
                if appState.session.sessionType == .break {
                    PommyMascot(
                        pose: .sleep,
                        size: 64,
                        cheekTint: Color(hex: "#7CB893"),
                        cadence: .hero,
                        activityMode: appState.effectiveAnimationMode
                    )
                        .frame(height: 70)
                } else if isStopwatchHardMode {
                    PommyMascot(
                        pose: .focusHard,
                        size: 64,
                        cheekTint: appState.config.color(for: appState.session.category),
                        cadence: .hero,
                        activityMode: appState.effectiveAnimationMode
                    )
                    .frame(height: 70)
                }

                Text(formatElapsed(appState.session.elapsedSeconds))
                    .font(.system(
                        size: (appState.session.sessionType == .break || isStopwatchHardMode) ? 32 : 56,
                        weight: .ultraLight
                    ).monospacedDigit())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(stopwatchCenterCaption)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary.opacity(0.7))
                if !appState.session.task.isEmpty {
                    Text(appState.session.task)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(stopwatchMilestone)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(appState.config.color(for: appState.session.category))
                    .opacity(stopwatchMilestone.isEmpty ? 0 : 0.85)
                    .id(stopwatchMilestone)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: stopwatchMilestone)
                    .padding(.top, 4)
            }
            .padding(.top, 18)

            Spacer(minLength: 16)

            runningControls
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    /// True once the focus stopwatch elapsed crosses 75 minutes; we treat
    /// this as the "extra effort" zone so Pommy puts on the headband.
    private var isStopwatchHardMode: Bool {
        appState.session.sessionType == .focus &&
            appState.session.elapsedSeconds >= 75 * 60
    }

    private var stopwatchRiderPose: MascotPose {
        if appState.session.state == .focusPaused { return .curious }
        return isStopwatchHardMode ? .focusHard : .focus
    }

    private var stopwatchCenterCaption: String {
        if appState.session.sessionType == .break { return "break" }
        return isStopwatchHardMode ? "extra effort" : "focus"
    }

    /// Milestone copy for the open-ended stopwatch. Phrased as soft check-ins
    /// rather than progress markers since there's no target.
    private var stopwatchMilestone: String {
        guard appState.session.sessionType == .focus else { return "" }
        let mins = appState.session.elapsedSeconds / 60
        switch mins {
        case ..<5:    return ""
        case 5..<15:  return "Easing in..."
        case 15..<30: return "Getting into it"
        case 30..<50: return "You're deep in it now"
        case 50..<75: return "This is an elite session"
        default:      return ""
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var runningControls: some View {
        switch appState.session.state {
        case .focusRunning, .breakRunning:
            HStack(spacing: 16) {
                ctrlBtn("pause.fill", "Pause") { appState.session.pause() }
                ctrlBtn("stop.fill",  "Stop")  { appState.requestStop() }
            }
        case .focusPaused, .breakPaused:
            HStack(spacing: 16) {
                ctrlBtn("play.fill", "Resume") { appState.session.resume() }
                ctrlBtn("stop.fill", "Stop")   { appState.requestStop() }
            }
        default:
            EmptyView()
        }
    }

    private func ctrlBtn(_ symbol: String, _ tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(Surface.topHighlight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pommyPress()
        .help(tip)
    }

    // MARK: - Idle sub-views

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.config.categories, id: \.self) { cat in
                    let sel = cat == selectedCat
                    let col = appState.config.color(for: cat)
                    Button {
                        withAnimation(Motion.springSnap) { selectedCat = cat }
                    } label: {
                        Text(cat)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(sel ? .white : .secondary)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(
                                ZStack {
                                    if sel {
                                        Capsule().fill(col.verticalGradient)
                                    } else {
                                        Capsule().fill(Surface.hairline)
                                    }
                                }
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        sel ? Surface.innerHighlight : Surface.fillFaint,
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: sel ? col.opacity(0.32) : .clear, radius: sel ? 10 : 0, y: sel ? 3 : 0)
                    }
                    .buttonStyle(.plain)
                    .pommyPress()
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var taskField: some View {
        TextField("What are we doing today?", text: $task)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Surface.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Surface.fillFaint, lineWidth: 1)
            )
    }

    private func startBtn(type: SessionType) -> some View {
        let isFocus = type == .focus
        let color: Color = isFocus
            ? appState.config.color(for: selectedCat)
            : Color(white: 0.5)
        let label = isFocus ? "Focus" : "Break"
        let icon  = isFocus ? "target" : "cup.and.saucer.fill"

        return Button {
            launchSession(type: type)
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(color.verticalGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Surface.innerHighlight, lineWidth: 1)
                )
                .shadow(color: color.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .pommyPress()
    }

    @ViewBuilder
    private var quickShortcut: some View {
        let prevState = appState.session.state
        if prevState == .afterFocusSaved || prevState == .idle {
            Button {
                appState.session.targetSeconds = Self.openEndedTarget
                appState.takeBreak(category: selectedCat)
            } label: {
                Label("Take a break", systemImage: "cup.and.saucer.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Surface.hairline, in: Capsule())
            }
            .buttonStyle(.plain)
        } else if prevState == .afterBreakSaved {
            Button {
                launchSession(type: .focus)
            } label: {
                Label("Start focus", systemImage: "target")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Surface.hairline, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func launchSession(type: SessionType) {
        appState.session.targetSeconds = Self.openEndedTarget
        appState.isStopwatchSession    = true
        if type == .focus {
            appState.startFocus(category: selectedCat, task: task, breatheFirst: false)
        } else {
            appState.takeBreak(category: selectedCat)
        }
    }

    private func syncFromConfig() {
        selectedCat = appState.config.defaultCategory
        task = ""
    }

    // MARK: - Elapsed formatter

    private func formatElapsed(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
