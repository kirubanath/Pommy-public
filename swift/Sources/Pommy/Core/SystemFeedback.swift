import Foundation
import AppKit
import AVFoundation

/// Drives system-level UI affordances based on session state:
/// - Window title reflecting current activity
/// - Soft chime when a focus session reaches its target
@MainActor
final class SystemFeedback {

    private weak var appState: AppState?
    private var hasChimedForCurrentSession: Bool = false

    private var chimePlayer: AVAudioPlayer?

    init(appState: AppState) {
        self.appState = appState
        loadChime()
    }

    // MARK: - Tick

    /// Call once per second from a timer or AppState observation point.
    func tick() {
        guard let s = appState?.session else { return }

        updateWindowTitle(session: s)
        maybePlayChime(session: s)
    }

    // MARK: - Window title

    private func updateWindowTitle(session: TimerSession) {
        let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" })
        guard let win else { return }

        let newTitle: String
        switch session.state {
        case .focusRunning, .focusOverflow, .focusPaused:
            let mins  = session.remainingSeconds / 60
            let suffix = session.task.isEmpty ? session.category : "\(session.category) · \(session.task)"
            let prefix = session.isOverflow ? "+\(session.overflowSeconds / 60)m" : "\(mins)m"
            newTitle = "Pommy · \(prefix) · \(suffix)"
        case .breakRunning, .breakOverflow, .breakPaused:
            let mins = session.remainingSeconds / 60
            newTitle = "Pommy · Break · \(mins)m"
        case .breathing:
            newTitle = "Pommy · Breathing…"
        default:
            newTitle = "Pommy"
        }

        if win.title != newTitle {
            win.title = newTitle
        }
    }

    // MARK: - Chime

    private func loadChime() {
        // Use macOS system "Glass" sound as a calm, premium-feeling chime
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.volume = 0.55
        p.prepareToPlay()
        chimePlayer = p
    }

    private func maybePlayChime(session: TimerSession) {
        // Reset latch when a new session begins (elapsed restarts)
        if session.elapsedSeconds < 5 {
            hasChimedForCurrentSession = false
        }

        // Fire once when (or after) the session crosses target. Using >= so
        // the chime isn't lost if feedbackTimer was paused during screen sleep
        // and tick() wasn't called on the exact crossing second.
        let justCrossed = session.elapsedSeconds >= session.targetSeconds
        let isFocus     = session.sessionType == .focus

        if justCrossed && isFocus && !hasChimedForCurrentSession {
            chimePlayer?.currentTime = 0
            chimePlayer?.play()
            hasChimedForCurrentSession = true
        }
    }

    func reset() {
        NSApp.dockTile.badgeLabel = nil
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            win.title = "Pommy"
        }
    }
}
