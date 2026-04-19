#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MarkdownPreview"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
BUILD_BINARY="$ROOT_DIR/.build/release/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Building release binary..."
swift build -c release --package-path "$ROOT_DIR"

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$ROOT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$APP_BUNDLE" >/dev/null
fi

echo "Created $APP_BUNDLE"
