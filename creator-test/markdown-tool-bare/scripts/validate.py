#!/usr/bin/env python3
"""Validate Swift project consistency. Runs: build -> lint-deps -> lint-quality -> test -> verify."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd, cwd=None):
    """Run command, return True if success. Print truncated output."""
    if cwd is None:
        cwd = ROOT
    print(f"\n[{name}]")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.stdout:
        output = result.stdout[:1000] if len(result.stdout) > 1000 else result.stdout
        print(output)
    if result.stderr:
        print(result.stderr[:500] if len(result.stderr) > 500 else result.stderr, file=sys.stderr)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    return result.returncode == 0


def main():
    print("Swift Project Validation Pipeline")
    print("=" * 60)

    steps = [
        ("Build", ["swift", "build"]),
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["swift", "test"]),
        ("Verify (E2E)", ["python3", "scripts/verify/run.py"]),
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
