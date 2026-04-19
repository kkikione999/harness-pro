#!/usr/bin/env python3
"""E2E verification for MarkdownPreview.

This script verifies the application works correctly in an end-to-end scenario.
TODO: Fill in actual E2E verification logic based on your application.

Verification scenarios to implement:
1. App launches without crashing
2. Can open a markdown file via command line
3. File changes are detected and UI updates
4. Link clicking opens new windows correctly
"""

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent


def run(name, cmd, cwd=None, timeout=30):
    """Run command, return True if success."""
    if cwd is None:
        cwd = ROOT
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        status = "PASS" if result.returncode == 0 else "FAIL"
        print(f"[{status}] {name}")
        if result.stdout:
            print(result.stdout[:300] if len(result.stdout) > 300 else result.stdout)
        if result.stderr:
            print(result.stderr[:300] if len(result.stderr) > 300 else result.stderr, file=sys.stderr)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"[FAIL] {name} (timeout after {timeout}s)")
        return False


def main():
    print("E2E Verification")
    print("=" * 60)

    # TODO: Implement actual E2E tests
    # Example structure:
    # 1. Build app bundle
    # 2. Launch app with test file
    # 3. Verify window appears
    # 4. Verify content renders

    steps = [
        # ("Build App", ["./scripts/build_app.sh"]),
        # ("Launch and Verify Window", ["python3", "scripts/verify/test_window.py"]),
        # ("Test File Open", ["python3", "scripts/verify/test_file_open.py"]),
    ]

    if not steps:
        print("NOTE: E2E tests not yet implemented")
        print("  - Build app: ./scripts/build_app.sh")
        print("  - Run smoke test: ./scripts/test_smoke.sh")
        print("  - Manual testing recommended")
        print("")
        # For now, just check if app bundle exists
        app_bundle = ROOT / "dist/MarkdownPreview.app"
        if app_bundle.exists():
            print(f"[PASS] App bundle exists at {app_bundle}")
            return True
        else:
            print(f"[FAIL] App bundle not found at {app_bundle}")
            print("  Run ./scripts/build_app.sh first")
            return False

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    total = len(steps)

    print(f"\n{'=' * 60}")
    print(f"Passed: {passed}/{total}")
    return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
