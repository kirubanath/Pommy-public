import SwiftUI

/// Right-panel top section — live notes textarea.
///
/// Written during a session, appended in the stop sheet, sent to Notion.
/// Clears when the next session starts (handled by AppState.startFocus).
@MainActor
struct NotesView: View {
    @Environment(AppState.self) private var appState

    @State private var saveBlinkVisible: Bool = false
    @State private var saveDebounceTask: Task<Void, Never>? = nil

    private var sessionTint: Color {
        appState.config.color(for: appState.session.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            editor
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            Text("Notes")
                .font(.pommyLabel)
                .foregroundStyle(Color.secondary.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            sessionContextBadge
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var sessionContextBadge: some View {
        let s = appState.session
        let isActive = s.state == .focusRunning || s.state == .focusOverflow ||
                       s.state == .focusPaused  || s.state == .breakRunning  ||
                       s.state == .breakOverflow || s.state == .breakPaused
        if isActive {
            HStack(spacing: 5) {
                Circle()
                    .fill(s.sessionType == .focus ? sessionTint : Color(white: 0.5))
                    .frame(width: 4, height: 4)
                Text(s.sessionType == .focus
                     ? "\(s.category) · \(s.durationMins)m"
                     : "Break · \(s.durationMins)m")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.75))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Surface.hairline, lineWidth: 1)
            )
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Defined panel surface
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Surface.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Surface.hairline, lineWidth: 1)
                )

            if appState.notes.isEmpty {
                Text("Notes, wins, complaints, big ideas…")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .padding(.top, 14)
                    .padding(.leading, 18)
                    .allowsHitTesting(false)
            }
            TextEditor(text: Binding(
                get: { appState.notes },
                set: { newValue in
                    appState.notes = newValue
                    scheduleSavedBlink()
                }
            ))
            .font(.system(size: 13))
            .lineSpacing(6)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            // Subtle save indicator: appears 350ms after typing pauses,
            // holds, then fades. No strobing during continuous input.
            Rectangle()
                .fill(sessionTint.opacity(0.6))
                .frame(height: 2)
                .padding(.horizontal, 12)
                .opacity(saveBlinkVisible ? 0.6 : 0.0)
                .animation(.easeInOut(duration: 0.45), value: saveBlinkVisible)
        }
    }

    /// Debounced "saved" pulse: cancels any pending blink, waits 350ms after
    /// the last keystroke, shows the indicator briefly, then hides it.
    private func scheduleSavedBlink() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            saveBlinkVisible = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            if Task.isCancelled { return }
            saveBlinkVisible = false
        }
    }
}
