import SwiftUI

/// Left panel — session controls with animated colour-tinted background.
///
/// The background tint transitions smoothly between:
/// - Idle / afterBreakSaved  → faint default-category tint (12 % opacity)
/// - Focus running / overflow → stronger category tint (20 % opacity)
/// - Focus paused             → mid category tint (15 % opacity)
/// - Break running / overflow → grey tint (15 % opacity)
/// - afterFocusSaved          → soft category tint (10 % opacity)
@MainActor
struct TimerPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var showFirstSessionCelebration: Bool = false

    var body: some View {
        ZStack {
            // Animated tinted background
            panelBackground
                .animation(.easeInOut(duration: 0.5), value: appState.session.state)
                .animation(.easeInOut(duration: 0.5), value: appState.session.category)

            // Content layer
            Group {
                switch appState.session.state {
                case .idle, .afterFocusSaved, .afterBreakSaved:
                    IdleView()
                        .transition(.opacity)
                case .breathing:
                    if appState.isStopwatchSession {
                        blockedByStopwatchView
                            .transition(.opacity)
                    } else {
                        BreathingGateView()
                            .transition(.opacity)
                    }
                default:
                    if appState.isStopwatchSession {
                        blockedByStopwatchView
                            .transition(.opacity)
                    } else {
                        RunningView()
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: stateGroup)

            // Stop sheet overlay
            if appState.showStopSheet {
                StopSheet()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            // ✓ Saved confirmation banner with a tiny waving Pommy
            if appState.showSavedConfirmation {
                VStack {
                    HStack(spacing: 10) {
                        PommyMascot(
                            pose: .wave,
                            size: 28,
                            cheekTint: appState.config.color(for: currentCategory),
                            cadence: .decorative,
                            activityMode: appState.effectiveAnimationMode
                        )
                        .frame(height: 28)
                        Text("Saved")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Surface.topHighlight, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    Spacer()
                }
                .padding(.top, 18)
                .zIndex(20)
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.showSavedConfirmation)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.showStopSheet)
        .overlay {
            if showFirstSessionCelebration {
                FirstSessionCelebration(tint: appState.config.color(for: currentCategory)) {
                    withAnimation(.easeOut(duration: 0.4)) { showFirstSessionCelebration = false }
                }
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .onChange(of: appState.showSavedConfirmation) { _, isShown in
            guard isShown else { return }
            maybeTriggerFirstSessionCelebration()
        }
    }

    private func maybeTriggerFirstSessionCelebration() {
        guard !UserDefaults.standard.hasCelebratedFirstSession else { return }
        guard appState.session.state == .afterFocusSaved else { return }
        let focusCount = appState.sessionLog.entries.filter(\.isFocus).count
        guard focusCount == 1 else { return }

        UserDefaults.standard.hasCelebratedFirstSession = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showFirstSessionCelebration = true
            }
        }
    }

    // MARK: - Background

    private var panelBackground: some View {
        // A soft category wash that fills the whole pane (so colors don't
        // wash out at the bottom), brighter at the top to read as "lit from
        // above".
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
        case .focusRunning, .focusOverflow:   return 0.20
        case .focusPaused:                    return 0.15
        case .afterFocusSaved:                return 0.10
        case .breakRunning, .breakOverflow:   return 0.15
        case .breakPaused:                    return 0.10
        default:                              return 0.12
        }
    }

    private var currentCategory: String {
        appState.session.state == .idle || appState.session.state == .afterBreakSaved
            ? appState.config.defaultCategory
            : appState.session.category
    }

    // Reduces re-animation churn — only animate on major group transitions.
    private var stateGroup: Int {
        switch appState.session.state {
        case .idle, .afterFocusSaved, .afterBreakSaved: return 0
        case .breathing:                                 return appState.isStopwatchSession ? 3 : 1
        default:                                         return appState.isStopwatchSession ? 3 : 2
        }
    }

    private var blockedByStopwatchView: some View {
        VStack(spacing: 20) {
            PommyMascot(
                pose: .curious,
                size: 52,
                cadence: .hero,
                activityMode: appState.effectiveAnimationMode
            )
            VStack(spacing: 6) {
                Text("Stopwatch is running.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                Text("Stop it there before starting a timer.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button {
                withAnimation(Motion.springSoft) { appState.selectedPage = .stopwatch }
            } label: {
                Label("Go to stopwatch", systemImage: "stopwatch")
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
}

/// Full-panel one-time overlay celebrating a user's very first focus session.
/// Auto-dismisses; tapping anywhere also closes it.
@MainActor
private struct FirstSessionCelebration: View {
    let tint: Color
    let onDismiss: () -> Void

    @State private var burst: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                ZStack {
                    PetalBurst(trigger: burst ? 1 : 0, color: tint)
                    PommyMascot(
                        pose: .celebrate,
                        size: 120,
                        cheekTint: tint,
                        cadence: .hero,
                        activityMode: .full
                    )
                }
                .frame(width: 180, height: 180)

                Text("You did the thing!")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.primary)

                Text("Pommy is unreasonably proud of you right now.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button {
                    onDismiss()
                } label: {
                    Text("Let's do another")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(tint.verticalGradient)
                        )
                        .shadow(color: tint.opacity(0.4), radius: 12, y: 5)
                }
                .buttonStyle(.plain)
                .pommyPress()
                .padding(.top, 6)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Surface.fillStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { onDismiss() }
        }
    }
}
