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
