import Foundation

// MARK: - Schema

/// Mirrors notion_schema.json — maps logical field keys to Notion property names.
private struct NotionSchema: Codable {
    struct Field: Codable {
        var notion_name: String
        var type:        String
    }
    var timezone: String
    var fields:   [String: Field]

    static let fallback = NotionSchema(
        timezone: "UTC",
        fields: [
            "task":          Field(notion_name: "Task",           type: "title"),
            "category":      Field(notion_name: "Category",       type: "select"),
            "session_type":  Field(notion_name: "Type",           type: "select"),
            "date":          Field(notion_name: "Date",           type: "date"),
            "duration_mins": Field(notion_name: "Duration (min)", type: "number"),
            "overflow_mins": Field(notion_name: "Overflow (min)", type: "number"),
            "device":        Field(notion_name: "Device",         type: "select"),
            "notes":         Field(notion_name: "Notes",          type: "rich_text")
        ]
    )
}

// MARK: - Notion query result (for stats)

struct NotionSessionResult: Identifiable {
    var id:           String
    var date:         String  // ISO-8601 date "YYYY-MM-DD"
    var sessionType:  String
    var category:     String
    var task:         String
    var durationMins: Int
    var overflowMins: Int
    var notes:        String  = ""
}

// MARK: - Client

/// All Notion API calls — save, validate, and query for stats.
///
/// Uses `URLSession` directly (no third-party dependencies).
/// All public methods are async and throw on failure.
struct NotionClient {

    private static let notionVersion = "2022-06-28"
    private static let baseURL       = URL(string: "https://api.notion.com/v1")!

    // MARK: - Schema loading

    private static func loadSchema() -> NotionSchema {
        guard let data = try? Data(contentsOf: AppPaths.notionSchema),
              let schema = try? JSONDecoder().decode(NotionSchema.self, from: data)
        else { return .fallback }
        return schema
    }

    // MARK: - Headers

    private static func headers(for creds: NotionCredentials) -> [String: String] {
        [
            "Authorization":  "Bearer \(creds.token)",
            "Content-Type":   "application/json",
            "Notion-Version": notionVersion
        ]
    }

    // MARK: - Save session

