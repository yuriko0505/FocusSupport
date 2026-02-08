#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FocusSupport"
OUT_DIR=".build"
APP_DIR="$OUT_DIR/$APP_NAME.app"

mkdir -p "$OUT_DIR"

swiftc \
  -O \
  -o "$OUT_DIR/$APP_NAME" \
  Sources/FocusSupport/main.swift \
  -framework Cocoa \
  -framework UserNotifications

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$OUT_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat <<'PLIST' > "$APP_DIR/Contents/Info.plist"
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
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleExecutable</key>
  <string>FocusSupport</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built $OUT_DIR/$APP_NAME"

echo "Built $APP_DIR"

echo "Run: open $APP_DIR"
