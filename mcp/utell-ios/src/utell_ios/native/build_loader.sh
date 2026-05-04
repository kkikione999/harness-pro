#!/usr/bin/env bash
# Compile the utell-loader dylib for iOS Simulator.
# Detects host architecture automatically (arm64 or x86_64).
# Run from the project root: bash src/utell_ios/native/build_loader.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/loader.m"
OUTPUT="$SCRIPT_DIR/loader.dylib"

# Detect host architecture
ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86_64" ]; then
    echo "Error: Unsupported architecture '$ARCH'. Only arm64 and x86_64 are supported." >&2
    exit 1
fi

if ! command -v xcrun &>/dev/null; then
    echo "Error: xcrun not found. Install Xcode CLI tools: xcode-select --install" >&2
    exit 1
fi

SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null) || {
    echo "Error: iOS Simulator SDK not found. Install Xcode with iOS platform support." >&2
    exit 1
}
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)

echo "Compiling loader.m → loader.dylib"
echo "  Architecture: $ARCH"
echo "  SDK: $SDK_PATH (version $SDK_VERSION)"

clang -dynamiclib \
    -target "${ARCH}-apple-ios${SDK_VERSION}-simulator" \
    -isysroot "$SDK_PATH" \
    -framework Foundation -framework UIKit \
    -lobjc \
    -o "$OUTPUT" \
    "$SOURCE"

codesign -f -s - "$OUTPUT"

echo "Done: $OUTPUT"
file "$OUTPUT"
