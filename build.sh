#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FocusSupport"
APP_BUILD_VERSION="0"
APP_SHORT_VERSION="0.2"
OUT_DIR=".build"
APP_DIR="$OUT_DIR/$APP_NAME.app"
BIN_PATH="$OUT_DIR/$APP_NAME"

if [ "${1:-}" = "clean" ]; then
  rm -rf "$OUT_DIR"
  echo "Cleaned $OUT_DIR"
  exit 0
fi

mkdir -p "$OUT_DIR"

SOURCE_FILES=()
while IFS= read -r file; do
  SOURCE_FILES+=("$file")
done < <(find Sources -type f -name '*.swift' | sort)

if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
  echo "No Swift sources found under Sources/"
  exit 1
fi

swiftc \
  -O \
  -o "$BIN_PATH" \
  "${SOURCE_FILES[@]}" \
  -framework Cocoa \
  -framework UserNotifications \
  -framework UniformTypeIdentifiers

if [ ! -x "$BIN_PATH" ]; then
  echo "Built binary not found: $BIN_PATH"
  exit 1
fi

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat <<PLIST > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>FocusSupport</string>
  <key>CFBundleDisplayName</key>
  <string>FocusSupport</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.FocusSupport</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD_VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_SHORT_VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>FocusSupport</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built $BIN_PATH"

echo "Built $APP_DIR"

echo "Run: open $APP_DIR"
