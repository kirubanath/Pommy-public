import SwiftUI

/// Shown whenever no session is running.
/// Lets the user pick a category, set the dial, enter a task, and start.
@MainActor
struct IdleView: View {
    @Environment(AppState.self) private var appState

    @State private var dialMinutes:  Int         = 50
    @State private var dialType:     SessionType = .focus
    @State private var selectedCat:  String      = "Work"
    @State private var task:         String      = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                        .padding(.bottom, 4)

                    categoryPills

                    DialView(
                        minutes:       $dialMinutes,
                        sessionType:   $dialType,
                        categoryColor: appState.config.color(for: selectedCat),
                        maxMinutes:    appState.config.dialMaxMinutes
                    )

                    presetRow

                    taskField

                    startButton

                    quickShortcut
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }

            // Calm Pommy peeking from the bottom-right corner. Tap for a quip.
            PommyMascot(
                pose: .peek,
                size: 56,
                cheekTint: appState.config.color(for: selectedCat),
                chatty: true
            )
            .opacity(0.85)
            .padding(.trailing, 18)
            .padding(.bottom, 14)
            .transition(.opacity)
        }
        .onAppear { syncFromConfig() }
        .onChange(of: appState.session.state) { _, new in
            if new == .idle { syncFromConfig() }
        }
        // Config loads asynchronously after the view first appears. Re-sync
        // so the default category becomes selected once it's actually known.
        .onChange(of: appState.config.defaultCategory) { _, _ in
            if appState.session.state == .idle { syncFromConfig() }
        }
        .onChange(of: appState.config.categories) { _, _ in
            if appState.session.state == .idle,
               !appState.config.categories.contains(selectedCat) {
                syncFromConfig()
            }
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
        case 5..<12:  return "What chaos are we creating today?"
        case 12..<17: return "Still going? Respect."
        case 17..<22: return "One last push, you've got this"
        default:      return "You're still up. That's your call."
        }
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.config.categories, id: \.self) { cat in
                    categoryPill(cat)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func categoryPill(_ cat: String) -> some View {
        let isSelected = cat == selectedCat
        let color      = appState.config.color(for: cat)
        return Button {
            withAnimation(Motion.springSnap) { selectedCat = cat }
        } label: {
            Text(cat)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule().fill(color.verticalGradient)
                        } else {
                            Capsule().fill(Surface.hairline)
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Surface.innerHighlight : Surface.fillFaint,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? color.opacity(0.35) : .clear,
                    radius: isSelected ? 12 : 0,
                    y: isSelected ? 4 : 0
                )
        }
        .buttonStyle(.plain)
        .pommyPress()
    }

    // MARK: - Preset row (below the dial)

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(appState.config.focusPresets, id: \.self) { p in
                let active = dialMinutes == p && dialType == .focus
                Button {
                    withAnimation(Motion.springSnap) {
                        dialMinutes = p
                        dialType    = .focus
                    }
                } label: {
                    Text("\(p)m")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(active ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(active ? Surface.fillStrong : Surface.fillFaint)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(active ? Surface.fillStrong : Surface.fillFaint, lineWidth: 1)
                        )
                        .scaleEffect(active ? 1.0 : 1.0)
                }
                .buttonStyle(.plain)
                .pommyPress()
            }
        }
    }

    // MARK: - Task field

    private var lastTaskForCategory: String {
        appState.sessionLog.entries
            .filter { $0.category == selectedCat && !$0.task.isEmpty }
            .last?.task ?? ""
    }

    @ViewBuilder
    private var taskField: some View {
        let hint = lastTaskForCategory
        TextField(
            hint.isEmpty ? "What are we doing today?" : hint,
            text: $task
        )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Surface.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Surface.fillFaint, lineWidth: 1)
            )
            .onSubmit { startSession() }
    }

    // MARK: - Primary start button

    @State private var ctaBreath: Bool = false

    private var startButton: some View {
        Button(action: startSession) {
            HStack(spacing: 10) {
                Text(dialType == .focus ? "Start Focus" : "Start Break")
                    .font(.system(size: 15, weight: .semibold))
                /// Text("Space")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Surface.innerHighlight)
                    )
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(primaryColor.verticalGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Surface.innerHighlight, lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: primaryColor.opacity(0.45), radius: 18, y: 8)
            .scaleEffect(ctaBreath ? 1.012 : 1.0)
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.015, pressScale: 0.985)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                ctaBreath = true
            }
        }
    }

    private var primaryColor: Color {
        dialType == .focus
            ? appState.config.color(for: selectedCat)
            : Color(white: 0.43)
    }

    // MARK: - Quick shortcut (always visible, opposite mode)

    @ViewBuilder
    private var quickShortcut: some View {
        if dialType == .focus {
            Button { quickBreak() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                    Text("Take a break  ·  \(appState.config.breakDuration)m")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Start a \(appState.config.breakDuration)-minute break")
        } else {
            Button { quickFocus() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                    Text("Start focus  ·  \(appState.config.focusDuration)m")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Start a \(appState.config.focusDuration)-minute focus session")
        }
    }

    // MARK: - Actions

    private func startSession() {
        appState.session.targetSeconds = dialMinutes * 60
        if dialType == .focus {
            appState.startFocus(category: selectedCat, task: task)
        } else {
            appState.takeBreak(category: selectedCat)
        }
    }

    private func quickBreak() {
        appState.session.targetSeconds = appState.config.breakDuration * 60
        appState.takeBreak(category: selectedCat)
    }

    private func quickFocus() {
        appState.session.targetSeconds = appState.config.focusDuration * 60
        appState.startFocus(category: selectedCat, task: task)
    }

    private func syncFromConfig() {
        selectedCat = appState.config.defaultCategory
        dialMinutes = appState.config.focusDuration
        dialType    = .focus
        task        = ""
    }
}
