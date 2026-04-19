#!/usr/bin/env python3
"""Validate project consistency. Runs: build -> lint-deps -> lint-quality -> test -> verify."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd, cwd=None):
    """Run command, return True if success. Print truncated output."""
    if cwd is None:
        cwd = ROOT
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    if result.stdout:
        print(result.stdout[:500] if len(result.stdout) > 500 else result.stdout)
    if result.stderr:
        print(result.stderr[:500] if len(result.stderr) > 500 else result.stderr, file=sys.stderr)
    return result.returncode == 0


def main():
    print("Validation Pipeline")
    print("=" * 60)

    steps = [
        ("Build", ["swift", "build"]),
        ("Lint Architecture (lint-deps)", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["swift", "test"]),
        ("Verify (E2E)", ["python3", "scripts/verify/run.py"]),  # E2E verification
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    total = len(steps)

    print(f"\n{'=' * 60}")
    print(f"Passed: {passed}/{total}")
    if passed == total:
        print("All validations passed!")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
