# TypeScript Templates

## TypeScript lint-deps.sh Template

```bash
#!/bin/bash
# Lint architecture: check TypeScript layer dependencies

set -euo pipefail

# Layer mapping
declare -A LAYERS=(
    ["types"]=0
    ["utils"]=1
    ["config"]=2
    ["services"]=3
    ["handlers"]=4
)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
VIOLATIONS=0

# Get layer from path
get_layer() {
    local file="$1"
    # Extract first directory after src/
    local rel="${file#$SRC_DIR/}"
    local top_dir="${rel%%/*}"
    echo "${LAYERS[$top_dir]:-4}"
}

# Extract imports from TS file
get_imports() {
    local file="$1"
    grep -oE "from ['\"]@/[^\'\"]+['\"]" "$file" 2>/dev/null | sed "s/from ['\"]@\///g; s/['\"]//g"
}

check_violations() {
    local file="$1"
    local file_layer="$(get_layer "$file")"

    for imp in $(get_imports "$file"); do
        imp_layer="$(get_layer "$imp")"
        if [[ "$file_layer" -lt "$imp_layer" ]]; then
            echo "VIOLATION: $file (Layer $file_layer) imports $imp (Layer $imp_layer)"
            echo "  Lower layer cannot import higher layer."
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    done
}

echo "Checking TypeScript layer dependencies..."

find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" | while read -r file; do
    check_violations "$file"
done

echo
[[ "$VIOLATIONS" -eq 0 ]] && exit 0 || exit 1
```

## TypeScript lint-quality.sh Template

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
MAX_LINES=500
VIOLATIONS=0

echo "Checking TypeScript code quality..."

# File length check
find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" | while read -r file; do
    lines=$(wc -l < "$file")
    if [[ "$lines" -gt "$MAX_LINES" ]]; then
        echo "VIOLATION: $file has $lines lines"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# console.log check
find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" | while read -r file; do
    if grep -qE 'console\.(log|debug|info)' "$file"; then
        echo "VIOLATION: $file contains console.log - use structured logging"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

echo
[[ "$VIOLATIONS" -eq 0 ]] && exit 0 || exit 1
```

## TypeScript validate.py Template

```python
#!/usr/bin/env python3
"""Validate TypeScript project consistency."""

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
    print("TypeScript Project Validation")
    print("=" * 60)

    steps = [
        ("Build", ["npm", "run", "build"]),
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["npm", "test"]),
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    print(f"\nPassed: {passed}/{len(steps)}")
    sys.exit(0 if passed == len(steps) else 1)


if __name__ == "__main__":
    main()
```
