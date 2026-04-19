#!/usr/bin/env python3
"""Validate MarkdownPreview project consistency."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd, cwd=None):
    """Run a command and report results."""
    if cwd is None:
        cwd = ROOT
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    if result.returncode != 0:
        print(f"  Command: {' '.join(cmd)}")
        if result.stdout:
            print(f"  stdout: {result.stdout[:500]}")
        if result.stderr:
            print(f"  stderr: {result.stderr[:500]}")
    return result.returncode == 0


def main():
    """Run all validation steps."""
    print("=" * 60)
    print("MarkdownPreview Validation Pipeline")
    print("=" * 60)
    print()

    steps = [
        ("Build", ["swift", "build"]),
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["swift", "test"]),
    ]

    results = []
    for name, cmd in steps:
        success = run(name, cmd)
        results.append((name, success))
        print()

    # Summary
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    passed = sum(1 for _, s in results if s)
    total = len(results)
    print(f"{passed}/{total} checks passed")

    if passed == total:
        print("All validations passed!")
        sys.exit(0)
    else:
        print("Some validations failed:")
        for name, success in results:
            if not success:
                print(f"  - {name}")
        sys.exit(1)


if __name__ == "__main__":
    main()
