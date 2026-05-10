#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Harness Pro Plugin — One-Line Installer
# =============================================================================
# Usage:
#   curl -sSL https://raw.githubusercontent.com/josh-folder/harness-pro-plugin/main/install.sh | bash
#
# Or clone first:
#   git clone https://github.com/josh-folder/harness-pro-plugin.git
#   cd harness-pro-plugin && ./install.sh
# =============================================================================

REPO_URL="${REPO_URL:-https://github.com/josh-folder/harness-pro-plugin.git}"
PLUGIN_NAME="harness-pro-plugin"
MARKETPLACE_NAME="harness-pro-marketplace"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
PLUGINS_DIR="$CLAUDE_DIR/plugins"
MARKETPLACE_DIR="$PLUGINS_DIR/marketplaces/$MARKETPLACE_NAME"
KNOWN_MARKETPLACES_FILE="$PLUGINS_DIR/known_marketplaces.json"

colors() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
}
colors

info()  { echo -e "${BLUE}ℹ${NC}  $*"; }
ok()    { echo -e "${GREEN}✓${NC}  $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
error() { echo -e "${RED}✗${NC}  $*"; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v git &>/dev/null; then
    error "git is required but not installed."
    echo "   Install: brew install git   # macOS"
    echo "            apt-get install git # Ubuntu/Debian"
    exit 1
fi
ok "git found"

if ! command -v python3 &>/dev/null; then
    error "python3 is required but not installed."
    echo "   Install: brew install python3   # macOS"
    echo "            apt-get install python3 # Ubuntu/Debian"
    exit 1
fi
ok "python3 found"

if [[ ! -d "$CLAUDE_DIR" ]]; then
    error "Claude Code config directory not found: $CLAUDE_DIR"
    echo "   Please install Claude Code first: https://claude.ai/code"
    exit 1
fi
ok "Claude Code config directory: $CLAUDE_DIR"

# ---------------------------------------------------------------------------
# Clone / update marketplace
# ---------------------------------------------------------------------------
info "Setting up marketplace directory..."

if [[ -d "$MARKETPLACE_DIR/.git" ]]; then
    info "Existing marketplace found. Pulling latest..."
    git -C "$MARKETPLACE_DIR" pull --ff-only
else
    rm -rf "$MARKETPLACE_DIR"
    info "Cloning $REPO_URL ..."
    git clone --depth 1 "$REPO_URL" "$MARKETPLACE_DIR"
fi
ok "Marketplace ready: $MARKETPLACE_DIR"

# ---------------------------------------------------------------------------
# Register marketplace in known_marketplaces.json
# ---------------------------------------------------------------------------
info "Registering marketplace..."

python3 - "$MARKETPLACE_NAME" "$MARKETPLACE_DIR" "$KNOWN_MARKETPLACES_FILE" << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

name, path, known_file = sys.argv[1:4]

data = {}
if os.path.exists(known_file):
    with open(known_file, "r", encoding="utf-8") as f:
        data = json.load(f)

data[name] = {
    "source": {
        "source": "directory",
        "path": os.path.abspath(path)
    },
    "installLocation": os.path.abspath(path),
    "lastUpdated": datetime.now(timezone.utc).isoformat()
}

os.makedirs(os.path.dirname(known_file), exist_ok=True)
with open(known_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
    f.write("\n")

print(f"Registered marketplace: {name}")
PYEOF

ok "Marketplace registered"

# ---------------------------------------------------------------------------
# Install plugin via claude-plugin CLI
# ---------------------------------------------------------------------------
info "Installing plugin..."

cd "$MARKETPLACE_DIR"
if [[ -f "scripts/claude-plugin" ]]; then
    python3 scripts/claude-plugin install "$PLUGIN_NAME@$MARKETPLACE_NAME" --scope user
else
    error "claude-plugin CLI not found in scripts/"
    exit 1
fi

# ---------------------------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------------------------
info "Running health check..."
python3 scripts/claude-plugin doctor 2>/dev/null || true

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
ok "Installation complete!"
echo ""
echo "   Plugin:     $PLUGIN_NAME@$MARKETPLACE_NAME"
echo "   Cache:      $PLUGINS_DIR/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
echo ""
echo -e "   ${YELLOW}Next steps:${NC}"
echo "   1. Restart Claude Code, or"
echo "   2. Run '/reload' inside Claude Code, or"
echo "   3. Start a new Claude Code session"
echo ""
echo "   Then verify with: /harness-pro-doctor"
echo ""
