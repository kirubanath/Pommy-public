import SwiftUI

/// Consolidated settings for all session types — timer, stopwatch, and streak.
@MainActor
struct SessionsSettings: View {
    @Environment(AppState.self) private var appState

    private let ringOptions     = [10, 15, 20, 25, 30, 45, 60]
    private let dialMaxOptions  = [60, 120, 180, 240]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                timerCard
                presetsCard
                breathingCard
                stopwatchCard
                streakCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Cards

    private var timerCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Timer") {
            PommySettingsRow("Focus duration") {
                EditableStepper(
                    value: $config.focusDuration,
                    range: 1...120,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Break duration") {
                EditableStepper(
                    value: $config.breakDuration,
                    range: 1...60,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Min. to log") {
                EditableStepper(
                    value: $config.minSessionMinutes,
                    range: 0...60,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Overflow warning") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { config.overflowWarning },
                        set: { config.overflowWarning = $0; appState.saveConfig() }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
            PommyRowDivider()
            PommySettingsRow("Dial max") {
                Picker("", selection: $config.dialMaxMinutes) {
                    ForEach(dialMaxOptions, id: \.self) { mins in
                        Text(dialMaxLabel(mins)).tag(mins)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: config.dialMaxMinutes) { _, _ in
                    appState.saveConfig()
                }
            }
        }
    }

    private var presetsCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Quick Presets") {
            ForEach(config.focusPresets.indices, id: \.self) { i in
                if i > 0 { PommyRowDivider() }
                PommySettingsRow("Preset \(i + 1)") {
                    EditableStepper(
                        value: Binding(
                            get: { config.focusPresets[i] },
                            set: { config.focusPresets[i] = $0 }
                        ),
                        range: 1...120,
                        unit: "min",
                        fieldWidth: 64,
                        onCommit: { appState.saveConfig() }
                    )
                }
            }
        }
    }

    private var breathingCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Pre-focus Breathing") {
            PommySettingsRow("Breathe before focus") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { config.breatheBeforeFocus },
                        set: { config.breatheBeforeFocus = $0; appState.saveConfig() }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
            if config.breatheBeforeFocus {
                PommyRowDivider()
                PommySettingsRow("Breath cycles") {
                    EditableStepper(
                        value: $config.breathCycles,
                        range: 1...20,
                        onCommit: { appState.saveConfig() }
                    )
                }
            }
        }
    }

    private var stopwatchCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Stopwatch Rings") {
            PommySettingsRow("Minutes per ring") {
                Picker("", selection: $config.stopwatchMinsPerRing) {
                    ForEach(ringOptions, id: \.self) { mins in
                        Text("\(mins) min").tag(mins)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: config.stopwatchMinsPerRing) { _, _ in
                    appState.saveConfig()
                }
            }
        }
    }

    private var streakCard: some View {
        @Bindable var config = appState.config
        return PommySectionCard("Streak") {
            PommySettingsRow("Min. focus to count") {
                EditableStepper(
                    value: $config.streakMinMinutes,
                    range: 5...120,
                    step: 5,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Daily target") {
                EditableStepper(
                    value: Binding(
                        get: { config.dailyFocusTargetMins / 60 },
                        set: { config.dailyFocusTargetMins = $0 * 60 }
                    ),
                    range: 1...12,
                    unit: "h",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Per-day goals") {
                Toggle("", isOn: $config.perDayGoalsEnabled)
                    .labelsHidden()
                    .onChange(of: config.perDayGoalsEnabled) { _, _ in
                        appState.saveConfig()
                    }
            }
            if config.perDayGoalsEnabled {
                perDayGoalRows(config: config)
            }
            PommyRowDivider()
            PommySettingsRow("Weekly target") {
                EditableStepper(
                    value: Binding(
                        get: { config.weeklyFocusTargetMins / 60 },
                        set: { config.weeklyFocusTargetMins = $0 * 60 }
                    ),
                    range: 5...60,
                    unit: "h",
                    onCommit: { appState.saveConfig() }
                )
            }
        }
    }

    @ViewBuilder
    private func perDayGoalRows(config: Config) -> some View {
        // Calendar.weekday: 1=Sun, 2=Mon … 7=Sat
        let days: [(Int, String)] = [
            (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
            (5, "Thursday"), (6, "Friday"), (7, "Saturday"), (1, "Sunday")
        ]
        ForEach(days, id: \.0) { weekday, label in
            PommyRowDivider()
            PommySettingsRow(label) {
                EditableStepper(
                    value: Binding(
                        get: { (config.dailyFocusTargetByWeekday[weekday] ?? config.dailyFocusTargetMins) / 60 },
                        set: { config.dailyFocusTargetByWeekday[weekday] = $0 * 60 }
                    ),
                    range: 1...12,
                    unit: "h",
                    onCommit: { appState.saveConfig() }
                )
            }
        }
    }

    private func dialMaxLabel(_ mins: Int) -> String {
        let h = mins / 60
        return h == 1 ? "1 hour" : "\(h) hours"
    }
}
