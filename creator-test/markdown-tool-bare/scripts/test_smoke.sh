#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MarkdownPreview.app"
APP_NAME="MarkdownPreview"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

if [[ ! -f "$APP_BUNDLE/Contents/Info.plist" ]]; then
    echo "Missing Info.plist in app bundle" >&2
    exit 1
fi

if [[ ! -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]]; then
    echo "Missing executable in app bundle" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
FILE_ONE="$TMP_DIR/first.md"
FILE_TWO="$TMP_DIR/second.md"
printf '# First\n\nOne\n' > "$FILE_ONE"
printf '# Second\n\nTwo\n' > "$FILE_TWO"

pkill -x MarkdownPreview >/dev/null 2>&1 || true
sleep 1

open -n -a "$APP_BUNDLE" "$FILE_ONE" "$FILE_TWO"

for _ in {1..30}; do
    PID="$(pgrep -n -x MarkdownPreview 2>/dev/null || true)"
    PROBE="$(TARGET_PID="$PID" swift -e 'import Foundation; import CoreGraphics; let targetPID = Int(ProcessInfo.processInfo.environment["TARGET_PID"] ?? "") ?? 0; let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []; let windows = info.filter { w in let pidValue = (w[kCGWindowOwnerPID as String] as? Int) ?? (w[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? -1; return pidValue == targetPID }; let names = windows.compactMap { $0[kCGWindowName as String] as? String }.filter { !$0.isEmpty }; print("\(windows.count)\t\(names.joined(separator: "|"))")' 2>/dev/null || true)"
    WINDOW_COUNT="${PROBE%%$'\t'*}"
    WINDOW_NAMES="${PROBE#*$'\t'}"
    if [[ "$WINDOW_NAMES" == *"first.md"* ]] && [[ "$WINDOW_NAMES" == *"second.md"* ]] && [[ "$WINDOW_COUNT" -ge 2 ]]; then
        break
    fi
    sleep 0.2
done

if [[ "${WINDOW_COUNT:-0}" -lt 2 ]]; then
    echo "Expected at least 2 windows, got ${WINDOW_COUNT:-0}" >&2
    exit 1
fi

if [[ "$WINDOW_NAMES" != *"first.md"* ]] || [[ "$WINDOW_NAMES" != *"second.md"* ]]; then
    echo "Expected window titles to include first.md and second.md, got: $WINDOW_NAMES" >&2
    exit 1
fi

pkill -x MarkdownPreview >/dev/null 2>&1 || true
rm -rf "$TMP_DIR"

echo "Smoke test passed."
