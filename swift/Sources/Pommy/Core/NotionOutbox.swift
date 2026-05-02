import Foundation
import Network

/// Write-behind outbox for Notion pushes.
///
/// Responsibilities: push pending SessionLog entries to Notion one-at-a-time,
/// retry transient failures with exponential backoff, and kick automatically
/// when the network is regained. AppState drives the trigger points (launch,
/// save, become-active); the outbox handles the drain loop exclusively.
actor NotionOutbox {
    static let shared = NotionOutbox()

    private weak var appState: AppState?
    private var drainTask: Task<Void, Never>?
    private var networkMonitor: NWPathMonitor?
    private var lastNetworkSatisfied = false

    private init() {}

    func configure(appState: AppState) {
        self.appState = appState
        startNetworkMonitor()
    }

    /// Idempotent: starts a drain pass if none is already running.
    func kick() {
        guard drainTask == nil else { return }
        drainTask = Task { await drain() }
    }

    // MARK: - Drain

    private func drain() async {
        defer { drainTask = nil }
        guard let appState else { return }

        let backoff: [Double] = [2, 8, 30]
        var attempt = 0

        while !Task.isCancelled {
            guard let creds = await appState.credentials else { return }
            let pendingIDs = await appState.sessionLog.pendingEntries.map { $0.id }
            guard !pendingIDs.isEmpty else { return }

            let config = await appState.config
            var anyRetryable = false

            for id in pendingIDs {
                guard !Task.isCancelled else { return }

                // Re-read entry: a concurrent reconcile may have adopted a page id.
                guard let live = await appState.sessionLog.entry(id: id),
                      live.pending_push,
                      live.notion_page_id == nil else { continue }

                do {
                    let pageID = try await NotionClient.saveSession(
                        creds:        creds,
                        config:       config,
                        task:         live.task,
                        category:     live.category,
                        sessionType:  live.sessionTypeEnum,
                        startedAt:    live.dateValue ?? Date(),
                        durationMins: live.duration_mins,
                        overflowMins: live.overflow_mins,
                        notes:        live.notes
                    )
                    await appState.sessionLog.attachNotionPageID(id: id, pageID: pageID)
                } catch NotionError.saveFailedHTTP(let code, let msg)
                    where code >= 400 && code < 500 && code != 401 && code != 429 {
                    // Permanent client error — stop retrying this entry.
                    await appState.sessionLog.markPushFailed(id: id)
                    await appState.reportOutboxError("Push failed (HTTP \(code)): \(msg)")
                } catch {
                    // Network error, 401, 429, 5xx — all retryable.
                    anyRetryable = true
                }
            }

            if !anyRetryable { return }

            let delay = attempt < backoff.count ? backoff[attempt] : 30
            attempt += 1
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    // MARK: - Network monitor (B3)

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            Task { await self.handleNetworkChange(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "com.pommy.network-monitor", qos: .utility))
    }

    private func handleNetworkChange(satisfied: Bool) {
        defer { lastNetworkSatisfied = satisfied }
        guard satisfied, !lastNetworkSatisfied else { return }
        kick()
    }
}
