# Go Templates

## Go lint-deps.sh Template

```bash
#!/bin/bash
# Lint architecture: check Go layer dependencies

set -euo pipefail

# Layer mapping (inferred from codebase)
declare -A LAYERS=(
    ["types"]=0
    ["utils"]=1
    ["config"]=2
    ["services"]=3
    ["handlers"]=4
)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VIOLATIONS=0

# Get all packages
PACKAGES=$(cd "$ROOT_DIR" && go list ./...)

get_layer() {
    local pkg="$1"
    # Extract module name from full path
    local name="${pkg##*/}"
    echo "${LAYERS[$name]:-4}"
}

check_violations() {
    local pkg="$1"
    local pkg_layer="$(get_layer "$pkg")"

    # Get imports for this package
    local imports=$(cd "$ROOT_DIR" && go list -f '{{.Imports}}' "$pkg" 2>/dev/null | tr -d '[]')

    for imp in $imports; do
        # Skip standard library and external packages
        case "$imp" in
            golang.org/*|github.com/*|golang.org/*)
                imp_name="${imp##*/}"
                if [[ -n "${LAYERS[$imp_name]:-}" ]]; then
                    imp_layer="${LAYERS[$imp_name]}"
                    if [[ "$pkg_layer" -lt "$imp_layer" ]]; then
                        echo "VIOLATION: $pkg (Layer $pkg_layer) imports $imp (Layer $imp_layer)"
                        echo "  Lower layer cannot import higher layer."
                        VIOLATIONS=$((VIOLATIONS + 1))
                    fi
                fi
                ;;
        esac
    done
}

echo "Checking Go layer dependencies..."

for pkg in $PACKAGES; do
    check_violations "$pkg"
done

echo
if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "✓ No layer violations found"
    exit 0
else
    echo "✗ Found $VIOLATIONS violation(s)"
    exit 1
fi
```

## Go lint-quality.sh Template

```bash
#!/bin/bash
# Lint code quality for Go projects

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAX_LINES=500
VIOLATIONS=0

echo "Checking Go code quality..."

# Check 1: File line count
find "$ROOT_DIR" -name "*.go" -not -path "*/vendor/*" | while read -r file; do
    lines=$(wc -l < "$file")
    if [[ "$lines" -gt "$MAX_LINES" ]]; then
        echo "VIOLATION: $file has $lines lines (max $MAX_LINES)"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# Check 2: No fmt.Print* (use log/slog instead)
echo "Checking for fmt.Print statements..."
find "$ROOT_DIR" -name "*.go" -not -path "*/vendor/*" | while read -r file; do
    if grep -qE 'fmt\.Print' "$file"; then
        echo "VIOLATION: $file contains fmt.Print - use log/slog instead"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# Check 3: Error handling (no _ = err)
echo "Checking for ignored errors..."
find "$ROOT_DIR" -name "*.go" -not -path "*/vendor/*" | while read -r file; do
    if grep -qE '^_ = err$' "$file" 2>/dev/null; then
        echo "VIOLATION: $file ignores error with _ = err"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

echo
if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "✓ No quality violations found"
    exit 0
else
    echo "✗ Found $VIOLATIONS violation(s)"
    exit 1
fi
```

## Go validate.py Template

```python
#!/usr/bin/env python3
"""Validate Go project consistency."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd):
    print(f"\n[{name}]")
    result = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    return result.returncode == 0


def main():
    print("Go Project Validation")
    print("=" * 60)

    steps = [
        ("Build", ["go", "build", "./..."]),
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["go", "test", "./..."]),
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    print(f"\nPassed: {passed}/{len(steps)}")
    sys.exit(0 if passed == len(steps) else 1)


if __name__ == "__main__":
    main()
```

## Go Layer Inference

```bash
# Get package graph
cd /path/to/project && go list -json ./... | jq -r '.ImportPath + " -> " + (.Imports | join(", "))'

# Find packages with no internal imports (potential L0)
go list -f '{{.ImportPath}} {{.Imports}}' ./... | grep -v 'github.com/user/project'
```
