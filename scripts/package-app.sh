#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_DIR="$PROJECT_DIR/dist/Daymark.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$PROJECT_DIR/.build/swift-module-cache"
swift build -c release
swift "$PROJECT_DIR/scripts/generate-icon.swift" "$PROJECT_DIR/Resources/AppIcon.png"
rm -rf "$PROJECT_DIR/.build/AppIcon.iconset"
mkdir -p "$PROJECT_DIR/.build/AppIcon.iconset"
sips -z 16 16 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$PROJECT_DIR/.build/AppIcon.iconset/icon_512x512.png" >/dev/null
cp "$PROJECT_DIR/Resources/AppIcon.png" "$PROJECT_DIR/.build/AppIcon.iconset/icon_512x512@2x.png"
iconutil -c icns "$PROJECT_DIR/.build/AppIcon.iconset" -o "$PROJECT_DIR/Resources/AppIcon.icns"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp ".build/release/Daymark" "$CONTENTS_DIR/MacOS/Daymark"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
