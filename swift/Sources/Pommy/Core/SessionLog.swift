import Foundation

// MARK: - Entry

/// One logged session.
///
/// Schema from the plan:
/// `{ date, session_type, category, task, duration_mins, overflow_mins }`
struct SessionEntry: Codable, Identifiable, Equatable {
    var id:              UUID    = UUID()
    var date:            String  // ISO-8601 date string "YYYY-MM-DD"
    var session_type:    String  // "Focus" | "Break"
    var category:        String
    var task:            String
    var duration_mins:   Int
    var overflow_mins:   Int
    var notes:           String  = ""
    /// Stable Notion page identifier (UUID-shaped) once the row has been
    /// pushed. Nil for entries that have never been synced.
    var notion_page_id:  String? = nil
    /// True when this entry exists locally but Notion doesn't know about it
    /// yet (either never pushed, or the last push failed). Reconcile retries
    /// the push on every sync and never deletes a pending entry.
    var pending_push:    Bool    = false

    private enum CodingKeys: String, CodingKey {
        case id, date, session_type, category, task, duration_mins, overflow_mins, notes, notion_page_id, pending_push
    }

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        date           = try c.decode(String.self,          forKey: .date)
        session_type   = try c.decode(String.self,          forKey: .session_type)
        category       = try c.decode(String.self,          forKey: .category)
        task           = try c.decode(String.self,          forKey: .task)
        duration_mins  = try c.decode(Int.self,             forKey: .duration_mins)
        overflow_mins  = try c.decode(Int.self,             forKey: .overflow_mins)
        notes          = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        notion_page_id = try c.decodeIfPresent(String.self, forKey: .notion_page_id)
        pending_push   = try c.decodeIfPresent(Bool.self,   forKey: .pending_push) ?? false
    }

    init(date: String, sessionType: SessionType, category: String,
         task: String, durationMins: Int, overflowMins: Int,
         notes: String = "", notionPageID: String? = nil, pendingPush: Bool = false) {
        self.date           = date
        self.session_type   = sessionType.rawValue
        self.category       = category
        self.task           = task
        self.duration_mins  = durationMins
        self.overflow_mins  = overflowMins
        self.notes          = notes
        self.notion_page_id = notionPageID
        self.pending_push   = pendingPush
    }

    // MARK: Convenience

    var sessionTypeEnum: SessionType {
        switch session_type.lowercased() {
        case SessionType.focus.rawValue.lowercased():
            return .focus
        case SessionType.break.rawValue.lowercased():
            return .break
        default:
            return .focus
        }
    }

    var isFocus: Bool {
        sessionTypeEnum == .focus
    }

    var isBreak: Bool {
        sessionTypeEnum == .break
    }

    var dateValue: Date? {
        let f         = DateFormatter()
        f.dateFormat  = "yyyy-MM-dd"
        f.locale      = Locale(identifier: "en_US_POSIX")
        return f.date(from: date)
    }
}

// MARK: - Log store

/// Reads and appends to `AppPaths.sessionLog` (session_log.json).
///
/// The file is a JSON array of entries. Reads happen on a background
/// thread; all mutating operations return on the MainActor.
@Observable @MainActor
final class SessionLog {

    private(set) var entries: [SessionEntry] = []

    // MARK: Load

    func load() async {
        let loaded = await Task.detached(priority: .userInitiated) {
            Self.readFromDisk()
        }.value
        self.entries = loaded
    }

