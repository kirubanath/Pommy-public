import Foundation

/// Central registry of every file path the app reads or writes.
///
/// All paths live under ~/Library/Application Support/Pommy/
/// exactly matching the Python core layout so both the Swift app
/// and the terminal TUI share the same config and session log.
enum AppPaths {

    // MARK: - Root

    /// ~/Library/Application Support/Pommy/
    static let appSupport: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base.appendingPathComponent("Pommy", isDirectory: true)
    }()

    // MARK: - Config

    /// ~/Library/Application Support/Pommy/config/
    static var config: URL {
        appSupport.appendingPathComponent("config", isDirectory: true)
    }

    /// ~/Library/Application Support/Pommy/config/settings.json
    static var settings: URL {
        config.appendingPathComponent("settings.json")
    }

    /// ~/Library/Application Support/Pommy/config/notion.json
    /// Matches the filename the Python TUI reads/writes — shared file.
    static var notionCredentials: URL {
        config.appendingPathComponent("notion.json")
    }

    /// ~/Library/Application Support/Pommy/config/notion_schema.json
    /// Maps logical field keys → Notion property names. Shared with Python TUI.
    static var notionSchema: URL {
        config.appendingPathComponent("notion_schema.json")
    }

    // MARK: - Session log

    /// ~/Library/Application Support/Pommy/config/session_log.json
    ///
    /// Matches the path the Python TUI would write to if it were
    /// extended to emit this file (Option C in the plan).
    static var sessionLog: URL {
        config.appendingPathComponent("session_log.json")
    }

    // MARK: - Bundled audio

    /// Returns the URL for a bundled audio asset by filename.
    ///
    /// build.sh copies swift/Resources/audio/ into
    /// Pommy.app/Contents/Resources/audio/ so Bundle.main finds them here.
    static func audio(named filename: String) -> URL? {
        Bundle.main.url(forResource: filename, withExtension: nil,
                        subdirectory: "audio")
    }

    // MARK: - Setup

    /// Creates all required directories on first launch.
    /// Safe to call every time — does nothing if they already exist.
    static func ensureDirectoriesExist() throws {
        let fm = FileManager.default
        for dir in [appSupport, config] {
            try fm.createDirectory(at: dir,
                                   withIntermediateDirectories: true,
                                   attributes: nil)
        }
    }
}
