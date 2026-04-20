#!/usr/bin/env python3
"""E2E verification runner for MarkdownPreview."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent


def run(name, cmd, cwd=None):
    """Run command, return True if success."""
    if cwd is None:
        cwd = ROOT
    print(f"\n[{name}]")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.stdout:
        output = result.stdout[:1000]
        print(output)
    if result.stderr:
        print(result.stderr[:500], file=sys.stderr)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    return result.returncode == 0


def main():
    print("MarkdownPreview E2E Verification")
    print("=" * 60)

    # Verify the smoke test passes (builds app, opens files, checks windows)
    smoke_ok = run("Smoke Test", ["bash", "scripts/test_smoke.sh"])

    if smoke_ok:
        print("\nE2E verification passed!")
        return True
    else:
        print("\nE2E verification failed!")
        return False


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
