import SwiftUI

@MainActor
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var selectionNS

    var onShowShortcuts: (() -> Void)? = nil

    private var activeTint: Color {
        let key = appState.session.state == .idle
            ? appState.config.defaultCategory
            : appState.session.category
        return appState.config.color(for: key)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                pageButton(.timer)
                pageButton(.stopwatch)
                pageButton(.stats)
                pageButton(.mindfulness)
            }
            .padding(.top, 16)

            Spacer()

            syncButton
                .padding(.bottom, 8)

            pageButton(.settings)
                .padding(.bottom, 8)

            shortcutsButton
                .padding(.bottom, 14)
        }
        .frame(width: 64)
        .background(Surface.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Surface.fillFaint)
                .frame(width: 1)
        }
    }

    // MARK: - Page button

    private func pageButton(_ page: SidebarPage) -> some View {
        let active = appState.selectedPage == page
        return Button {
            withAnimation(Motion.springSnap) {
                appState.selectedPage = page
            }
        } label: {
            ZStack {
                if active {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(activeTint.verticalGradient)
                        .opacity(0.18)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Surface.topHighlight, lineWidth: 1)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: activeTint.opacity(0.25), radius: 8, y: 2)
                        .matchedGeometryEffect(id: "sidebarPill", in: selectionNS)
                }
                Image(systemName: page.sfSymbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(active ? Color.primary : Color.secondary.opacity(0.75))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(page.label)
        .pommyPress(hoverScale: 1.04, pressScale: 0.94)
    }

    // MARK: - Sync button

    private var syncButton: some View {
        Button {
            guard let creds = appState.credentials else { return }
            Task { await appState.syncNotionStats(creds: creds) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                if appState.notionSyncStatus == .syncing {
                    SpinningPommyBadge()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(syncIconColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.04, pressScale: 0.94)
        .help(syncHelp)
        .opacity(appState.credentials == nil ? 0.3 : 1)
        .disabled(appState.credentials == nil || appState.notionSyncStatus == .syncing)
    }

    private var syncIconColor: Color {
        switch appState.notionSyncStatus {
        case .failed:  return Color.red.opacity(0.75)
        case .synced:  return Color.green.opacity(0.75)
        default:       return .secondary
        }
    }

    /// Tiny curious Pommy that spins while a sync is in flight.
    private struct SpinningPommyBadge: View {
        @State private var rotation: Double = 0
        var body: some View {
            PommyMascot(pose: .curious, size: 22)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }

    // MARK: - Shortcuts button

    private var shortcutsButton: some View {
        Button {
            onShowShortcuts?()
        } label: {
            Text("?")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.55))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.04, pressScale: 0.94)
        .help("Keyboard shortcuts")
    }

    private var syncHelp: String {
        switch appState.notionSyncStatus {
        case .syncing:       return "Syncing…"
        case .synced:        return "Synced"
        case .failed(let m): return "Sync failed: \(m)"
        default:             return appState.credentials == nil ? "Hook up Notion first (Settings → Notion)" : "Push to Notion"
        }
    }
}
