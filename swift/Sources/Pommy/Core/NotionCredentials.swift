import Foundation

// MARK: - Model

/// Notion integration credentials.
///
/// Stored in `AppPaths.notionCredentials` (notion.json) — the exact same
/// file the Python TUI reads and writes, so credentials entered in either
/// interface work immediately in the other.
///
/// File permissions are set to 0o600 on save (same as the Python TUI).
struct NotionCredentials: Codable, Equatable {
    var token:       String  // integration token — starts with "ntn_" or "secret_"
    var database_id: String  // Notion database UUID
    var page_url:    String  // tracker page URL (opened in browser from Settings)

    var isEmpty: Bool {
        token.isEmpty || database_id.isEmpty
    }

    /// Extracts the 32-char Notion database ID from a share/page URL.
    ///
    /// Accepts the full link a user copies from Notion, e.g.
    /// `https://www.notion.so/workspace/MyDatabase-abcdef0123456789abcdef0123456789?v=feedface…`
    /// and returns `abcdef0123456789abcdef0123456789` (NOT the `?v=…` view ID,
    /// which is also a 32-char hex string).
    ///
    /// Also accepts a bare ID (with or without dashes) and normalizes it.
    /// Returns nil if no 32-hex-char ID can be found in the path portion.
    static func extractDatabaseID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Drop the query string (`?v=…` view ID, `&p=…`, fragments, etc.)
        // before scanning, otherwise we'd return the view ID.
        let pathOnly = trimmed
            .components(separatedBy: "?").first ?? trimmed
        let noFragment = pathOnly
            .components(separatedBy: "#").first ?? pathOnly

        let stripped = noFragment.replacingOccurrences(of: "-", with: "")
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

        // Walk the path and find the last 32-char hex run.
        let chars = Array(stripped)
        guard chars.count >= 32 else { return nil }
        var lastMatch: String? = nil
        for i in 0...(chars.count - 32) {
            let window = String(chars[i..<i+32])
            if window.unicodeScalars.allSatisfy({ hex.contains($0) }) {
                lastMatch = window.lowercased()
            }
        }
        return lastMatch
    }
}

// MARK: - Load / save

enum NotionCredentialsStore {

    // MARK: Load

    /// Returns the stored credentials, or nil if the file doesn't exist
    /// or cannot be parsed.
    static func load() -> NotionCredentials? {
        let url = AppPaths.notionCredentials
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(NotionCredentials.self, from: data)
    }

    // MARK: Save

    /// Persists credentials to notion.json with permissions 0o600.
    static func save(_ creds: NotionCredentials) throws {
        let encoder              = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data                 = try encoder.encode(creds)
        let url                  = AppPaths.notionCredentials

        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    // MARK: Clear

    static func clear() throws {
        let url = AppPaths.notionCredentials
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Validation result

enum NotionValidationResult: Equatable {
    case success(databaseTitle: String)
    case failure(message: String)
}
