#!/usr/bin/env bash
# pre-push-simplify.sh
# PreToolUse hook: blocks git push until /simplify reviews the code.
#
# TTL-based state:
#   1st push (no state)    → deny + write timestamp → Claude runs /simplify
#   2nd push (within 10m)  → allow + cleanup state  → push goes through
#   2nd push (after 10m)   → deny again (stale)     → re-run /simplify

input=$(cat)

# Cross-platform JSON parsing: prefer python3, fall back to node, then jq
command=$(echo "$input" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "$input" | node -e "
const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
console.log((d.tool_input||{}).command||'');
" 2>/dev/null || echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Cross-platform repo hash: shasum (macOS/BSD) or sha256sum (Linux)
if command -v shasum &>/dev/null; then
    REPO_KEY="$(pwd | shasum -a 256 | cut -c1-12)"
elif command -v sha256sum &>/dev/null; then
    REPO_KEY="$(pwd | sha256sum | cut -c1-12)"
else
    REPO_KEY="$(pwd | cksum | cut -d' ' -f1)"
fi

# User-scoped state file to avoid multi-user conflicts
STATE_FILE="${TMPDIR:-/tmp}/claude-simplify-${USER}-${REPO_KEY}"
TTL_SECONDS=600

# Only act on git push
if echo "$command" | grep -qE '^\s*git\s+push'; then
  if [ -f "$STATE_FILE" ]; then
    # Cross-platform stat: try BSD first, then GNU
    state_mtime=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE" 2>/dev/null || echo "")
    if [ -n "$state_mtime" ] && [ "$state_mtime" -eq "$state_mtime" ] 2>/dev/null; then
      now=$(date +%s)
      age=$(( now - state_mtime ))
      if [ "$age" -lt "$TTL_SECONDS" ]; then
        rm -f "$STATE_FILE"
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
EOF
        exit 0
      fi
    fi
  fi

  date +%s > "$STATE_FILE"
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git push blocked: run /simplify to review all changed code for reuse, quality, and efficiency before pushing. After /simplify completes and issues are addressed, retry the push."}}
EOF
  exit 0
fi

# Not git push — pass through
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
EOF
exit 0
