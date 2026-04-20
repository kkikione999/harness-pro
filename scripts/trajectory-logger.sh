#!/bin/bash
# trajectory-logger.sh
# PostToolUse hook — mechanically logs every tool call to JSONL.
# No AI involved. Pure deterministic recording.
#
# Hook receives JSON on stdin:
#   session_id, tool_name, tool_input, tool_response, tool_use_id, cwd
#
# Output: harness/trace/trajectories/{session_id}.jsonl

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Extract fields with python (jq may not be available)
SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_id', 'unknown'))
" 2>/dev/null || echo "unknown")

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('tool_name', 'unknown'))
" 2>/dev/null || echo "unknown")

CWD=$(echo "$INPUT" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('cwd', ''))
" 2>/dev/null || echo "")

# Build log entry with python (handles escaping properly)
TRAJ_DIR="${CLAUDE_PROJECT_DIR:-$(git -C "${CWD:-.}" rev-parse --show-toplevel 2>/dev/null || echo "$HOME")}/harness/trace/trajectories"
mkdir -p "$TRAJ_DIR"

echo "$INPUT" | python3 -c "
import sys, json, re, os
from datetime import datetime

d = json.load(sys.stdin)

# Normalize paths to be project-agnostic
def normalize(s):
    if not isinstance(s, str):
        return s
    home = os.path.expanduser('~')
    s = s.replace(home, '\$HOME')
    # Collapse any project variant
    s = re.sub(r'\$HOME/hp-sleeper[A-Za-z0-9_-]*', '\$PROJECT', s)
    s = re.sub(r'\$HOME/harness-simple', '\$SKILL_ROOT', s)
    return s

tool_input = d.get('tool_input', {})
tool_response = d.get('tool_response', {})

# For Bash commands, extract just the command string
command = ''
if d.get('tool_name') == 'Bash' and isinstance(tool_input, dict):
    command = tool_input.get('command', '')

# For Edit/Write, extract file path
file_path = ''
if d.get('tool_name') in ('Edit', 'Write') and isinstance(tool_input, dict):
    file_path = tool_input.get('file_path', '')
    file_path = normalize(file_path)

# Truncate tool_response preview
response_preview = ''
if isinstance(tool_response, dict):
    response_preview = json.dumps(tool_response)[:200]
elif isinstance(tool_response, str):
    response_preview = tool_response[:200]

entry = {
    'ts': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'session': d.get('session_id', 'unknown'),
    'tool': d.get('tool_name', 'unknown'),
    'cwd': normalize(d.get('cwd', '')),
    'command': normalize(command),
    'file': file_path,
    'response_preview': response_preview
}

session_id = d.get('session_id', 'unknown')
# Sanitize session_id for filename
safe_id = re.sub(r'[^a-zA-Z0-9_-]', '_', session_id)
log_file = os.path.join('$TRAJ_DIR', f'{safe_id}.jsonl')

with open(log_file, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
" 2>/dev/null

exit 0
