import Foundation
import SwiftUI

// MARK: - Ambient sound

enum AmbientSound: String, Codable, CaseIterable, Identifiable {
    case rain    = "Rain"
    case wind    = "Wind"
    case breeze  = "Breeze"
    case forest  = "Forest"
    case silence = "Silence"

    var id: String { rawValue }

    /// Filename inside Pommy.app/Contents/Resources/audio/
    var filename: String? {
        switch self {
        case .rain:    return "rain_loop.m4a"
        case .wind:    return "wind_loop.m4a"
        case .breeze:  return "breeze_loop.m4a"
        case .forest:  return "forest_loop.m4a"
        case .silence: return nil
        }
    }
}

enum StatsTodayTheme: String, Codable, CaseIterable, Identifiable {
    case fireflyJar  = "Firefly Jar"

    var id: String { rawValue }

    /// User-facing label (kept separate from rawValue for backward-compatible persistence).
    var displayName: String {
        switch self {
        case .fireflyJar: return "Camp"
        }
    }
}

// MARK: - Persisted payload (mirrors settings.json exactly)

/// Every key here maps 1-to-1 with settings.json.
/// Swift-only keys (category_colors, breathe_*, ambient_*) are ignored
/// by the Python TUI — backward-compatible via `decodeIfPresent`.
private struct ConfigPayload: Codable {

    // Shared with Python TUI
    var focus_duration:   Int
    var break_duration:   Int
    var overflow_warning: Bool
    var device:           String
    var devices:          [String]
    var categories:       [String]
    var default_category: String
    var focus_presets:    [Int]

    // Swift-only — written alongside shared keys, ignored by Python
    var category_colors:       [String: String]?  // category name → hex string
    var stopwatch_mins_per_ring: Int?
    var streak_min_minutes:     Int?
    var weekly_focus_target_mins: Int?
    var daily_focus_target_mins: Int?
    var dial_max_minutes:       Int?
    var breathe_before_focus:  Bool?
    var breath_cycles:         Int?
    var breathe_duration_mins: Int?
    var rest_duration_mins:    Int?
    var ambient_sound:         String?
    var ambient_volume:        Double?
    var stats_today_theme:     String?
    var min_session_minutes:   Int?
    var notion_sync_enabled:   Bool?
}

// MARK: - Config (live, observable)

/// Single source of truth for all user preferences.
///
/// Reads from and writes to `AppPaths.settings` (settings.json).
/// Initialise once in `AppState` and inject via the environment.
@Observable
final class Config {

    // MARK: Shared with Python TUI

    var focusDuration:   Int    = 50
    var breakDuration:   Int    = 10
    var overflowWarning: Bool   = true
    var device:          String = "Home"
    var devices:         [String] = ["Home"]
    var categories:      [String] = ["Work", "Study", "Creative", "Personal"]
    var defaultCategory: String   = "Work"
    var focusPresets:    [Int]    = [25, 45, 50]

    // MARK: Category colors (Swift-only)

    /// Maps category name → SwiftUI Color.
    /// Default palette from the plan's design spec (muted, desaturated).
    var categoryColors: [String: Color] = [:]

    private static let defaultPalette: [String: String] = [
        "Work":     "#5B8DB8",
        "Study":    "#6A9E72",
        "Creative": "#C9974A",
        "Personal": "#9B9B9B"
    ]

    // MARK: Focus settings (Swift-only)

    var breatheBeforeFocus: Bool = false
    var breathCycles:       Int  = 5

    // MARK: Mindfulness settings (Swift-only)

    var stopwatchMinsPerRing: Int         = 30
    var streakMinMinutes:     Int         = 25
    /// Target weekly focus time in minutes — drives the companion plant in
    /// the stats header and the aurora reward in the Today scene. Default 20h.
    var weeklyFocusTargetMins: Int        = 1200
    /// Target daily focus time in minutes — drives the Pommy-sleeps choreography
    /// and the "Goal complete" indicator in the Today header. Default 4h.
    var dailyFocusTargetMins:  Int        = 240
    /// Max minutes a single revolution of the dial represents. Restricted in
    /// settings to 60 / 120 / 180 / 240 so the geometry stays sane.
    var dialMaxMinutes:        Int        = 120

    var breatheDurationMins: Int         = 5
    var restDurationMins:    Int         = 5
    var ambientSound:        AmbientSound = .rain
    var ambientVolume:       Double       = 0.7
    var statsTodayTheme:     StatsTodayTheme = .fireflyJar
    /// Sessions shorter than this are silently discarded (not logged locally or pushed to Notion).
    /// Set to 0 to disable the gate.
    var minSessionMinutes:   Int         = 10
    /// When false, sessions are saved locally but nothing is pushed or pulled from Notion
    /// until the user re-enables. All pending entries drain automatically on re-enable.
    var notionSyncEnabled:   Bool        = true

