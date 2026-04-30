import SwiftUI

/// Press `?` (shift+/) anywhere in the app to toggle a glassy cheat sheet
/// of all keyboard shortcuts.
@MainActor
struct ShortcutOverlay: View {
    let onDismiss: () -> Void

    private let groups: [Group] = [
        Group(title: "Session", items: [
            Item(keys: ["Space"], description: "Start / pause"),
            Item(keys: ["⌘", "."], description: "Stop session"),
            Item(keys: ["⌘", "S"], description: "Save (in stop sheet)"),
            Item(keys: ["⌘", "D"], description: "Discard (in stop sheet)"),
            Item(keys: ["esc"], description: "Skip breathing (coward)")
        ]),
        Group(title: "App", items: [
            Item(keys: ["⌘", ","], description: "Open settings"),
            Item(keys: ["?"],       description: "Close this very thing")
        ])
    ]

    struct Group { let title: String; let items: [Item] }
    struct Item  { let keys: [String]; let description: String }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Shortcuts (you seem like the type)")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Surface.topHighlight))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                ForEach(groups.indices, id: \.self) { i in
                    let g = groups[i]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(g.title)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary.opacity(0.65))
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(g.items.indices, id: \.self) { j in
                                shortcutRow(g.items[j])
                            }
                        }
                    }
                }
            }
            .padding(22)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Surface.fillStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func shortcutRow(_ item: Item) -> some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(item.keys, id: \.self) { k in
                    keyCap(k)
                }
            }
            Spacer()
            Text(item.description)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(.vertical, 2)
    }

    private func keyCap(_ k: String) -> some View {
        Text(k)
            .font(.system(size: 11, weight: .medium).monospaced())
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Surface.fillStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Surface.hairline, lineWidth: 1)
            )
    }
}
