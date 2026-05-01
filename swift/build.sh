#!/usr/bin/env bash
# build.sh — builds Pommy.app from the Swift package, assembles the app bundle,
# ad-hoc code-signs it, and strips the quarantine flag so it runs on any Mac
# without Gatekeeper prompts.
#
# Usage:
#   cd swift && ./build.sh
#
# Output:
#   swift/dist/Pommy.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DIST="$SCRIPT_DIR/dist"
APP="$DIST/Pommy.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "▶ Building (release)…"
swift build -c release 2>&1

BUILT_BIN=".build/release/Pommy"

if [[ ! -f "$BUILT_BIN" ]]; then
    echo "✗ Build failed — binary not found at $BUILT_BIN"
    exit 1
fi

echo "▶ Generating app icon (vector Pommy)…"
ICON_OUT="$DIST/AppIcon.icns"
mkdir -p "$DIST"
swift scripts/make-icon.swift "$ICON_OUT"


echo "▶ Exporting docs/assets/pommy.png…"
mkdir -p "$SCRIPT_DIR/../docs"
sips -s format png "$ICON_OUT" --out "$SCRIPT_DIR/../docs/pommy.png" --resampleWidth 128 > /dev/null

echo "▶ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# Binary
cp "$BUILT_BIN" "$MACOS/Pommy"

# App icon
cp "$ICON_OUT" "$RESOURCES/AppIcon.icns"


# Quips JSON
cp Resources/quips.json "$RESOURCES/quips.json"

# Audio loop files (optional — skip if not present)
if [[ -d Resources/audio ]]; then
    mkdir -p "$RESOURCES/audio"
    for f in Resources/audio/*.m4a; do
        [[ -f "$f" ]] && cp "$f" "$RESOURCES/audio/"
    done
fi

# Info.plist
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>         <string>com.pommy.app</string>
    <key>CFBundleName</key>               <string>Pommy</string>
    <key>CFBundleDisplayName</key>        <string>Pommy</string>
    <key>CFBundleExecutable</key>         <string>Pommy</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>            <string>1</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.productivity</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
</dict>
</plist>
PLIST

echo "▶ Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "▶ Stripping quarantine flag…"
xattr -cr "$APP"

echo ""
echo "✓ Done → $APP"
echo "  Copy it anywhere — no Gatekeeper prompts."

if [[ "${POMMY_SKIP_INSTALL:-0}" == "1" ]]; then
    echo "▶ Skipping install (POMMY_SKIP_INSTALL=1)"
    echo "▶ Launching Pommy from dist…"
    open "$APP"
else
    echo "▶ Installing to /Applications…"
    # Quit gracefully if running, then overwrite the bundle.
    # Settings in ~/Library/Application Support/Pommy/ are untouched.
    pkill -9 -x Pommy 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/Pommy.app
    cp -R "$APP" /Applications/Pommy.app
    echo "✓ Installed → /Applications/Pommy.app"
    echo "▶ Launching Pommy…"
    open "/Applications/Pommy.app"
fi
