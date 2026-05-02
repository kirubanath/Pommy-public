import Foundation
import SwiftUI

enum AnimationActivityMode: Equatable {
    case full
    case throttled
    case frozen
}

// MARK: - Sidebar page

enum SidebarPage: String, CaseIterable, Identifiable {
    case timer       = "timer"
    case stopwatch   = "stopwatch"
    case stats       = "chart.bar.fill"
    case mindfulness = "sparkles"
    case settings    = "gearshape.fill"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .timer:       return "Timer"
        case .stopwatch:   return "Stopwatch"
        case .stats:       return "Stats"
        case .mindfulness: return "Mindfulness"
        case .settings:    return "Settings"
        }
    }

    var sfSymbol: String {
        switch self {
        case .mindfulness: return "leaf.fill"
        default:           return rawValue
        }
    }
}

// MARK: - Notion sync status

enum NotionSyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed(String)
}

// MARK: - Sync dot state (B5)

enum SyncDotState: Equatable {
    case ok
    case pending
    case failed(String)
}

struct NotionStats {
    var todayFocusMinutes: Int
    var weekFocusMinutes:  Int
    var rawResults:        [NotionSessionResult]
}

// MARK: - AppState

/// Single source of truth shared by every view and the menubar item.
/// Injected into the view hierarchy via `.environment(appState)`.
@Observable @MainActor
final class AppState {

    // MARK: Sub-models

    let config     = Config()
    let session    = TimerSession()
    let sessionLog = SessionLog()

    private var systemFeedback: SystemFeedback?
    private var feedbackTimer:  Timer?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var didRegisterLifecycleObservers = false
    private var launchTaskStarted = false
    private var autoSyncTask: Task<Void, Never>?

    var credentials: NotionCredentials? = nil
    var isAppActive: Bool = true
    var isMainWindowVisible: Bool = true
    var isMainWindowKey: Bool = true

    var effectiveAnimationMode: AnimationActivityMode {
        if !isAppActive || !isMainWindowVisible { return .frozen }
        if !isMainWindowKey { return .throttled }
        return .full
    }

    var syncDotState: SyncDotState {
        if case .failed(let m) = notionSyncStatus { return .failed(m) }
        if notionSyncStatus == .syncing || sessionLog.pendingPushCount > 0 { return .pending }
        return .ok
    }

    func reportOutboxError(_ message: String) {
        notionSyncStatus = .failed(message)
    }

    // MARK: Navigation

    var selectedPage: SidebarPage = .timer

    // MARK: In-session notes

    /// Live notes — accumulated during the session, appended in the stop
    /// sheet, sent to Notion on save. Cleared when the next session starts.
    var notes: String = ""

    // MARK: Stop sheet

    var showStopSheet:  Bool   = false
    var stopSheetNotes: String = ""

    // MARK: Session source

    /// True when the running session was launched from the stopwatch panel.
    /// Lets each panel show its own idle/running UI without cross-contamination.
    var isStopwatchSession: Bool = false

    // MARK: Save confirmation

    /// True for ~1.2 s after a session is saved — drives the ✓ Saved banner.
    var showSavedConfirmation: Bool = false

    // MARK: Notion sync

    var notionSyncStatus: NotionSyncStatus = .idle
    var notionStats:      NotionStats?     = nil

    // MARK: - Launch

    func onLaunch() async {
        guard !launchTaskStarted else {
            refreshActivityStateFromSystem()
            handleActivityModeTransition()
            return
        }
        launchTaskStarted = true

        do {
            try AppPaths.ensureDirectoriesExist()
            try config.load()
        } catch {
            // First launch — settings.json absent; defaults already populated.
        }

        credentials           = NotionCredentialsStore.load()
        session.targetSeconds = config.focusDuration * 60

        await sessionLog.load()
        await NotionOutbox.shared.configure(appState: self)

        if let creds = credentials {
            await syncNotionStats(creds: creds)
        } else {
            Task.detached { await NotionOutbox.shared.kick() }
        }

        startAutoSync()
        startSystemFeedback()
        observeAppLifecycle()
        refreshActivityStateFromSystem()
        handleActivityModeTransition()
    }

