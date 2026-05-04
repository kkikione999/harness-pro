#!/usr/bin/env bash
# install-lsp-deps.sh
# SessionStart hook: idempotently installs language server binaries.
# Runs on every session start; exits quickly if everything is already installed.
# Only marks a dependency as installed after verifying the binary is on PATH.

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/harness-pro-plugin}"
mkdir -p "$STATE_DIR"
STATE_FILE="${STATE_DIR}/.lsp-installed"
touch "$STATE_FILE"

is_installed() { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }
mark_installed() { is_installed "$1" || echo "$1" >> "$STATE_FILE"; }
unmark_installed() { [ -f "$STATE_FILE" ] && sed -i.bak "/^${1}$/d" "$STATE_FILE" && rm -f "$STATE_FILE.bak"; }
log() { echo "[harness-pro-plugin/lsp-setup] $*" >&2; }

CHANGED=0

# --- TypeScript Language Server ---
if ! is_installed "typescript-language-server" || ! command -v typescript-language-server &>/dev/null; then
  unmark_installed "typescript-language-server"
  if command -v typescript-language-server &>/dev/null; then
    log "typescript-language-server already present"
  else
    log "Installing typescript-language-server + typescript via npm..."
    npm i -g typescript-language-server typescript 2>&1 | while IFS= read -r line; do log "  $line"; done
    if command -v typescript-language-server &>/dev/null; then
      log "typescript-language-server installed successfully"
    else
      log "WARNING: typescript-language-server installation may have failed (npm prefix may not be on PATH)"
    fi
  fi
  command -v typescript-language-server &>/dev/null && mark_installed "typescript-language-server"
  CHANGED=1
fi

# --- sourcekit-lsp (Xcode bundled) ---
if ! is_installed "sourcekit-lsp" || ! command -v sourcekit-lsp &>/dev/null; then
  unmark_installed "sourcekit-lsp"
  if command -v sourcekit-lsp &>/dev/null; then
    log "sourcekit-lsp available"
  else
    log "WARNING: sourcekit-lsp not found. Install Xcode CLI tools: xcode-select --install"
  fi
  command -v sourcekit-lsp &>/dev/null && mark_installed "sourcekit-lsp"
  CHANGED=1
fi

# --- gopls ---
if ! is_installed "gopls" || ! command -v gopls &>/dev/null; then
  unmark_installed "gopls"
  if command -v gopls &>/dev/null; then
    log "gopls already present"
  else
    if command -v go &>/dev/null; then
      log "Installing gopls via go install..."
      go install golang.org/x/tools/gopls@latest 2>&1 | while IFS= read -r line; do log "  $line"; done
      if command -v gopls &>/dev/null; then
        log "gopls installed successfully"
      else
        log "WARNING: gopls installed but not on PATH — add \$(go env GOPATH)/bin to your PATH"
      fi
    else
      log "WARNING: gopls not installed - Go toolchain not found. Install Go: https://go.dev/dl/"
    fi
  fi
  command -v gopls &>/dev/null && mark_installed "gopls"
  CHANGED=1
fi

# --- Pyright ---
if ! is_installed "pyright" || ! command -v pyright-langserver &>/dev/null; then
  unmark_installed "pyright"
  if command -v pyright-langserver &>/dev/null; then
    log "pyright already present"
  else
    log "Installing pyright via npm..."
    npm i -g pyright 2>&1 | while IFS= read -r line; do log "  $line"; done
    if command -v pyright-langserver &>/dev/null; then
      log "pyright installed successfully"
    else
      log "WARNING: pyright installation may have failed (npm prefix may not be on PATH)"
    fi
  fi
  command -v pyright-langserver &>/dev/null && mark_installed "pyright"
  CHANGED=1
fi

if [ "$CHANGED" -eq 0 ]; then
  log "All LSP dependencies satisfied (cached)"
fi
