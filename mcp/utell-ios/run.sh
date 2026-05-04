#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if command -v uv &>/dev/null; then
    exec uv run --project "$SCRIPT_DIR" utell-ios
elif command -v python3 &>/dev/null; then
    VENV_DIR="$SCRIPT_DIR/.venv"
    if [ ! -d "$VENV_DIR" ]; then
        if ! python3 -m venv "$VENV_DIR" 2>/dev/null; then
            # venv module unavailable — install pip --user as fallback
            echo "[utell-ios] python3-venv not available, using pip --user fallback" >&2
            pip3 install --user --quiet "mcp>=1.0.0" 2>/dev/null || {
                echo "Error: Failed to install mcp via pip. Run: pip3 install mcp" >&2
                exit 1
            }
            PYTHONPATH="$SCRIPT_DIR/src" exec python3 -m utell_ios.server
        fi
        "$VENV_DIR/bin/pip" install -q "mcp>=1.0.0" || {
            echo "Error: Failed to install mcp package into venv. Check pip logs above." >&2
            rm -rf "$VENV_DIR"
            exit 1
        }
    fi
    PYTHONPATH="$SCRIPT_DIR/src" exec "$VENV_DIR/bin/python" -m utell_ios.server
else
    echo "Error: Neither uv nor python3 found. Please install one of them." >&2
    exit 1
fi
