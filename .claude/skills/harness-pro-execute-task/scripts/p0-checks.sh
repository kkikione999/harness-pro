#!/bin/bash
# p0-checks.sh — Universal P0 checks that apply to all projects
# Run at milestone boundaries and before completion
#
# Usage:
#   bash p0-checks.sh              # Full check suite
#   bash p0-checks.sh --pre-check  # Pre-validation mode (architecture boundary only)
#
# Exit non-zero if any CRITICAL violation found

set -euo pipefail

PROJECT_ROOT="$(pwd)"
VIOLATIONS=0
PRE_CHECK=false
LOG_DIR=".harness/trace/failures"
LOG_FILE="$LOG_DIR/p0-failures.log"

# --- Parse arguments ---
if [[ "${1:-}" == "--pre-check" ]]; then
    PRE_CHECK=true
fi

# --- Failure logging ---
log_failure() {
    local check_id="$1"
    local file="$2"
    local summary="$3"
    mkdir -p "$LOG_DIR"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $check_id | $file | $summary" >> "$LOG_FILE"
}

# --- Source file discovery (shared) ---
discover_source_files() {
    git ls-files --cached --others --exclude-standard 2>/dev/null \
        | grep -vE '\.(lock|sum|mod|pbxproj|md|txt|json|yaml|yml|toml|conf|sh)$' \
    || find . -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.java" \) \
        ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" 2>/dev/null
}

# ============================================================
# P0-001: No hardcoded secrets
# ============================================================
check_secrets() {
    if [[ "$PRE_CHECK" == true ]]; then return; fi

    local pattern='(api[_-]?key|secret|password|token|private[_-]?key|auth[_-]?token|bearer)\s*[:=]\s*["\x27][^"\x27]{8,}'
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null \
        | grep -vE '\.(lock|sum|mod|pbxproj)$' \
        || find . -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.java" \) \
            ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" 2>/dev/null)

    local matches
    matches=$(echo "$files" | xargs grep -liE "$pattern" 2>/dev/null || true)

    if [ -n "$matches" ]; then
        echo "CRITICAL P0-001: Hardcoded secrets detected"
        echo ""
        echo "  Why: Secrets in source code leak via git history, CI logs, and error reports."
        echo "  Once pushed, they are permanently exposed even if deleted later."
        echo ""
        echo "$matches" | while read -r f; do
            echo "  File: $f"
            local lines
            lines=$(grep -nE "$pattern" "$f" 2>/dev/null | head -3 || true)
            if [ -n "$lines" ]; then
                echo "$lines" | while read -r line; do echo "    $line"; done
            fi
        done
        echo ""
        echo "  Fix: 1) Move each value to a .env file or secret manager"
        echo "       2) Reference via environment variable (e.g., process.env.API_KEY, os.environ['API_KEY'])"
        echo "       3) Add the secret file to .gitignore"
        echo "       4) If already committed, rotate the secret immediately"
        echo "  Reference: See project security.md > Secret Management"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
        log_failure "P0-001" "$(echo "$matches" | tr '\n' ',')" "Hardcoded secrets found"
    else
        echo "PASS P0-001: No hardcoded secrets"
    fi
}

# ============================================================
# P0-002: File size limit (800 lines)
# ============================================================
check_file_size() {
    if [[ "$PRE_CHECK" == true ]]; then return; fi

    local MAX_LINES=800
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null \
        | grep -vE '\.(lock|sum|min\.js|min\.css|generated|pb\.go)$' \
        || find . -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.java" \) \
            ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" 2>/dev/null)

    local oversize
    oversize=$(echo "$files" | while read -r f; do
        [ -z "$f" ] && continue
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        if [ "$lines" -gt "$MAX_LINES" ]; then
            echo "$f ($lines lines)"
        fi
    done)

    if [ -n "$oversize" ]; then
        echo "CRITICAL P0-002: Files exceed ${MAX_LINES}-line limit"
        echo ""
        echo "  Why: Large files indicate mixed responsibilities, making code harder for"
        echo "  agents to understand, modify, and test. Each file should have one clear purpose."
        echo ""
        echo "$oversize" | while read -r line; do
            echo "  $line"
        done
        echo ""
        echo "  Fix: 1) Identify the file's distinct responsibilities"
        echo "       2) Extract each responsibility into its own focused file"
        echo "       3) Re-export from the original file if needed for backward compatibility"
        echo "  Target: Each file < ${MAX_LINES} lines, one clear responsibility"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
        log_failure "P0-002" "$(echo "$oversize" | tr '\n' ',')" "Files exceed ${MAX_LINES} line limit"
    else
        echo "PASS P0-002: All files under ${MAX_LINES} lines"
    fi
}

