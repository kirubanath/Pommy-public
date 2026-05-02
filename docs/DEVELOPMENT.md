# Development

Build instructions, architecture notes, and how to cut a release. If you just want to use Pommy, [README.md](../README.md) is all you need.

## Repository layout

```
Pommy/
├── README.md
├── swift/                      The app
│   ├── Package.swift
│   ├── build.sh                Build, sign, and install Pommy.app
│   ├── scripts/
│   │   └── make-icon.swift     Renders AppIcon.icns from the vector mascot
│   ├── Resources/audio/        Ambient loops bundled into the .app
│   └── Sources/Pommy/
│       ├── App/                Entry point, AppState, system feedback
│       ├── Core/               Config, TimerSession, NotionClient, SessionLog
│       └── UI/                 Per-screen SwiftUI views
└── docs/
    ├── DEVELOPMENT.md          You are here
    ├── NOTION.md               Notion integration setup
    ├── assets/pommy.png               Brand asset used in README
    └── assets/
```

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.9+ (ships with recent Xcode CLT)

## Build and install

```bash
cd swift
./build.sh
```

This compiles the Swift package in release mode, renders a multi-resolution `AppIcon.icns` from the vector mascot, assembles `dist/Pommy.app`, ad-hoc code-signs it, strips the quarantine flag, and copies it to `/Applications/Pommy.app`.

Set `POMMY_SKIP_INSTALL=1` to stop before the install step.

## Run from source

```bash
cd swift
swift run -c release
```

Skips the icon and bundle steps. Fine for logic iteration but the menubar item and dock icon behave differently without a real bundle. Use `./build.sh` when testing UX.

## Architecture

- `AppState` (`@Observable`) is the single source of truth. `Config`, `TimerSession`, and `SessionLog` are sub-models.
- `NotionOutbox` (`actor`) is the single write path to Notion — a write-behind queue that drains serially, retries on transient errors, and surfaces permanent failures as a sync-dot state. `AppState` never awaits network; saves are always instant.
- `SystemFeedback` ticks every second and updates the dock badge and window title from `TimerSession`.
- `DesignTokens.swift` holds the entire visual language — `Surface` colors, fill ladder (`fillFaint` / `fillSoft` / `fillStrong`), `Camp` accent palette, `Radius`, `Spacing`, `Motion`, typography, and reusable views: `AmbientAppBackground`, `PommyDivider`, `PommySectionCard`, `PommySettingsRow`, `PommyRowDivider`, plus the `.pommyPress`, `.pommyGlow`, `.pommyHairline`, `.campGlow`, `.pommySecondaryButton` modifiers. Everything else reads from it.
- `TodayThemes.swift` renders the night-camp scene used in Stats. It is a self-contained atmospheric piece — single time source via `TimelineView(.animation)`, layered sines for natural motion, smoothstep eases for state transitions, two-layer `.plusLighter` glow for lit objects. Don't extend it casually.
- `PommyMascot.swift` is a pure-SwiftUI vector mascot. Its poses (`idle`, `focus`, `sleep`, `wave`, `celebrate`, `peek`, `sad`, `curious`, `focusHard`) are reused everywhere.

## Data paths

| File / dir | Purpose |
|---|---|
| `config/settings.json` | Source defaults, copied on first launch |
| `config/notion_schema.json` | Source defaults |
| `~/Library/Application Support/Pommy/config/` | Live user config |
| `~/Library/Application Support/Pommy/session_log.json` | Local session mirror |
| `~/Library/Application Support/Pommy/notion.json` | Token + database ID (gitignored) |

Sessions are saved locally first, then pushed to Notion. If Notion is unreachable the session still lands in your stats and syncs next time.

## Cutting a release

1. Bump the version string in `swift/build.sh` (`CFBundleShortVersionString`) if needed.
2. Commit and push to `main`.
3. Tag and push:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The `Release` GitHub Actions workflow runs on a macOS runner, executes `swift/build.sh`, zips `Pommy.app`, and attaches it to a new GitHub Release. The download link in README always resolves to the latest tag.

## Style conventions

- SwiftUI views stay under ~300 lines. Split into `private var foo: some View` first, then extract a separate file only if the view is reused.
- All visual constants come from `DesignTokens.swift`. Don't hardcode colors, radii, or spacing in views. In particular, no raw `Color.white.opacity(...)` for chrome — use the `Surface` ladder (`fillFaint` 0.04, `hairline` / `fillSoft` 0.06, `topHighlight` 0.08, `fillStrong` 0.10, `innerHighlight` 0.18). Black opacities are reserved for shadows and modal scrims.
- Settings screens use `PommySectionCard` + `PommySettingsRow` + `PommyRowDivider`. Don't reach for `.formStyle(.grouped)` — system grouped Forms paint their own panels that float above `AmbientAppBackground`.
- Selected / lit / focused states use `.campGlow(active:tint:)` for the two-layer halo. Press / hover feedback uses `.pommyPress`. Apply both, not one.
- User-facing copy avoids em dashes. Use `·` or commas. `PommyQuips` follows the same rule.
- New mascot poses go in `MascotPose` and `PommyMascot.swift` next to existing ones, with the face/mouth/arms branches updated.
