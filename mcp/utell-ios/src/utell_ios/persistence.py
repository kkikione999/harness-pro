"""Persistence verification utilities for iOS simulator app data."""

from __future__ import annotations

import os
import re
import shutil
import subprocess


def get_simulator_data_root(bundle_id: str) -> str:
    """Resolve the data directory for *bundle_id* on the booted simulator.

    First tries ``xcrun simctl get_app_container booted <bundle_id> data``.
    Falls back to constructing the path manually from the booted device UDID.
    """
    result = subprocess.run(
        ["xcrun", "simctl", "get_app_container", "booted", bundle_id, "data"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        return result.stdout.strip()

    # Fallback: construct path from booted device UDID
    booted = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "booted"],
        capture_output=True,
        text=True,
        check=False,
    )
    match = re.search(r"\(([0-9A-F-]{10,})\)", booted.stdout)
    if match:
        udid = match.group(1)
        return os.path.join(
            os.path.expanduser("~"),
            "Library", "Developer", "CoreSimulator", "Devices", udid, "data",
        )

    raise RuntimeError("Cannot determine simulator data directory")


def search_token_in_storage(data_root: str, token: str) -> dict:
    """Search *data_root* for *token* using ripgrep.

    Returns ``{"found": bool, "matches": list[str], "count": int}``.
    If ripgrep exits non-zero (no matches or error), returns
    ``{"found": False, "matches": []}``.
    """
    rg_path = shutil.which("rg")
    if rg_path is None:
        raise RuntimeError(
            "ripgrep (rg) is not installed. Install it via: brew install ripgrep "
            "(macOS) or apt install ripgrep (Linux)"
        )

    result = subprocess.run(
        [rg_path, "-a", "-F", "-n", token, data_root],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        return {"found": False, "matches": [], "count": 0}

    lines = [line for line in result.stdout.strip().split("\n") if line]
    return {"found": True, "matches": lines, "count": len(lines)}


def verify_persistence(
    bundle_id: str,
    token: str,
    expected_format: str | None = None,
    *,
    data_root: str | None = None,
) -> dict:
    """Full persistence verification for *token* in the app's data storage.

    If *expected_format* is provided, the formatted token is searched first.
    Falls back to searching the raw *token*.

    Returns ``{"pass": bool, "level": str, "detail": str, "matches": list}``.
    """
    data_root = data_root or get_simulator_data_root(bundle_id)

    # Search formatted form first when an expected format is given
    if expected_format:
        formatted = search_token_in_storage(data_root, expected_format)
        if formatted["found"]:
            return {
                "pass": True,
                "level": "full",
                "detail": f"Formatted token found: {expected_format}",
                "matches": formatted["matches"],
            }

    # Search raw token
    raw = search_token_in_storage(data_root, token)
    if raw["found"]:
        if expected_format:
            return {
                "pass": False,
                "level": "partial",
                "detail": f"Raw token found but formatting not applied: {token}",
                "matches": raw["matches"],
            }
        return {
            "pass": True,
            "level": "full",
            "detail": f"Token found: {token}",
            "matches": raw["matches"],
        }

    return {
        "pass": False,
        "level": "none",
        "detail": f"Token not found: {token}",
        "matches": [],
    }
