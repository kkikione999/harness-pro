"""Compile SwiftUI thunk code into a dylib for hot-reload injection."""

from __future__ import annotations

import json
import platform
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CompileResult:
    success: bool
    dylib_path: str | None = None
    stderr: str = ""


_cached_sdk_path: str | None = None


def _get_host_arch() -> str:
    """Detect the host CPU architecture for simulator target triple."""
    machine = platform.machine()
    if machine in ("arm64", "aarch64"):
        return "arm64"
    if machine in ("x86_64", "amd64"):
        return "x86_64"
    return machine


def get_simulator_os_version() -> str:
    """Detect the OS version of the booted iOS simulator."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "booted", "-j"],
            capture_output=True, text=True, check=False,
        )
        data = json.loads(result.stdout)
        for runtime, devices in data.get("devices", {}).items():
            for device in devices:
                if device.get("state") == "Booted":
                    for part in runtime.split("."):
                        if part.startswith("iOS-"):
                            return part[4:].replace("-", ".")
    except Exception:
        pass
    return _fallback_os_version()


def _fallback_os_version() -> str:
    """Best-effort OS version from the installed simulator SDK."""
    try:
        result = subprocess.run(
            ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
            capture_output=True, text=True, check=False,
        )
        version = result.stdout.strip()
        if version and version[0].isdigit():
            return version
    except Exception:
        pass
    return "18.0"


def get_simulator_sdk_version() -> str:
    """Return the Xcode SDK version (kept for backwards compatibility)."""
    return get_simulator_os_version()


def _get_simulator_sdk_path() -> str:
    global _cached_sdk_path
    if _cached_sdk_path is not None:
        return _cached_sdk_path
    result = subprocess.run(
        ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"],
        capture_output=True, text=True, check=False,
    )
    _cached_sdk_path = result.stdout.strip()
    return _cached_sdk_path


def discover_framework_search_paths(build_products_dir: str) -> list[str]:
    """Find parent directories of .framework bundles for use with -F flags."""
    products_path = Path(build_products_dir)
    parent_dirs: set[str] = set()
    for fw in products_path.glob("*.framework"):
        parent_dirs.add(str(fw.parent))
    return sorted(parent_dirs)


def compile_thunk(
    thunk_source_path: str,
    output_dylib_path: str,
    build_products_dir: str,
    product_name: str,
    sdk_version: str = "",
) -> CompileResult:
    if not sdk_version:
        sdk_version = get_simulator_os_version()

    sdk_path = _get_simulator_sdk_path()

    framework_flags: list[str] = []
    for fw_dir in discover_framework_search_paths(build_products_dir):
        framework_flags.extend(["-F", fw_dir])

    cmd = [
        "xcrun", "swiftc",
        "-target", f"{_get_host_arch()}-apple-ios{sdk_version}-simulator",
        "-sdk", sdk_path,
        "-emit-library",
        "-module-name", "thunk",
        "-o", output_dylib_path,
        thunk_source_path,
        "-I", build_products_dir,
        *framework_flags,
        "-Xfrontend", "-enable-private-imports",
        "-Xlinker", "-undefined",
        "-Xlinker", "dynamic_lookup",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return CompileResult(success=False, stderr=result.stderr)

    codesign = subprocess.run(
        ["codesign", "-f", "-s", "-", output_dylib_path],
        capture_output=True, text=True, check=False,
    )
    if codesign.returncode != 0:
        return CompileResult(success=False, stderr=f"codesign failed: {codesign.stderr}")

    return CompileResult(success=True, dylib_path=output_dylib_path)
