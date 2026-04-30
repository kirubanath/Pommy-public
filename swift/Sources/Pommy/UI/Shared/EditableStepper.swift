import SwiftUI

/// A small numeric input that combines a typable text field with a stepper.
///
/// SwiftUI's `Stepper` is arrows-only; users can't type a value directly.
/// `EditableStepper` shows a text field for direct entry plus the stepper's
/// up/down buttons, clamps to `range` on commit, and calls `onCommit` whenever
/// the value actually changes (typed or stepped).
@MainActor
struct EditableStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""
    var fieldWidth: CGFloat = 60
    var onCommit: () -> Void = {}

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: fieldWidth)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focused)
                .onAppear { text = "\(value)" }
                .onChange(of: value) { _, newValue in
                    // Keep the field in sync when the stepper drives the change,
                    // but don't fight the user mid-edit.
                    if !focused { text = "\(newValue)" }
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .onSubmit { commit() }

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _, _ in onCommit() }
        }
    }

    private func commit() {
        if let parsed = Int(text.trimmingCharacters(in: .whitespaces)) {
            let clamped = min(max(parsed, range.lowerBound), range.upperBound)
            if clamped != value {
                value = clamped
                onCommit()
            }
            text = "\(clamped)"
        } else {
            // Invalid entry — revert to current value.
            text = "\(value)"
        }
    }
}