# ============================================================
# P0-003: No TODO/FIXME in staged changes
# ============================================================
check_todos() {
    if [[ "$PRE_CHECK" == true ]]; then return; fi

    local todos
    todos=$(git diff --cached --name-only 2>/dev/null | xargs grep -nE '(TODO|FIXME|HACK|XXX):' 2>/dev/null || true)

    # If no git staging, check all tracked source files
    if [ -z "$todos" ]; then
        todos=$(git ls-files --cached 2>/dev/null | grep -vE '\.(lock|sum|mod)$' | xargs grep -nE '(TODO|FIXME|HACK|XXX):' 2>/dev/null || true)
    fi

    if [ -n "$todos" ]; then
        echo "WARNING P0-003: TODO/FIXME residuals found (advisory, not blocking)"
        echo ""
        echo "  Why: Leftover TODOs indicate incomplete work or tracked debt."
        echo "  They accumulate and obscure real issues. Resolve or convert to tracked issues."
        echo ""
        echo "$todos" | head -5
        echo ""
        echo "  Fix: 1) If the work is done, remove the TODO"
        echo "       2) If it's real debt, create a tracked issue and reference it: TODO(#123)"
        echo "       3) If it's a hack, document WHY and add a linked issue"
        echo ""
    else
        echo "PASS P0-003: No TODO/FIXME residuals"
    fi
}

# ============================================================
# P0-004: Worker Discoveries appended to context.md
# ============================================================
check_worker_discoveries() {
    if [[ "$PRE_CHECK" == true ]]; then return; fi

    local context_files
    context_files=$(find .harness/file-stack -name "context.md" 2>/dev/null || true)

    if [ -z "$context_files" ]; then
        echo "INFO P0-004: No context.md files found (may be first milestone)"
        return
    fi

    local all_valid=true
    for f in $context_files; do
        if grep -q "## Worker Discoveries" "$f" 2>/dev/null; then
            local discoveries
            discoveries=$(awk '/^## Worker Discoveries/,/^##|^$/ {if(/^## Worker Discoveries/){next}; if(/^- \[M[0-9]+\]/){print}}' "$f" 2>/dev/null || true)

            if [ -n "$discoveries" ]; then
                local invalid
                invalid=$(echo "$discoveries" | grep -vE '^\- \[M[0-9]+\] ' || true)
                if [ -n "$invalid" ]; then
                    echo "WARNING P0-004: Malformed Worker Discoveries in $f:"
                    echo "  Why: Worker Discoveries must use format: \`- [M{n}] description\`"
                    echo "  This ensures discoveries are traceable to specific milestones."
                    echo "$invalid" | head -3 | while read -r line; do echo "    $line"; done
                    echo "  Fix: Reformat as: - [M{n}] description of discovery"
                    all_valid=false
                else
                    echo "PASS P0-004: Worker Discoveries well-formed ($(echo "$discoveries" | wc -l | tr -d ' ') entries in $f)"
                fi
            else
                echo "INFO P0-004: Worker Discoveries section empty in $f (no new discoveries this milestone)"
            fi
        fi
    done
}

