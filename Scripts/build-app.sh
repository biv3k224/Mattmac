#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
APP_DIR="$BUILD_DIR/mattmac.app"
ARCH="$(uname -m)"

case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "Unsupported Mac architecture: $ARCH" >&2; exit 1 ;;
esac

mkdir -p "$APP_DIR/Contents/MacOS"
xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target "$ARCH-apple-macosx13.0" \
  -O \
  -module-cache-path "$BUILD_DIR/module-cache" \
  "$ROOT_DIR/Sources/mattmac.swift" \
  -o "$APP_DIR/Contents/MacOS/mattmac" \
  -framework AppKit \
  -framework SwiftUI

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>mattmac</string>
  <key>CFBundleIdentifier</key><string>com.mattmac.desktop</string>
  <key>CFBundleName</key><string>mattmac</string>
  <key>CFBundleDisplayName</key><string>mattmac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.3</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
