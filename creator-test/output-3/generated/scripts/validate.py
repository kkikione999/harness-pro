#!/usr/bin/env python3
"""
validate.py - Full validation pipeline for MarkdownPreview
Runs: build → lint-arch → lint-quality → test → verify (E2E)
"""

import subprocess
import sys
import os
from pathlib import Path

# Allow override via environment variable for testing
MARKDOWN_PREVIEW_ROOT = os.environ.get("MARKDOWN_PREVIEW_ROOT")
SCRIPT_DIR = Path(__file__).resolve().parent
if MARKDOWN_PREVIEW_ROOT:
    PROJECT_ROOT = Path(MARKDOWN_PREVIEW_ROOT)
else:
    PROJECT_ROOT = SCRIPT_DIR.parent


def run_command(cmd, description, timeout=300):
    """Run a command and return success status."""
    print(f"\n{'='*60}")
    print(f"  {description}")
    print(f"{'='*60}")

    try:
        result = subprocess.run(
            cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout
        )

        if result.stdout:
            print(result.stdout[:500] if len(result.stdout) > 500 else result.stdout)
        if result.stderr:
            print(result.stderr[:500] if len(result.stderr) > 500 else result.stderr, file=sys.stderr)

        status = "PASS" if result.returncode == 0 else "FAIL"
        print(f"[{status}] {description}")
        return result.returncode == 0

    except subprocess.TimeoutExpired:
        print(f"[FAIL] {description} (timeout after {timeout}s)")
        return False
    except Exception as e:
        print(f"[FAIL] {description}: {e}")
        return False


def main():
    print("Validation Pipeline")
    print("=" * 60)

    # Build command paths relative to PROJECT_ROOT
    lint_deps = str(SCRIPT_DIR / "lint-deps")
    lint_quality = str(SCRIPT_DIR / "lint-quality")
    verify_run = str(SCRIPT_DIR / "verify" / "run.py")

    steps = [
        (["swift", "build"], "Build"),
        (["bash", lint_deps], "Lint Architecture"),
        (["bash", lint_quality], "Lint Quality"),
        (["swift", "test"], "Test"),
        (["python3", verify_run], "Verify (E2E)"),
    ]

    passed = sum(1 for cmd, name in steps if run_command(cmd, name))
    total = len(steps)

    print(f"\n{'='*60}")
    print(f"Passed: {passed}/{total}")
    if passed == total:
        print("All validations passed!")
        return 0
    else:
        print("Some validations failed:")
        for cmd, name in steps:
            if not run_command(cmd, name):
                print(f"  - {name}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