    private func observeAppLifecycle() {
        guard !didRegisterLifecycleObservers else { return }
        didRegisterLifecycleObservers = true

        let resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isAppActive = false
                self?.handleActivityModeTransition()
            }
        }
        lifecycleObservers.append(resignObserver)

        let becomeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isAppActive = true
                self?.handleActivityModeTransition()
            }
            Task.detached { await NotionOutbox.shared.kick() }
        }
        lifecycleObservers.append(becomeObserver)
    }

    func pauseUITickers() {
        feedbackTimer?.invalidate()
        feedbackTimer = nil
    }

    func resumeUITickers() {
        guard feedbackTimer == nil else { return }
        scheduleFeedbackTimer()
        systemFeedback?.tick()
    }

    func setMainWindowVisibility(_ isVisible: Bool) {
        isMainWindowVisible = isVisible
        handleActivityModeTransition()
    }

    func setMainWindowKey(_ isKey: Bool) {
        isMainWindowKey = isKey
        handleActivityModeTransition()
        if isKey, let creds = credentials, notionSyncStatus != .syncing {
            Task { await syncNotionStats(creds: creds) }
        }
    }

    private func startSystemFeedback() {
        systemFeedback = SystemFeedback(appState: self)
        scheduleFeedbackTimer()
    }

    private func scheduleFeedbackTimer() {
        feedbackTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.systemFeedback?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        feedbackTimer = t
    }

    // MARK: - Session actions

    /// Start button on the idle dial.
    /// Pass `breatheFirst: false` to skip the pre-focus breathing gate (e.g. stopwatch mode).
    func startFocus(category: String, task: String, breatheFirst: Bool? = nil) {
        notes = ""
        session.startFocus(
            category:     category,
            task:         task,
            breatheFirst: breatheFirst ?? config.breatheBeforeFocus
        )
    }

    /// Take a Break — clears notes so they don't bleed into the break.
    func takeBreak(category: String) {
        notes = ""
        session.startBreak(category: category)
    }

    /// ⏹ Stop — pauses the timer and surfaces the stop sheet for focus
    /// sessions. Break sessions skip the "how did it go?" notes UI and save
    /// immediately, since there's nothing to reflect on.
    func requestStop() {
        session.pause()
        stopSheetNotes = ""

        if session.sessionType == .break {
            Task { await saveSession() }
        } else {
            showStopSheet = true
        }
    }

    /// Stop sheet → [Save]. Local-first: appends instantly, pushes to Notion in background.
    func saveSession() async {
        let combinedNotes = [notes, stopSheetNotes]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let entry = SessionEntry(
            date:         SessionLog.isoDate(from: Date()),
            sessionType:  session.sessionType,
            category:     session.category,
            task:         session.task,
            durationMins: session.durationMins,
            overflowMins: session.overflowMins,
            notes:        combinedNotes,
            pendingPush:  true
        )

        do { try sessionLog.append(entry) } catch {}

        // Dismiss UI immediately — user never waits on Notion.
        showStopSheet      = false
        notes              = ""
        stopSheetNotes     = ""
        isStopwatchSession = false
        session.reset()

        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            showSavedConfirmation = false
        }

        Task.detached { await NotionOutbox.shared.kick() }
    }

    /// Stop sheet → [Discard].
    func discardSession() {
        showStopSheet      = false
        stopSheetNotes     = ""
        isStopwatchSession = false
        session.reset()
    }

    // MARK: - Menubar label

    var menubarLabel: String {
        switch session.state {
        case .focusRunning, .focusOverflow, .focusPaused:
            return "\(session.category) · \(formatTime(session.remainingSeconds))"
        case .breakRunning, .breakOverflow, .breakPaused:
            return formatTime(session.remainingSeconds)
        case .breathing:
            return "Breathing…"
        default:
            let local  = sessionLog.todayFocusMinutes
            let notion = notionStats?.todayFocusMinutes ?? 0
            let mins   = max(local, notion)
            return formatMinutes(mins)
        }
    }

    // MARK: - Notion sync

    /// Days of history we mirror from Notion. Anything older is left alone.
    private static let syncWindowDays = 90

    func syncNotionStats(creds: NotionCredentials) async {
        notionSyncStatus = .syncing
        do {
            let cal       = Calendar.current
            let windowStart = cal.startOfDay(for: Date()) -
                              TimeInterval((Self.syncWindowDays - 1) * 86_400)
            let weekStart   = cal.startOfDay(for: Date()) - TimeInterval(6 * 86_400)
            let results   = try await NotionClient.querySessions(
                creds: creds, startDate: windowStart
            )
            let today     = SessionLog.isoDate(from: Date())
            let focusType = SessionType.focus.rawValue

            // Reconcile local log with Notion for the queried window.
            // Page-id driven: refreshes edits, drops Notion-deletions, adds
            // rows logged from other devices, and adopts ids for any legacy
            // local entries that match by content.
            let windowStartStr = SessionLog.isoDate(from: windowStart)
            let todayStr       = SessionLog.isoDate(from: Date())
            sessionLog.reconcileWithNotion(results, from: windowStartStr, to: todayStr)

            // Push any local entries that never made it to Notion.
            Task.detached { await NotionOutbox.shared.kick() }

            // Stats counters use the raw Notion query so they're authoritative
            // even before the local log finishes reconciling.
            notionStats = NotionStats(
                todayFocusMinutes: results
                    .filter { $0.date == today && $0.sessionType == focusType }
                    .reduce(0) { $0 + $1.durationMins },
                weekFocusMinutes: results
                    .filter {
                        $0.sessionType == focusType &&
                        $0.date >= SessionLog.isoDate(from: weekStart)
                    }
                    .reduce(0) { $0 + $1.durationMins },
                rawResults: results
            )
            notionSyncStatus = .synced
        } catch {
            notionSyncStatus = .failed(error.localizedDescription)
        }
    }


    // MARK: - Config helpers

    func saveConfig() {
        try? config.save()
    }

    /// Renames a category everywhere it's referenced: config (categories list,
    /// color map, default category), local session log, and any matching
    /// Notion rows. Returns false if the rename was rejected (empty / dup /
    /// no-op) so the UI can revert.
    @discardableResult
    func renameCategory(from old: String, to candidate: String) -> Bool {
        let new = candidate.trimmingCharacters(in: .whitespaces)
        guard !new.isEmpty, new != old else { return false }
        guard let idx = config.categories.firstIndex(of: old) else { return false }
        guard !config.categories.contains(new) else { return false }

        config.categories[idx] = new

        if let color = config.categoryColors.removeValue(forKey: old) {
            config.categoryColors[new] = color
        }
        if config.defaultCategory == old {
            config.defaultCategory = new
        }
        saveConfig()

        sessionLog.renameCategory(from: old, to: new)

        // Push the rename to Notion in the background — best effort.
        if let creds = credentials {
            let pageIDs = sessionLog.pageIDs(forCategory: new)
            Task { @MainActor in
                for pid in pageIDs {
                    try? await NotionClient.updateCategory(
                        creds: creds, pageID: pid, newCategory: new
                    )
                }
            }
        }

        return true
    }

    // MARK: - Private

    /// Background auto-sync every 60 seconds when credentials are present.
    /// Faster cadence keeps the calendar in step with edits made in Notion
    /// without hammering the API (a 60-second poll is well under any limit).
    private func startAutoSync() {
        guard autoSyncTask == nil else { return }
        autoSyncTask = Task { @MainActor in
            while true {
                let interval: Double = isMainWindowVisible ? 30 : 60
                try? await Task.sleep(for: .seconds(interval))
                guard let creds = credentials else { continue }
                guard isAppActive else { continue }
                // Skip if a sync is already in progress.
                guard notionSyncStatus != .syncing else { continue }
                await syncNotionStats(creds: creds)
            }
        }
    }

    private func refreshActivityStateFromSystem() {
        isAppActive = NSApp.isActive
        if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            isMainWindowVisible = mainWindow.isVisible
            isMainWindowKey = mainWindow.isKeyWindow
        }
    }

    private func handleActivityModeTransition() {
        if effectiveAnimationMode == .frozen {
            pauseUITickers()
        } else {
            resumeUITickers()
        }
    }

    private func formatTime(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
