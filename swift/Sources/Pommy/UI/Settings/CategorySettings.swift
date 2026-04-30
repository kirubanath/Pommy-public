import SwiftUI

@MainActor
struct CategorySettings: View {
    @Environment(AppState.self) private var appState

    @State private var newCatName: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                categoriesCard
                defaultCard
                addCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Cards

    private var categoriesCard: some View {
        PommySectionCard("Categories") {
            ForEach(Array(appState.config.categories.enumerated()), id: \.element) { idx, cat in
                if idx > 0 {
                    PommyRowDivider()
                }
                CategoryRow(
                    cat:       cat,
                    canDelete: appState.config.categories.count > 1,
                    onDelete:  { deleteCategory(cat) }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private var defaultCard: some View {
        PommySectionCard("Default") {
            PommySettingsRow("Default category") {
                Picker("", selection: Binding(
                    get: { appState.config.defaultCategory },
                    set: { appState.config.defaultCategory = $0; appState.saveConfig() }
                )) {
                    ForEach(appState.config.categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }

    private var addCard: some View {
        PommySectionCard("Add category") {
            HStack(spacing: 10) {
                TextField("New category name", text: $newCatName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Surface.fillFaint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Surface.hairline, lineWidth: 1)
                    )
                    .onSubmit { addCategory() }

                Button("Add") { addCategory() }
                    .disabled(
                        newCatName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        appState.config.categories.contains(newCatName.trimmingCharacters(in: .whitespaces))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Mutations

    private func addCategory() {
        let name = newCatName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !appState.config.categories.contains(name) else { return }
        appState.config.categories = appState.config.categories + [name]
        appState.config.assignMissingColors()
        appState.saveConfig()
        newCatName = ""
    }

    private func deleteCategory(_ cat: String) {
        var cats = appState.config.categories
        cats.removeAll { $0 == cat }
        appState.config.categories = cats

        if !cats.contains(appState.config.defaultCategory) {
            appState.config.defaultCategory = cats.first ?? "General"
        }
        appState.saveConfig()
    }
}

// MARK: - Editable row

@MainActor
private struct CategoryRow: View {
    let cat:       String
    let canDelete: Bool
    let onDelete:  () -> Void

    @Environment(AppState.self) private var appState

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Swatch box — opens curated palette popover.
            CategoryColorPicker(color: Binding(
                get: { appState.config.color(for: cat) },
                set: { newColor in
                    appState.config.categoryColors[cat] = newColor
                    appState.saveConfig()
                }
            ))

            nameField

            // Delete — removes the whole row (swatch + name).
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove \(cat)")
            .disabled(!canDelete)
            .opacity(canDelete ? 1 : 0.25)
        }
    }

    private var nameField: some View {
        let tint = appState.config.color(for: cat)
        let bg = focused ? Surface.hairline : Surface.fillFaint
        let stroke = focused ? Surface.innerHighlight : Surface.fillFaint

        return TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .lineLimit(1)
            .focused($focused)
            .onAppear { draft = cat }
            .onChange(of: cat) { _, newCat in
                if !focused { draft = newCat }
            }
            .onSubmit { commit() }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .campGlow(active: focused, tint: tint, outerRadius: 8, innerRadius: 4, outerOpacity: 0.18, innerOpacity: 0.14)
            .animation(.easeInOut(duration: 0.12), value: focused)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == cat {
            draft = cat
            return
        }
        let accepted = appState.renameCategory(from: cat, to: trimmed)
        if !accepted {
            // Rejected (duplicate, etc.) — revert silently.
            draft = cat
        }
    }
}

// MARK: - Curated color picker

/// A small swatch button that opens a popover grid of curated colors —
/// Apple Reminders / Calendar style. Each row is one hue at light / medium /
/// deep saturation; the active swatch wears a thin ring.
@MainActor
private struct CategoryColorPicker: View {
    @Binding var color: Color
    @State private var showing: Bool = false

    private static let palette: [[String]] = [
        ["E0A8A8", "C76B6B", "924242"], // rose
        ["E5BC8E", "C9974A", "9C7028"], // amber
        ["CFC487", "A89A4F", "7C6F2E"], // olive
        ["9EC9A4", "6A9E72", "4A7C56"], // green
        ["8FC2B5", "5BA290", "3A7062"], // teal
        ["8FB7DA", "5B8DB8", "3F6E94"], // blue
        ["AC9DDB", "7867A5", "574881"], // lavender
        ["C0AAD3", "9277A8", "6F5B7C"], // plum
        ["D0D0D0", "9B9B9B", "6A6A6A"]  // grey
    ]

    private var currentHex: String {
        color.hexString.uppercased().replacingOccurrences(of: "#", with: "")
    }

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .leading) {
            VStack(spacing: 8) {
                ForEach(Self.palette.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(Self.palette[row], id: \.self) { hex in
                            swatch(hex: hex)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func swatch(hex: String) -> some View {
        let isSelected = hex.uppercased() == currentHex
        let c = Color(hex: hex)
        return Button {
            color   = c
            showing = false
        } label: {
            Circle()
                .fill(c)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.primary.opacity(0.85) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .padding(2)
        }
        .buttonStyle(.plain)
    }
}
