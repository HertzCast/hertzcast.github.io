#!/usr/bin/env bash
# build.sh — Compilează Yamaha Controller și produce un DMG pentru distribuție.
# Funcționează cu doar Xcode Command Line Tools (fără Xcode.app).
#
# Usage:
#   ./scripts/build.sh
#   ./scripts/build.sh --version 1.0.0
#   ./scripts/build.sh --universal   # arm64 + x86_64 fat binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_DIR/HertzCast"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"

APP_NAME="HertzCast"
EXECUTABLE="HertzCast"
BUNDLE_ID="com.danbutuc.hertzcast"
VERSION="2.2.0"
UNIVERSAL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --universal) UNIVERSAL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
HOST_ARCH="$(uname -m)"

echo "╔══════════════════════════════════════╗"
echo "║  Building HertzCast v$VERSION"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Collect sources ───────────────────────────────────────────────────────────
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$SOURCE_DIR" -name "*.swift" | sort)
echo "▸ ${#SOURCES[@]} Swift files found"
for s in "${SOURCES[@]}"; do echo "    $(basename "$s")"; done
echo ""

mkdir -p "$BUILD_DIR"

SWIFT_FLAGS=(
  -sdk "$SDK_PATH"
  -module-name "$EXECUTABLE"
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks"
  -framework SwiftUI
  -framework AppKit
  -framework UserNotifications
  -framework Combine
  -framework Foundation
)

# ── Compile ───────────────────────────────────────────────────────────────────
if $UNIVERSAL; then
  echo "▸ Compiling arm64..."
  swiftc "${SWIFT_FLAGS[@]}" -target "arm64-apple-macos13.0" \
    "${SOURCES[@]}" -o "$BUILD_DIR/${EXECUTABLE}_arm64"

  echo "▸ Compiling x86_64..."
  swiftc "${SWIFT_FLAGS[@]}" -target "x86_64-apple-macos13.0" \
    "${SOURCES[@]}" -o "$BUILD_DIR/${EXECUTABLE}_x86_64"

  echo "▸ Creating universal binary..."
  lipo -create \
    "$BUILD_DIR/${EXECUTABLE}_arm64" \
    "$BUILD_DIR/${EXECUTABLE}_x86_64" \
    -output "$BUILD_DIR/$EXECUTABLE"
  rm "$BUILD_DIR/${EXECUTABLE}_arm64" "$BUILD_DIR/${EXECUTABLE}_x86_64"
else
  echo "▸ Compiling ($HOST_ARCH)..."
  swiftc "${SWIFT_FLAGS[@]}" -target "${HOST_ARCH}-apple-macos13.0" \
    "${SOURCES[@]}" -o "$BUILD_DIR/$EXECUTABLE"
fi
echo "✔ Binary compiled"

# ── Assemble .app bundle ──────────────────────────────────────────────────────
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"

# ── Generate app icon ─────────────────────────────────────────────────────────
ICON_SRC="$PROJECT_DIR/screenshots/hertz_logo.png"
ICON_OUT="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
  echo "▸ Generating AppIcon.icns..."
  swift "$PROJECT_DIR/scripts/make_icon.swift" "$ICON_SRC" "$ICON_OUT"
else
  echo "⚠  hertz_logo.png not found — skipping icon"
fi

# Copy menu bar icons
for icon in hertz_green hertz_red; do
  src="$PROJECT_DIR/screenshots/${icon}.png"
  [ -f "$src" ] && cp "$src" "$APP_BUNDLE/Contents/Resources/" && echo "▸ Copied ${icon}.png"
done

# ── Copy image assets ─────────────────────────────────────────────────────────
RESOURCES_SRC="$SOURCE_DIR/Resources"
if [ -d "$RESOURCES_SRC" ]; then
  for img in "$RESOURCES_SRC"/*.png; do
    [ -f "$img" ] && cp "$img" "$APP_BUNDLE/Contents/Resources/" && echo "▸ Copied $(basename "$img")"
  done
  for font in "$RESOURCES_SRC"/*.ttf "$RESOURCES_SRC"/*.otf; do
    [ -f "$font" ] && cp "$font" "$APP_BUNDLE/Contents/Resources/" && echo "▸ Copied $(basename "$font")"
  done
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>ATSApplicationFontsPath</key>
    <string>.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSUserNotificationsUsageDescription</key>
    <string>HertzCast sends notifications when your receiver is turned on or off automatically.</string>
</dict>
</plist>
PLIST

# ── Strip extended attributes (resource forks break codesign) ────────────────
xattr -cr "$APP_BUNDLE"

# ── Ad-hoc code sign ──────────────────────────────────────────────────────────
ENTITLEMENTS="$SOURCE_DIR/HertzCast-dev.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi
echo "✔ Signed (ad-hoc)"

# ── Create DMG ────────────────────────────────────────────────────────────────
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/${EXECUTABLE}-v${VERSION}.dmg"
rm -f "$DMG_PATH"

STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  -quiet \
  "$DMG_PATH"

rm -rf "$STAGING"

echo "✔ DMG creat"
echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  Output"
echo "│  App : $APP_BUNDLE"
echo "│  DMG : $DMG_PATH"
echo "├──────────────────────────────────────────────────────────┤"
echo "│  Instalare: deschide DMG și trage în Applications."
echo "│  Prima lansare: right-click → Open (app e nesemnată)."
echo "└──────────────────────────────────────────────────────────┘"