    // MARK: - Load / save

    func load() throws {
        let data    = try Data(contentsOf: AppPaths.settings)
        let decoder = JSONDecoder()
        let p       = try decoder.decode(ConfigPayload.self, from: data)

        focusDuration   = p.focus_duration
        breakDuration   = p.break_duration
        overflowWarning = p.overflow_warning
        device          = p.device
        devices         = p.devices
        categories      = p.categories
        defaultCategory = p.default_category
        focusPresets    = p.focus_presets

        // Category colors — merge stored colours with defaults for any
        // category that has no saved colour yet.
        var merged: [String: Color] = [:]
        let stored = p.category_colors ?? [:]
        for cat in categories {
            let hex = stored[cat] ?? Self.defaultPalette[cat] ?? "#9B9B9B"
            merged[cat] = Color(hex: hex)
        }
        categoryColors = merged

        stopwatchMinsPerRing  = p.stopwatch_mins_per_ring   ?? 30
        streakMinMinutes      = p.streak_min_minutes        ?? 25
        weeklyFocusTargetMins = p.weekly_focus_target_mins  ?? 1200
        dailyFocusTargetMins  = p.daily_focus_target_mins   ?? 240
        dialMaxMinutes        = p.dial_max_minutes          ?? 120

        breatheBeforeFocus  = p.breathe_before_focus  ?? false
        breathCycles        = p.breath_cycles          ?? 5
        breatheDurationMins = p.breathe_duration_mins  ?? 5
        restDurationMins    = p.rest_duration_mins     ?? 5
        ambientSound        = AmbientSound(rawValue: p.ambient_sound ?? "") ?? .rain
        ambientVolume       = p.ambient_volume ?? 0.7
        statsTodayTheme     = StatsTodayTheme(rawValue: p.stats_today_theme ?? "") ?? .fireflyJar
        minSessionMinutes   = p.min_session_minutes    ?? 10
        notionSyncEnabled   = p.notion_sync_enabled    ?? true
    }

    func save() throws {
        // Serialize category colors back to hex strings
        var colorMap: [String: String] = [:]
        for (cat, color) in categoryColors {
            colorMap[cat] = color.hexString
        }

        let p = ConfigPayload(
            focus_duration:          focusDuration,
            break_duration:          breakDuration,
            overflow_warning:        overflowWarning,
            device:                  device,
            devices:                 devices,
            categories:              categories,
            default_category:        defaultCategory,
            focus_presets:           focusPresets,
            category_colors:           colorMap,
            stopwatch_mins_per_ring:   stopwatchMinsPerRing,
            streak_min_minutes:        streakMinMinutes,
            weekly_focus_target_mins:  weeklyFocusTargetMins,
            daily_focus_target_mins:   dailyFocusTargetMins,
            dial_max_minutes:          dialMaxMinutes,
            breathe_before_focus:    breatheBeforeFocus,
            breath_cycles:           breathCycles,
            breathe_duration_mins:   breatheDurationMins,
            rest_duration_mins:      restDurationMins,
            ambient_sound:           ambientSound.rawValue,
            ambient_volume:          ambientVolume,
            stats_today_theme:       statsTodayTheme.rawValue,
            min_session_minutes:     minSessionMinutes,
            notion_sync_enabled:     notionSyncEnabled
        )
        let encoder           = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data              = try encoder.encode(p)
        try data.write(to: AppPaths.settings, options: .atomic)
    }

    // MARK: - Helpers

    /// Returns the SwiftUI Color for a category, falling back to warm grey.
    func color(for category: String) -> Color {
        categoryColors[category] ?? Color(hex: Self.defaultPalette[category] ?? "#9B9B9B")
    }

    /// Ensures every category in `categories` has an entry in `categoryColors`.
    /// Call after adding a new category.
    func assignMissingColors() {
        for cat in categories where categoryColors[cat] == nil {
            categoryColors[cat] = Color(hex: Self.defaultPalette[cat] ?? "#9B9B9B")
        }
    }
}

// MARK: - Color ↔ Hex helpers

extension Color {

    /// Initialises a Color from a CSS hex string (#RGB, #RRGGBB).
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }

        // Expand #RGB → #RRGGBB
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }

        let value  = UInt64(s, radix: 16) ?? 0xA8A8A8
        let r      = Double((value >> 16) & 0xFF) / 255
        let g      = Double((value >>  8) & 0xFF) / 255
        let b      = Double( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns the color as a #RRGGBB hex string using the sRGB color space.
    var hexString: String {
        let resolved = self.resolve(in: EnvironmentValues())
        let r = Int(resolved.red   * 255)
        let g = Int(resolved.green * 255)
        let b = Int(resolved.blue  * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