    private nonisolated static func readFromDisk() -> [SessionEntry] {
        let url = AppPaths.sessionLog
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return [] }
        return (try? JSONDecoder().decode([SessionEntry].self, from: data)) ?? []
    }

    // MARK: Append

    /// Renames the `category` field on every matching entry. Used when the
    /// user edits a category name in settings — keeps the local log
    /// consistent so stats/calendar show the new label immediately.
    func renameCategory(from old: String, to new: String) {
        guard old != new else { return }
        var changed = false
        for i in entries.indices where entries[i].category == old {
            entries[i].category = new
            changed = true
        }
        if changed { try? writeToDisk() }
    }

    /// Returns the page ids of every entry currently labelled with `category`.
    /// Used to push a rename out to Notion.
    func pageIDs(forCategory category: String) -> [String] {
        entries.compactMap { $0.category == category ? $0.notion_page_id : nil }
    }

    /// Appends a new entry and persists synchronously (atomic write).
    func append(_ entry: SessionEntry) throws {
        entries.append(entry)
        try writeToDisk()
    }

    // MARK: Notion reconcile

    /// Reconciles the local log with what Notion currently holds for a date window.
    ///
    /// Reconcile is **page-id driven**:
    /// - Local entries with a `notion_page_id` are matched 1:1 against Notion.
    ///   If Notion still has the row, mutable fields are refreshed (Notion is
    ///   authoritative for synced rows). If Notion no longer has it, the local
    ///   entry is dropped (the user deleted it in Notion).
    /// - Notion rows with no matching local page id are inserted locally.
    /// - Local entries marked `pending_push` (never successfully synced) are
    ///   left intact regardless — they're handled by the retry-push pass in
    ///   `AppState`. They may also adopt a page id here if a content match is
    ///   found in Notion (handles legacy entries from before we tracked ids).
    ///
    /// Entries dated outside `startDate...endDate` are left untouched.
    func reconcileWithNotion(_ results: [NotionSessionResult], from startDate: String, to endDate: String) {
        let notionByID: [String: NotionSessionResult] = Dictionary(
            results.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var changed = false
        var keptPageIDs = Set<String>()

        // Pass 1: walk every local entry, decide keep/update/drop.
        var newEntries: [SessionEntry] = []
        newEntries.reserveCapacity(entries.count)

        for entry in entries {
            // Out of window — never touch.
            if entry.date < startDate || entry.date > endDate {
                newEntries.append(entry)
                if let pid = entry.notion_page_id { keptPageIDs.insert(pid) }
                continue
            }

            // Pending push — keep as-is; retry happens elsewhere.
            // But if a content match exists in Notion now, adopt that page id
            // (covers offline entries that were already pushed by another path
            // or legacy entries upgrading from the old schema).
            if entry.pending_push || entry.notion_page_id == nil {
                if let match = Self.contentMatch(for: entry, in: results) {
                    var updated = entry
                    updated.notion_page_id = match.id
                    updated.pending_push   = false
                    Self.refreshMutableFields(&updated, from: match)
                    newEntries.append(updated)
                    keptPageIDs.insert(match.id)
                    changed = true
                } else {
                    newEntries.append(entry)
                }
                continue
            }

            // Has a page id — look it up in Notion.
            guard let pageID = entry.notion_page_id else {
                newEntries.append(entry)
                continue
            }

            if let result = notionByID[pageID] {
                var updated = entry
                let before = updated
                Self.refreshMutableFields(&updated, from: result)
                if updated != before { changed = true }
                newEntries.append(updated)
                keptPageIDs.insert(pageID)
            } else {
                // Was synced; user deleted the row in Notion.
                changed = true
            }
        }

        entries = newEntries

        // Pass 2: add Notion rows we don't already have locally.
        for result in results {
            if keptPageIDs.contains(result.id) { continue }
            let entry = SessionEntry(
                date:         result.date,
                sessionType:  SessionType(rawValue: result.sessionType) ?? .focus,
                category:     result.category,
                task:         result.task,
                durationMins: result.durationMins,
                overflowMins: result.overflowMins,
                notes:        result.notes,
                notionPageID: result.id,
                pendingPush:  false
            )
            entries.append(entry)
            changed = true
        }

        if changed { try? writeToDisk() }
    }

    private static func refreshMutableFields(_ entry: inout SessionEntry, from result: NotionSessionResult) {
        // Conflict policy: Notion wins for user-editable fields; local wins for immutable session facts.
        entry.category = result.category
        entry.task     = result.task
        entry.notes    = result.notes
        // date, session_type, duration_mins, overflow_mins intentionally NOT updated from Notion.
    }

    /// Heuristic content match for legacy / pending entries that have no page id.
    /// Considered a match only if every coarse field aligns — date, session
    /// type, duration, category and task. Strict by design to avoid attaching
    /// the wrong Notion row to a local entry.
    private static func contentMatch(for entry: SessionEntry, in results: [NotionSessionResult]) -> NotionSessionResult? {
        results.first { r in
            r.date == entry.date &&
            r.sessionType == entry.session_type &&
            r.durationMins == entry.duration_mins &&
            r.category == entry.category &&
            r.task == entry.task
        }
    }

    // MARK: Cleanup

    /// Removes orphaned short sessions — entries that are below the minimum
    /// duration, never made it to Notion (no page ID), and are not pending push.
    /// Safe to run on launch; leaves pending entries and synced entries untouched.
    func cleanupBelowMinimum(minMinutes: Int) {
        guard minMinutes > 0 else { return }
        let before = entries.count
        entries.removeAll {
            $0.duration_mins < minMinutes &&
            $0.notion_page_id == nil &&
            !$0.pending_push
        }
        if entries.count != before { try? writeToDisk() }
    }

    // MARK: Push-flow mutators

    /// Mark an entry as pending push (call right after `append` when credentials exist).
    func markPending(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if !entries[idx].pending_push {
            entries[idx].pending_push = true
            try? writeToDisk()
        }
    }

    /// Attach a Notion page id to a local entry once a successful push returns.
    func attachNotionPageID(id: UUID, pageID: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].notion_page_id = pageID
        entries[idx].pending_push   = false
        try? writeToDisk()
    }

    /// All entries that still need to be pushed to Notion.
    var pendingEntries: [SessionEntry] {
        entries.filter { $0.pending_push }
    }

    var pendingPushCount: Int { entries.filter { $0.pending_push }.count }

    func entry(id: UUID) -> SessionEntry? {
        entries.first { $0.id == id }
    }

    /// Give up on a permanently-failed push (e.g. non-retryable 4xx).
    func markPushFailed(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].pending_push = false
        try? writeToDisk()
    }

    /// Discard a pending (unsynced) entry. Only valid for entries that have never
    /// been pushed to Notion (notion_page_id == nil). For synced entries, delete
    /// from Notion first — reconcile will drop the local mirror automatically.
    func discardEntry(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        guard entries[idx].notion_page_id == nil else { return }
        entries.remove(at: idx)
        try? writeToDisk()
    }

    // MARK: Queries (used by Stats + Calendar)

    /// All entries whose `date` matches today in the local calendar.
    var todayEntries: [SessionEntry] {
        let today = Self.isoDate(from: Date())
        return entries.filter { $0.date == today }
    }

    /// Entries for the last 7 calendar days (inclusive of today).
    func entries(forLastDays days: Int) -> [SessionEntry] {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date()) -
                    TimeInterval((days - 1) * 86_400)
        return entries.filter {
            guard let d = $0.dateValue else { return false }
            return d >= start
        }
    }

    /// Total focus minutes for today.
    var todayFocusMinutes: Int {
        todayEntries
            .filter(\.isFocus)
            .reduce(0) { $0 + $1.duration_mins }
    }

    /// Current focus streak — number of consecutive calendar days
    /// (counting backwards from today) that have at least one focus session.
    /// Consecutive-day focus streak.
    /// A day counts only if total focus minutes on that day meets `minMinutes`.
    func focusStreak(minMinutes: Int = 0) -> Int {
        let cal       = Calendar.current
        var streak    = 0
        var checkDate = cal.startOfDay(for: Date())

        // Build a date → total focus minutes map from local entries.
        var minutesByDate: [String: Int] = [:]
        for entry in entries where entry.isFocus {
            minutesByDate[entry.date, default: 0] += entry.duration_mins
        }

        while true {
            let key = Self.isoDate(from: checkDate)
            if (minutesByDate[key] ?? 0) >= max(1, minMinutes) {
                streak    += 1
                checkDate -= 86_400
            } else {
                break
            }
        }
        return streak
    }

    /// Total focus minutes grouped by ISO-8601 date string, for the last N days.
    func dailyFocusMinutes(days: Int) -> [(date: String, minutes: Int)] {
        let cal   = Calendar.current
        var result: [(date: String, minutes: Int)] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let date  = cal.startOfDay(for: Date()) - TimeInterval(offset * 86_400)
            let key   = Self.isoDate(from: date)
            let mins  = entries
                .filter { $0.date == key && $0.isFocus }
                .reduce(0) { $0 + $1.duration_mins }
            result.append((date: key, minutes: mins))
        }
        return result
    }

    /// Dominant category for a given date (most focus minutes).
    func dominantCategory(for isoDate: String) -> String? {
        let day = entries.filter {
            $0.date == isoDate && $0.isFocus
        }
        if day.isEmpty { return nil }
        let totals = Dictionary(grouping: day, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.duration_mins } }
        return totals.max(by: { $0.value < $1.value })?.key
    }

    // MARK: Private helpers

    private func writeToDisk() throws {
        let encoder              = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data                 = try encoder.encode(entries)
        try data.write(to: AppPaths.sessionLog, options: .atomic)
    }

    static func isoDate(from date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
