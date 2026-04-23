# Swift Templates

## Swift lint-deps Template

```bash
#!/bin/zsh
# Lint architecture: check Swift layer dependencies

set -euo pipefail

# Layer mapping (inferred from codebase)
declare -A LAYERS=(
    # Layer 0: Types
    ["MarkdownFileType"]=0
    ["MarkdownRenderMode"]=0
    ["MarkdownLinkAction"]=0
    ["MarkdownDropAction"]=0
    ["LinkOpenDecision"]=0
    # Layer 1: Utils
    ["LinkHandling"]=1
    # Layer 3: Services
    ["MarkdownInteractions"]=3
    # Layer 4: UI
    ["AppState"]=4
    ["AppWindowManager"]=4
    ["PreviewWindowController"]=4
    ["ContentView"]=4
    ["MarkdownPreviewView"]=4
    ["ReadOnlyTextView"]=4
    ["AppDelegate"]=4
    ["MarkdownPreviewApp"]=4
)

# External modules to skip
EXTERNAL_MODULES=(
    "Foundation"
    "AppKit"
    "SwiftUI"
    "Combine"
    "UniformTypeIdentifiers"
    "MarkdownUI"
    "OS"
)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_DIR="$ROOT_DIR/Sources"
VIOLATIONS=0

is_external() {
    local mod="$1"
    for ext in "${EXTERNAL_MODULES[@]}"; do
        [[ "$mod" == "$ext" ]] && return 0
    done
    return 1
}

get_layer() {
    local file="$1"
    local basename="$(basename "$file" .swift)"
    if [[ -n "${LAYERS[$basename]:-}" ]]; then
        echo "${LAYERS[$basename]}"
        return 0
    fi
    # Default to Layer 4 (UI) for unknown files
    echo "4"
}

check_violations() {
    local file="$1"
    local file_layer="$(get_layer "$file")"

    # Get imports from this file
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        mod="${line#import }"

        is_external "$mod" && continue

        # Check if we track this module
        if [[ -z "${LAYERS[$mod]:-}" ]]; then
            continue
        fi

        import_layer="${LAYERS[$mod]}"

        # Violation: lower layer (smaller number) imports higher layer (larger number)
        if [[ "$file_layer" -lt "$import_layer" ]]; then
            echo "VIOLATION: $(basename "$file") (Layer $file_layer) imports $mod (Layer $import_layer)"
            echo "  Lower layer cannot import higher layer."
            echo "  Fix: Restructure code so lower layer doesn't depend on higher."
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done < <(grep -h "^import " "$file" 2>/dev/null)
}

echo "Checking Swift layer dependencies..."

while IFS= read -r -d '' file; do
    check_violations "$file"
done < <(find "$SOURCES_DIR" -name "*.swift" -print0)

echo
if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "✓ No layer violations found"
    exit 0
else
    echo "✗ Found $VIOLATIONS violation(s)"
    exit 1
fi
```

## Swift lint-quality Template

```bash
#!/bin/zsh
# Lint code quality for Swift projects

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_DIR="$ROOT_DIR/Sources"
MAX_LINES=500
VIOLATIONS=0

echo "Checking Swift code quality..."

# Check 1: File line count
echo "Checking file lengths (max $MAX_LINES lines)..."
while IFS= read -r -d '' file; do
    lines=$(wc -l < "$file")
    if [[ "$lines" -gt "$MAX_LINES" ]]; then
        echo "VIOLATION: $(basename "$file") has $lines lines (max $MAX_LINES)"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find "$SOURCES_DIR" -name "*.swift" -print0)

# Check 2: No print statements (use os.Logger instead)
echo "Checking for print statements..."
while IFS= read -r -d '' file; do
    if grep -qE "^\s*print\(" "$file" 2>/dev/null; then
        # Allow in test files
        if [[ "$file" != *"/Tests/"* ]]; then
            echo "VIOLATION: $(basename "$file") contains print() - use Logger instead"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi
done < <(find "$SOURCES_DIR" -name "*.swift" -print0)

# Check 3: Structured logging (should use os.Logger)
echo "Checking for structured logging..."
# (Swift quality checks are lightweight - expand as needed)

echo
if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "✓ No quality violations found"
    exit 0
else
    echo "✗ Found $VIOLATIONS violation(s)"
    exit 1
fi
```

## Swift validate.py Template

```python
#!/usr/bin/env python3
"""Validate Swift project consistency."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd, cwd=None):
    """Run command, return True if success."""
    if cwd is None:
        cwd = ROOT
    print(f"\n[{name}]")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout[:500] if len(result.stdout) > 500 else result.stdout)
    if result.stderr:
        print(result.stderr[:500] if len(result.stderr) > 500 else result.stderr, file=sys.stderr)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    return result.returncode == 0


def main():
    print("Swift Project Validation Pipeline")
    print("=" * 60)

    steps = [
        ("Build", ["swift", "build"]),
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["swift", "test"]),
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    total = len(steps)

    print(f"\n{'=' * 60}")
    print(f"Passed: {passed}/{total}")
    if passed == total:
        print("All validations passed!")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
```

## Swift Layer Inference

From imports, infer layers:

```bash
# Get all imports grouped by target module
grep -rh "^import " Sources/ | sort | uniq -c | sort -rn

# Files with NO imports = likely L0 (Types)
# Files importing only Foundation = likely L1 (Utils) or L0
# Files importing AppKit/SwiftUI = likely L4 (UI)
```

### Swift Layer Heuristics

| Import Pattern | Likely Layer |
|----------------|--------------|
| No internal imports | L0 (Types) |
| Foundation only | L1 (Utils) |
| AppKit/SwiftUI | L4 (UI) |
| Mix of Foundation + domain types | L3 (Services) |
