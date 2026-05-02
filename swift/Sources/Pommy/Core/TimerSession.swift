import Foundation

// MARK: - Session type

enum SessionType: String, Codable, CaseIterable {
    case focus = "Focus"
    case `break` = "Break"
}

// MARK: - Session state

/// Every state the timer can be in, matching the plan's state table exactly.
enum SessionState: Equatable {
    case idle                        // no session running
    case breathing                   // pre-focus breathing gate
    case focusRunning                 // focus countdown active
    case focusPaused                  // focus paused mid-session
    case focusOverflow                // focus done, still ticking past target
    case afterFocusSaved              // session logged — show ☕ button
    case breakRunning                 // break countdown active
    case breakPaused                  // break paused mid-session
    case breakOverflow                // break done, still ticking past target
    case afterBreakSaved              // break logged — dial resets
}

// MARK: - Timer session

/// Drives a single focus or break session.
///
/// Owned by `AppState`. All mutations happen on the MainActor so
/// SwiftUI views update correctly.
@Observable @MainActor
final class TimerSession {

    // MARK: Public state (observed by views)

    private(set) var state:      SessionState = .idle
    private(set) var sessionType: SessionType  = .focus
    private(set) var category:   String        = "Work"
    private(set) var task:       String        = ""

    /// Target duration selected on the dial (seconds).
    var targetSeconds: Int = 50 * 60

    /// Elapsed real time since the session started (seconds).
    /// Counts up regardless of target — continues into overflow.
    private(set) var elapsedSeconds: Int = 0

    /// True once `elapsedSeconds` exceeds `targetSeconds`.
    var isOverflow: Bool { elapsedSeconds > targetSeconds }

    /// Remaining seconds until target (clamped to 0 in overflow).
    var remainingSeconds: Int { max(0, targetSeconds - elapsedSeconds) }

    /// Seconds past the target (0 when not in overflow).
    var overflowSeconds: Int { max(0, elapsedSeconds - targetSeconds) }

    // MARK: Private timer machinery

    private var timer: Timer?
    private(set) var sessionStart: Date?

    /// Wall-clock instant the current running interval began (nil when paused).
    private var runStart: Date?

    /// Elapsed seconds accumulated in all previous running intervals (before
    /// the current one). Banked on each pause so resume can add on top of it.
    private var pausedElapsed: TimeInterval = 0

    // MARK: - Session lifecycle

    /// Called when the user taps Start on the idle dial.
    /// If `breatheFirst` is true, transitions to `.breathing`; the
    /// breathing gate calls `beginFocus()` when done or skipped.
    func startFocus(category: String, task: String, breatheFirst: Bool) {
        self.category    = category
        self.task        = task
        self.sessionType = .focus
        elapsedSeconds   = 0

        if breatheFirst {
            state = .breathing
        } else {
            beginFocus()
        }
    }

    /// Called by `BreathingGateView` when breathing is complete or skipped.
    func beginFocus() {
        sessionStart   = Date()
        pausedElapsed  = 0
        runStart       = Date()
        startTicking()
        state = .focusRunning
    }

    /// Called when the user taps ☕ Take a Break.
    func startBreak(category: String) {
        self.category    = category
        self.sessionType = .break
        elapsedSeconds   = 0
        sessionStart     = Date()
        pausedElapsed    = 0
        runStart         = Date()
        startTicking()
        state = .breakRunning
    }

    func pause() {
        // Bank elapsed time before stopping the ticker so the count is correct.
        if let rs = runStart {
            pausedElapsed += Date.now.timeIntervalSince(rs)
            elapsedSeconds = Int(pausedElapsed)
            runStart = nil
        }
        stopTicking()
        switch state {
        case .focusRunning, .focusOverflow:
            state = .focusPaused
        case .breakRunning, .breakOverflow:
            state = .breakPaused
        default:
            break
        }
    }

    func resume() {
        runStart = Date()
        startTicking()
        switch state {
        case .focusPaused:
            state = isOverflow ? .focusOverflow : .focusRunning
        case .breakPaused:
            state = isOverflow ? .breakOverflow : .breakRunning
        default:
            break
        }
    }

    /// Called when the user taps ⏹ Stop — does NOT log; caller handles logging.
    func stop() {
        // Final bank so durationMins reflects true elapsed time.
        if let rs = runStart {
            pausedElapsed += Date.now.timeIntervalSince(rs)
            elapsedSeconds = Int(pausedElapsed)
            runStart = nil
        }
        stopTicking()
        switch sessionType {
        case .focus: state = .afterFocusSaved
        case .break: state = .afterBreakSaved
        }
    }

    /// Resets fully back to idle (called after session is saved/discarded).
    func reset() {
        stopTicking()
        pausedElapsed  = 0
        runStart       = nil
        elapsedSeconds = 0
        sessionStart   = nil
        state          = .idle
    }

    // MARK: - Computed display values

    /// Duration of the completed session in minutes (rounded to nearest).
    var durationMins: Int {
        Int((Double(elapsedSeconds) / 60).rounded())
    }

    var overflowMins: Int {
        Int((Double(overflowSeconds) / 60).rounded())
    }

    // MARK: - Private timer

    private func startTicking() {
        stopTicking()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // Compute from wall clock so screen-sleep gaps don't lose time.
        if let rs = runStart {
            elapsedSeconds = Int(pausedElapsed + Date.now.timeIntervalSince(rs))
        }
        updateOverflowState()
    }

    private func updateOverflowState() {
        switch state {
        case .focusRunning where elapsedSeconds > targetSeconds:
            state = .focusOverflow
        case .breakRunning where elapsedSeconds > targetSeconds:
            state = .breakOverflow
        default:
            break
        }
    }
}
