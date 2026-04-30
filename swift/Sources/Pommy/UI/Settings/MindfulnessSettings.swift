import SwiftUI

@MainActor
struct MindfulnessSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                durationsCard
                ambientCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var durationsCard: some View {
        PommySectionCard("Durations") {
            PommySettingsRow("Breathing session") {
                EditableStepper(
                    value: Binding(
                        get: { appState.config.breatheDurationMins },
                        set: { appState.config.breatheDurationMins = $0 }
                    ),
                    range: 1...60,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
            PommyRowDivider()
            PommySettingsRow("Rest session") {
                EditableStepper(
                    value: Binding(
                        get: { appState.config.restDurationMins },
                        set: { appState.config.restDurationMins = $0 }
                    ),
                    range: 1...60,
                    unit: "min",
                    onCommit: { appState.saveConfig() }
                )
            }
        }
    }

    private var ambientCard: some View {
        PommySectionCard("Ambient sound") {
            // Segmented picker spans full width — its options are the label,
            // so a leading label would be redundant.
            VStack(alignment: .leading, spacing: 6) {
                Text("Sound")
                    .font(.system(size: 13))
                Picker("", selection: Binding(
                    get: { appState.config.ambientSound },
                    set: { appState.config.ambientSound = $0; appState.saveConfig() }
                )) {
                    ForEach(AmbientSound.allCases) { sound in
                        Text(sound.rawValue).tag(sound)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            PommyRowDivider()

            PommySettingsRow("Volume") {
                Slider(
                    value: Binding(
                        get: { appState.config.ambientVolume },
                        set: { appState.config.ambientVolume = $0 }
                    ),
                    in: 0...1
                ) {
                    EmptyView()
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill").font(.caption)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill").font(.caption)
                } onEditingChanged: { ended in
                    if ended { appState.saveConfig() }
                }
                .frame(width: 200)
            }
            .disabled(appState.config.ambientSound == .silence)
        }
    }
}
