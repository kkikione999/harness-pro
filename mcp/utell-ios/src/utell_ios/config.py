"""Lightweight config persistence for utell-ios.

Stores per-project bundle IDs in ``$CLAUDE_PLUGIN_DATA/config.json``
so that auto-detected settings survive server restarts.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any


def _config_path() -> Path:
    """Return the path to the config file inside ``CLAUDE_PLUGIN_DATA``."""
    data_dir = os.environ.get("CLAUDE_PLUGIN_DATA", "")
    if data_dir:
        return Path(data_dir) / "config.json"
    return Path(tempfile.gettempdir()) / "utell-ios-config.json"


def load_config() -> dict[str, Any]:
    """Load the persisted config, returning an empty dict on any failure."""
    path = _config_path()
    if path.is_file():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def save_config(config: dict[str, Any]) -> None:
    """Atomically write *config* to disk."""
    path = _config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(config, indent=2, ensure_ascii=False)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(data, encoding="utf-8")
    tmp.replace(path)


def get_bundle_id(project_path: str) -> str | None:
    """Return the persisted bundle ID for *project_path*, or ``None``."""
    config = load_config()
    return config.get("projects", {}).get(project_path)


def set_bundle_id(project_path: str, bundle_id: str) -> None:
    """Persist *bundle_id* for *project_path*."""
    config = load_config()
    projects = config.setdefault("projects", {})
    projects[project_path] = bundle_id
    save_config(config)


def detect_bundle_id(project_path: str) -> str | None:
    """Auto-detect ``PRODUCT_BUNDLE_IDENTIFIER`` from an Xcode project.

    Prefers ``.xcworkspace`` over ``.xcodeproj`` (matches the pattern in
    ``preview_loader._resolve_xcode_flag``).  Returns ``None`` when no
    Xcode project is found or ``xcodebuild`` cannot determine the ID.
    """
    root = Path(project_path)

    # Prefer workspace, then project
    workspaces = sorted(root.glob("*.xcworkspace"))
    projects = sorted(root.glob("*.xcodeproj"))

    xcode_path: Path | None = None
    xcode_flag: list[str] = []
    if workspaces:
        xcode_path = workspaces[0]
        xcode_flag = ["-workspace", str(xcode_path)]
    elif projects:
        xcode_path = projects[0]
        xcode_flag = ["-project", str(xcode_path)]

    if xcode_path is None:
        return None

    cmd = ["xcodebuild", "-showBuildSettings", *xcode_flag]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith("PRODUCT_BUNDLE_IDENTIFIER"):
            _, _, value = stripped.partition("=")
            bundle_id = value.strip()
            if bundle_id:
                return bundle_id

    return None
