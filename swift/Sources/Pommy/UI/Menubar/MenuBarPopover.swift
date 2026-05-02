import SwiftUI

/// Content shown in the menubar popover when the user clicks the menubar item.
@MainActor
struct MenuBarPopover: View {
    @Environment(AppState.self) private var appState

    private var isIdle: Bool {
        appState.session.state == .idle ||
        appState.session.state == .afterFocusSaved ||
        appState.session.state == .afterBreakSaved
    }

    private var brandTint: Color {
        let key = appState.session.state == .idle
            ? appState.config.defaultCategory
            : appState.session.category
        return appState.config.color(for: key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PommyDivider(axis: .horizontal, inset: 10)
            statsRows
            if isIdle {
                PommyDivider(axis: .horizontal, inset: 10)
                quickStartRow
            }
            PommyDivider(axis: .horizontal, inset: 10)
            footer
        }
        .frame(width: 240)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isIdle {
                currentSessionView
            } else {
                HStack(spacing: 10) {
                    Image(nsImage: {
                        let copy = NSApp.applicationIconImage.copy() as! NSImage
                        copy.size = NSSize(width: 28, height: 28)
                        return copy
                    }())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pommy")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(.primary)
                        Text("Waiting patiently up here")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if appState.credentials != nil {
                        syncDot
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var currentSessionView: some View {
        HStack(spacing: 8) {
            // Category-tinted left edge
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(sessionDotColor)
                .frame(width: 2, height: 28)
                .shadow(color: sessionDotColor.opacity(0.4), radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(sessionStatusLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if !appState.session.task.isEmpty {
                    Text(appState.session.task)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(timerLabel)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.85))
        }
    }

    // MARK: - Sync dot (B5)

    @ViewBuilder
    private var syncDot: some View {
        switch appState.syncDotState {
        case .ok:
            Circle()
                .fill(Color.green.opacity(0.75))
                .frame(width: 7, height: 7)
                .help("Synced with Notion")
        case .pending:
            Circle()
                .fill(Color.yellow.opacity(0.85))
                .frame(width: 7, height: 7)
                .help("Syncing with Notion…")
        case .failed(let m):
            Circle()
                .fill(Color.red.opacity(0.75))
                .frame(width: 7, height: 7)
                .help("Sync failed: \(m)")
                .onTapGesture {
                    NSApp.windows
                        .first(where: { $0.identifier?.rawValue == "main" })?
                        .makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    appState.selectedPage = .settings
                }
        }
    }

    // MARK: - Stats rows

    private var statsRows: some View {
        VStack(spacing: 0) {
            statRow(label: "Today", value: formatMins(todayTotal))
            statRow(label: "This week", value: formatMins(weekTotal))
            let streak = appState.sessionLog.focusStreak(minMinutes: appState.config.streakMinMinutes)
            if streak > 0 {
                streakRow(streak)
            }
        }
        .padding(.vertical, 4)
    }

    private func streakRow(_ streak: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                rowIcon("flame.fill", color: .orange)
                Text("Streak")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(streak) \(streak == 1 ? "day" : "days")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                rowIcon(label == "Today" ? "sun.max.fill" : "calendar", color: .secondary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func rowIcon(_ symbol: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 18, height: 18)
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Quick-start row (idle only)

    private var quickStartRow: some View {
        Button {
            openMainWindow()
            appState.startFocus(
                category:    appState.config.defaultCategory,
                task:        "",
                breatheFirst: false
            )
        } label: {
            HStack(spacing: 10) {
                rowIcon("target", color: brandTint)
                Text("Start Focus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(appState.config.focusDuration)m")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(brandTint.verticalGradient)
                    )
                    .shadow(color: brandTint.opacity(0.35), radius: 6, y: 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.0, pressScale: 0.98)
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            openMainWindow()
        } label: {
            HStack {
                Text("Open Pommy")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.0, pressScale: 0.98)
    }

    // MARK: - Computed values

    private var todayTotal: Int {
        let local  = appState.sessionLog.todayFocusMinutes
        let notion = appState.notionStats?.todayFocusMinutes ?? 0
        return max(local, notion)
    }

    private var weekTotal: Int {
        let local  = appState.sessionLog.entries(forLastDays: 7)
            .filter(\.isFocus)
            .reduce(0) { $0 + $1.duration_mins }
        let notion = appState.notionStats?.weekFocusMinutes ?? 0
        return max(local, notion)
    }

    private var sessionDotColor: Color {
        switch appState.session.state {
        case .focusRunning, .focusOverflow: return appState.config.color(for: appState.session.category)
        case .focusPaused:                  return appState.config.color(for: appState.session.category).opacity(0.5)
        case .breakRunning, .breakOverflow: return Color(white: 0.43)
        default:                            return .clear
        }
    }

    private var sessionStatusLabel: String {
        switch appState.session.state {
        case .focusRunning, .focusOverflow: return "\(appState.session.category) · Focus"
        case .focusPaused:                  return "Paused (you okay?)"
        case .breakRunning, .breakOverflow: return "Break time"
        case .breakPaused:                  return "Break · also paused?"
        case .breathing:                    return "Breathing…"
        default:                            return "Pommy"
        }
    }

    private var timerLabel: String {
        let s = appState.session
        if s.isOverflow {
            return "+\(format(s.overflowSeconds))"
        }
        return format(s.remainingSeconds)
    }

    private func format(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private func formatMins(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - Window

    private func openMainWindow() {
        NSApp.windows
            .first(where: { $0.title == "Pommy" || $0.identifier?.rawValue == "main" })?
            .makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