# ============================================================
# P0-005: Architecture boundary check (optional)
# ============================================================
check_architecture() {
    local layers_file=".harness/golden-principles/layers.conf"
    if [[ ! -f "$layers_file" ]]; then
        echo "SKIP P0-005: No layer definitions found"
        echo "  To enable: create $layers_file with layer definitions"
        echo "  See .harness/golden-principles/layers.conf.example for template"
        return
    fi

    # Parse layers.conf: lines of "layer_number  directory_name"
    local -a dir_names=()
    local -a layer_nums=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        line="${line%%#*}"  # Remove inline comments
        line="${line#"${line%%[![:space:]]*}"}"  # Trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Trim trailing whitespace
        [[ -z "$line" ]] && continue
        # Parse: "0  types" → num=0, dir=types
        local num="${line%%[[:space:]]*}"
        local dir="${line#*[[:space:]]}"
        dir="${dir#"${dir%%[![:space:]]*}"}"
        # Validate: num must be digit, dir must be non-empty
        [[ "$num" =~ ^[0-9]+$ ]] || continue
        [[ -n "$dir" ]] || continue
        dir_names+=("$dir")
        layer_nums+=("$num")
    done < "$layers_file"

    if [[ ${#dir_names[@]} -eq 0 ]]; then
        echo "SKIP P0-005: layers.conf has no valid definitions"
        return
    fi

    # Determine layer for a file path
    # Returns the LOWEST matching layer number (most restrictive)
    get_layer() {
        local filepath="$1"
        local result=""
        for i in "${!dir_names[@]}"; do
            if [[ "/$filepath/" == */"${dir_names[$i]}"/* ]]; then
                if [[ -z "$result" ]] || [[ "${layer_nums[$i]}" -lt "$result" ]]; then
                    result="${layer_nums[$i]}"
                fi
            fi
        done
        echo "$result"
    }

    # Determine layer for an import path
    get_import_layer() {
        local imp_path="$1"
        for i in "${!dir_names[@]}"; do
            # Match: import path contains a layer directory as a component
            if [[ "/$imp_path/" == */"${dir_names[$i]}"/* ]] || [[ "$imp_path" == "${dir_names[$i]}" ]]; then
                echo "${layer_nums[$i]}"
                return
            fi
        done
        echo ""
    }

    local source_files
    source_files=$(discover_source_files)
    local arch_violations=0

    for f in $source_files; do
        [[ -z "$f" ]] && continue
        [[ ! -f "$f" ]] && continue

        # Get source file's layer
        local src_layer
        src_layer=$(get_layer "$f")
        [[ -z "$src_layer" ]] && continue

        # Extract import targets (language-agnostic heuristic)
        local imports
        imports=$({
            # Python: from X.Y import → X/Y
            grep -oE '(from|import)\s+[a-zA-Z_][a-zA-Z0-9_.]*' "$f" 2>/dev/null | \
                sed -E 's/^(from|import)[[:space:]]+//' | tr '.' '/' || true
            # TypeScript/JavaScript: from 'X' or require('X')
            grep -oE "(from\s+['\"][^'\"]+['\"]|require\s*\(['\"][^'\"]+['\"])" "$f" 2>/dev/null | \
                sed -E "s/(from|require)\s*[\('\"]+//;s/['\")]$//" | sed 's/^\.\///' | sed 's/^\.\.\///' || true
            # Go: import "X"
            grep -oE '"[^"]+"' "$f" 2>/dev/null | \
                sed -E 's/"//g' | awk -F'/' '{print $NF}' || true
        } | sort -u || true)

        for imp in $imports; do
            [[ -z "$imp" ]] && continue
            local imp_layer
            imp_layer=$(get_import_layer "$imp")
            [[ -z "$imp_layer" ]] && continue

            # Rule: source layer must be >= import layer
            # (higher layers CAN import lower layers)
            if [[ "$src_layer" -lt "$imp_layer" ]]; then
                if [[ $arch_violations -eq 0 ]]; then
                    echo "CRITICAL P0-005: Architecture boundary violations detected"
                    echo ""
                    echo "  Why: Lower layers must not depend on higher layers."
                    echo "  This keeps the dependency graph acyclic and modules independently testable."
                    echo ""
                fi
                echo "  File: $f (Layer $src_layer) → imports '$imp' (Layer $imp_layer)"
                arch_violations=$((arch_violations + 1))
            fi
        done
    done

    if [[ $arch_violations -gt 0 ]]; then
        echo ""
        echo "  Rule: Higher layers CAN import lower layers. Reverse is FORBIDDEN."
        echo "  Layer mapping:"
        for i in "${!dir_names[@]}"; do
            echo "    Layer ${layer_nums[$i]}: ${dir_names[$i]}/"
        done
        echo ""
        echo "  Fix: 1) Move the shared logic down to a lower layer that both can import"
        echo "       2) Pass the dependency as a parameter instead of importing it"
        echo "       3) If the layer assignment is wrong, update $layers_file"
        echo ""
        VIOLATIONS=$((VIOLATIONS + 1))
        log_failure "P0-005" "multiple" "$arch_violations architecture boundary violations"
    else
        echo "PASS P0-005: Architecture boundaries respected"
    fi
}

# ============================================================
# Main execution
# ============================================================
echo "=== P0 Universal Checks ==="
echo "Project: $PROJECT_ROOT"
if [[ "$PRE_CHECK" == true ]]; then
    echo "Mode: PRE-CHECK (architecture boundary only)"
fi
echo ""

if [[ "$PRE_CHECK" == true ]]; then
    # Pre-validation mode: only architecture check
    check_architecture
else
    # Full check suite
    check_secrets
    check_file_size
    check_todos
    check_worker_discoveries
    check_architecture
fi

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "FAILED: $VIOLATIONS CRITICAL violation(s) found"
    exit 1
else
    echo "PASSED: All P0 checks clean"
    exit 0
fi