    /// Creates a new page in the Notion database for a completed session.
    /// Creates a new page in Notion for a completed session and returns the
    /// new Notion page id so callers can persist it on the local entry.
    @discardableResult
    static func saveSession(
        creds:        NotionCredentials,
        config:       Config,
        task:         String,
        category:     String,
        sessionType:  SessionType,
        startedAt:    Date,
        durationMins: Int,
        overflowMins: Int,
        notes:        String
    ) async throws -> String {
        let schema     = loadSchema()
        let properties = buildProperties(
            schema: schema,
            values: [
                "task":          task.isEmpty ? "Untitled" : task,
                "category":      category,
                "session_type":  sessionType.rawValue,
                "date":          startedAt,
                "duration_mins": durationMins,
                "overflow_mins": overflowMins,
                "device":        config.device,
                "notes":         notes
            ]
        )

        let body: [String: Any] = [
            "parent":     ["database_id": creds.database_id],
            "properties": properties
        ]

        var request = URLRequest(
            url: baseURL.appendingPathComponent("pages"),
            timeoutInterval: 20
        )
        request.httpMethod  = "POST"
        request.allHTTPHeaderFields = headers(for: creds)
        request.httpBody    = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NotionError.saveFailed(msg)
        }
        let json   = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let pageID = (json?["id"] as? String) ?? ""
        guard !pageID.isEmpty else {
            throw NotionError.saveFailed("response missing page id")
        }
        return pageID
    }

    // MARK: - Update single property

    /// Patches an existing Notion page so its category select equals `newCategory`.
    /// Used when the user renames a category in settings.
    static func updateCategory(
        creds:       NotionCredentials,
        pageID:      String,
        newCategory: String
    ) async throws {
        let schema   = loadSchema()
        let catField = schema.fields["category"]?.notion_name ?? "Category"

        let body: [String: Any] = [
            "properties": [
                catField: ["select": ["name": newCategory]]
            ]
        ]

        var request = URLRequest(
            url: baseURL.appendingPathComponent("pages/\(pageID)"),
            timeoutInterval: 20
        )
        request.httpMethod          = "PATCH"
        request.allHTTPHeaderFields = headers(for: creds)
        request.httpBody            = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NotionError.saveFailed(msg)
        }
    }

    // MARK: - Validate

    /// Fetches database metadata to verify credentials are correct.
    /// Returns the database title on success.
    static func validate(creds: NotionCredentials) async throws -> String {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("databases/\(creds.database_id)"),
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(for: creds)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NotionError.validationFailed(msg)
        }
        let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let parts = json?["title"] as? [[String: Any]] ?? []
        let title = parts.compactMap {
            ($0["plain_text"] as? String)
        }.joined()
        return title.isEmpty ? "Untitled" : title
    }

    // MARK: - Query (background sync for stats)

    /// Returns all sessions since `startDate` from the Notion database,
    /// following `has_more`/`next_cursor` to retrieve every page.
    static func querySessions(
        creds:     NotionCredentials,
        startDate: Date
    ) async throws -> [NotionSessionResult] {
        let schema      = loadSchema()
        let dateField   = schema.fields["date"]?.notion_name ?? "Date"
        let typeField   = schema.fields["session_type"]?.notion_name ?? "Type"
        let catField    = schema.fields["category"]?.notion_name ?? "Category"
        let taskField   = schema.fields["task"]?.notion_name ?? "Task"
        let durField    = schema.fields["duration_mins"]?.notion_name ?? "Duration (min)"
        let ovfField    = schema.fields["overflow_mins"]?.notion_name ?? "Overflow (min)"
        let notesField  = schema.fields["notes"]?.notion_name ?? "Notes"

        let isoStart = isoDateString(from: startDate)
        let filter: [String: Any] = [
            "property": dateField,
            "date":     ["on_or_after": isoStart]
        ]

        let queryURL = baseURL.appendingPathComponent("databases/\(creds.database_id)/query")
        var allResults: [NotionSessionResult] = []
        var cursor: String? = nil

        repeat {
            var body: [String: Any] = ["filter": filter, "page_size": 100]
            if let cursor { body["start_cursor"] = cursor }

            var request = URLRequest(url: queryURL, timeoutInterval: 20)
            request.httpMethod           = "POST"
            request.allHTTPHeaderFields  = headers(for: creds)
            request.httpBody             = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let msg = String(data: data, encoding: .utf8) ?? "unknown error"
                throw NotionError.queryFailed(msg)
            }

            let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let pages   = json?["results"] as? [[String: Any]] ?? []
            let hasMore = json?["has_more"] as? Bool ?? false
            cursor      = hasMore ? (json?["next_cursor"] as? String) : nil

            let batch: [NotionSessionResult] = pages.compactMap { page in
                guard let id    = page["id"] as? String,
                      let props = page["properties"] as? [String: Any]
                else { return nil }

                let date     = dateValue(from: props[dateField])
                guard !date.isEmpty else { return nil }

                return NotionSessionResult(
                    id:           id,
                    date:         String(date.prefix(10)),
                    sessionType:  selectValue(from: props[typeField]),
                    category:     selectValue(from: props[catField]),
                    task:         titleValue(from: props[taskField]),
                    durationMins: numberValue(from: props[durField]),
                    overflowMins: numberValue(from: props[ovfField]),
                    notes:        richTextValue(from: props[notesField])
                )
            }
            allResults.append(contentsOf: batch)
        } while cursor != nil

        return allResults
    }

    // MARK: - Property builders

    private static func buildProperties(
        schema: NotionSchema,
        values: [String: Any]
    ) -> [String: Any] {
        var props: [String: Any] = [:]

        for (key, field) in schema.fields {
            guard let value = values[key] else { continue }
            let name = field.notion_name

            switch field.type {
            case "title":
                let text = (value as? String) ?? ""
                props[name] = ["title": [["text": ["content": text]]]]

            case "select":
                let text = (value as? String) ?? ""
                props[name] = ["select": ["name": text]]

            case "date":
                let localTZ = TimeZone.current.identifier
                let iso: String
                if let date = value as? Date {
                    iso = isoDateTimeString(from: date, timezone: localTZ)
                } else {
                    iso = (value as? String) ?? ""
                }
                props[name] = ["date": ["start": iso, "time_zone": localTZ]]

            case "number":
                props[name] = ["number": value]

            case "rich_text":
                let text = (value as? String) ?? ""
                if text.isEmpty {
                    props[name] = ["rich_text": []]
                } else {
                    props[name] = ["rich_text": [["text": ["content": text]]]]
                }

            default:
                break
            }
        }
        return props
    }

    // MARK: - Date helpers

    private static func isoDateString(from date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func isoDateTimeString(from date: Date, timezone: String) -> String {
        let f        = ISO8601DateFormatter()
        f.timeZone   = TimeZone(identifier: timezone) ?? .current
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    // MARK: - JSON helpers for query response

    private static func dateValue(from prop: Any?) -> String {
        guard let p = prop as? [String: Any],
              let d = p["date"] as? [String: Any],
              let s = d["start"] as? String
        else { return "" }
        return s
    }

    private static func titleValue(from prop: Any?) -> String {
        guard let p   = prop as? [String: Any],
              let arr = p["title"] as? [[String: Any]],
              let txt = arr.first?["plain_text"] as? String
        else { return "" }
        return txt
    }

    private static func selectValue(from prop: Any?) -> String {
        guard let p = prop as? [String: Any],
              let s = p["select"] as? [String: Any],
              let n = s["name"] as? String
        else { return "" }
        return n
    }

    private static func numberValue(from prop: Any?) -> Int {
        guard let p = prop as? [String: Any],
              let n = p["number"] as? Double
        else { return 0 }
        return Int(n)
    }

    private static func richTextValue(from prop: Any?) -> String {
        guard let p   = prop as? [String: Any],
              let arr = p["rich_text"] as? [[String: Any]]
        else { return "" }
        return arr.compactMap { $0["plain_text"] as? String }.joined()
    }
}

// MARK: - Errors

enum NotionError: Error, LocalizedError {
    case saveFailed(String)
    case validationFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let m):       return "Notion save failed: \(m)"
        case .validationFailed(let m): return "Notion validation failed: \(m)"
        case .queryFailed(let m):      return "Notion query failed: \(m)"
        }
    }
}
