import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    enum Tab: String, CaseIterable, Identifiable {
        case clocks      = "Clocks"
        case categories  = "Categories"
        case mindfulness = "Mindfulness"
        case notion      = "Notion"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .clocks:      return "timer"
            case .categories:  return "tag.fill"
            case .mindfulness: return "leaf.fill"
            case .notion:      return "arrow.clockwise"
            }
        }
    }

    @State private var selectedTab: Tab = .clocks
    @Namespace private var settingsPillNS

    private var activeTint: Color {
        appState.config.color(for: appState.config.defaultCategory)
    }

    var body: some View {
        ZStack {
            AmbientAppBackground(tint: activeTint, intensity: 0.05)
                .ignoresSafeArea()

            HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.pommyLabel)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                ForEach(Tab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 168)
            .background(Surface.sidebar.opacity(0.7))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Surface.fillFaint)
                    .frame(width: 1)
            }

            Group {
                switch selectedTab {
                case .clocks:      SessionsSettings()
                case .categories:  CategorySettings()
                case .mindfulness: MindfulnessSettings()
                case .notion:      NotionSettings()
                }
            }
            .id(selectedTab)
            .transition(.opacity.combined(with: .offset(y: 4)))
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(Motion.springSnap) { selectedTab = tab }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(isSelected ? activeTint : Color.secondary.opacity(0.75))
                Text(tab.rawValue)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(activeTint.verticalGradient)
                            .opacity(0.18)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Surface.topHighlight, lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "settingsPill", in: settingsPillNS)
                    }
                }
            )
            .campGlow(active: isSelected, tint: activeTint, outerOpacity: 0.22, innerOpacity: 0.18)
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.0, pressScale: 0.97)
    }
}
