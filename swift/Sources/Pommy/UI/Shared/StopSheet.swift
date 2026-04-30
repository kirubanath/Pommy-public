import SwiftUI

/// Slide-up save/discard sheet shown when the user taps ⏹ Stop.
/// Notes typed here are appended to the in-session notes before logging.
@MainActor
struct StopSheet: View {
    @Environment(AppState.self) private var appState
    @FocusState private var fieldFocused: Bool
    @State private var hoverState: HoverState = .none

    private enum HoverState { case none, save, discard }

    private var saveTint: Color {
        appState.session.sessionType == .focus
            ? appState.config.color(for: appState.session.category)
            : Color(white: 0.5)
    }

    private var reactiveTitle: String {
        switch hoverState {
        case .save:    return "Look at you go"
        case .discard: return "Yeet it into the void?"
        case .none:    return "How'd it go?"
        }
    }

    private var reactivePose: MascotPose {
        switch hoverState {
        case .save:    return .wave
        case .discard: return .sad
        case .none:    return .idle
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimming backdrop — swallows taps so user can't accidentally dismiss
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    PommyMascot(pose: reactivePose, size: 44)
                        .animation(.easeInOut(duration: 0.25), value: reactivePose)

                    Text(reactiveTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .id(reactiveTitle)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: reactiveTitle)

                ZStack(alignment: .topLeading) {
                    if appState.stopSheetNotes.isEmpty {
                        Text("Thoughts? Wins? Complaints? Whatever…")
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { appState.stopSheetNotes },
                        set: { appState.stopSheetNotes = $0 }
                    ))
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($fieldFocused)
                }
                .frame(height: 90)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Surface.sunken.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Surface.hairline, lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Button {
                        appState.discardSession()
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("Discard")
                                .font(.system(size: 13, weight: .medium))
                            Text("⌘D")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .keyboardShortcut("d", modifiers: .command)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .pommyPress()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoverState = hovering ? .discard
                                                  : (hoverState == .discard ? .none : hoverState)
                        }
                    }

                    Spacer()

                    Button {
                        Task { await appState.saveSession() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                            Text("⌘S")
                                .font(.system(size: 10, weight: .regular))
                                .opacity(0.65)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(saveTint.verticalGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Surface.innerHighlight, lineWidth: 1)
                        )
                        .shadow(color: saveTint.opacity(0.4), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("s", modifiers: .command)
                    .pommyPress()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoverState = hovering ? .save
                                                  : (hoverState == .save ? .none : hoverState)
                        }
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Surface.fillStrong, lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear { fieldFocused = true }
    }
}
