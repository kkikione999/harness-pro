"""Orchestrator for SwiftUI hot-reload preview system."""

from __future__ import annotations

import base64
import json
import logging
import os
import platform
import shutil
import socket
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from utell_ios import swift_parser, thunk_compiler, thunk_generator
from utell_ios.bridge_client import IOSBridgeClient

logger = logging.getLogger(__name__)

_TMP_BASE = Path(tempfile.gettempdir())
_STATE_PATH = _TMP_BASE / "utell_preview_state.json"
_DERIVED_DATA_PATH = _TMP_BASE / "utell_ios_preview_build"

_LOADER_DYLIB = Path(__file__).parent / "native" / "loader.dylib"


def _get_simulator_destination() -> str:
    """Detect the booted iOS simulator and return an xcodebuild destination string."""
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
                            ver = part[4:].replace("-", ".")
                            return (
                                f"platform=iOS Simulator,"
                                f"name={device['name']},OS={ver}"
                            )
    except Exception:
        pass
    return _fallback_simulator_destination()


def _fallback_simulator_destination() -> str:
    """Return a best-effort simulator destination when no booted device is found."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            capture_output=True, text=True, check=False,
        )
        data = json.loads(result.stdout)
        for runtime, devices in data.get("devices", {}).items():
            if "iOS" not in runtime:
                continue
            for device in devices:
                if device.get("isAvailable"):
                    name = device["name"]
                    for part in runtime.split("."):
                        if part.startswith("iOS-"):
                            ver = part[4:].replace("-", ".")
                            return f"platform=iOS Simulator,name={name},OS={ver}"
    except Exception:
        pass
    return "platform=iOS Simulator,name=iPhone 16"


_cached_has_watchos: dict[str, bool] = {}


def _scheme_has_watchos_targets(scheme: str, xcode_flag: list[str]) -> bool:
    """Detect whether the project contains watchOS targets.

    xcodebuild -scheme -showBuildSettings only returns settings for the
    scheme's primary target, so we enumerate all targets via ``-list`` and
    check each one individually for watchOS platform settings.

    Result is cached per (scheme, xcode_flag) key for the session.
    """
    cache_key = f"{scheme}:{':'.join(xcode_flag)}"
    if cache_key in _cached_has_watchos:
        return _cached_has_watchos[cache_key]

    # Step 1: enumerate all targets in the project
    list_cmd = ["xcodebuild", *xcode_flag, "-list"]
    list_result = subprocess.run(list_cmd, capture_output=True, text=True, check=False)

    targets: list[str] = []
    in_targets = False
    for line in list_result.stdout.splitlines():
        stripped = line.strip()
        if stripped == "Targets:":
            in_targets = True
            continue
        if in_targets:
            if not stripped or stripped.endswith(":"):
                break
            targets.append(stripped)

    result = False
    if targets:
        # Step 2: check each target's build settings for watchOS
        for target in targets:
            cmd = ["xcodebuild", "-target", target, *xcode_flag, "-showBuildSettings"]
            settings_result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            for line in settings_result.stdout.splitlines():
                parts = line.split("=", 1)
                if len(parts) == 2 and parts[0].strip() == "PLATFORM_NAME":
                    if parts[1].strip().lower() == "watchos":
                        result = True
                        break
            if result:
                break

    _cached_has_watchos[cache_key] = result
    return result


def _get_watchos_simulator_destination() -> str:
    """Find the first available watchOS simulator and return a destination string."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            capture_output=True, text=True, check=False,
        )
        data = json.loads(result.stdout)
        for runtime, devices in data.get("devices", {}).items():
            if "watchOS" not in runtime:
                continue
            for device in devices:
                if device.get("isAvailable"):
                    name = device["name"]
                    for part in runtime.split("."):
                        if part.startswith("watchOS-"):
                            ver = part[8:].replace("-", ".")
                            return f"platform=watchOS Simulator,name={name},OS={ver}"
    except Exception:
        pass
    return "platform=watchOS Simulator"


def _build_xcodebuild_multi_platform(
    scheme: str,
    xcode_flag: list[str],
    destination: str,
    derived_data_path: str,
    extra_args: list[str] | None = None,
) -> list[str]:
    """Build xcodebuild command with multi-platform (watchOS) handling.

    Detects watchOS targets in the scheme and pre-builds them separately
    before the main iOS build, preventing xcodebuild from failing when
    it encounters watchOS destinations it cannot satisfy with a single
    -destination flag.
    """
    has_watchos = _scheme_has_watchos_targets(scheme, xcode_flag)

    if has_watchos:
        watchos_cmd = [
            "xcodebuild", "build",
            "-scheme", scheme,
            "-destination", _get_watchos_simulator_destination(),
            "-derivedDataPath", derived_data_path,
            *xcode_flag,
            *(extra_args or []),
        ]
        watchos_result = subprocess.run(watchos_cmd, capture_output=True, text=True, check=False)
        if watchos_result.returncode != 0:
            logger.warning(
                "watchOS pre-build failed (rc=%d): %s",
                watchos_result.returncode,
                watchos_result.stderr[:500] if watchos_result.stderr else "",
            )
        else:
            logger.info("watchOS pre-build succeeded")

    cmd = [
        "xcodebuild", "build",
        "-scheme", scheme,
        "-destination", destination,
        "-derivedDataPath", derived_data_path,
        *xcode_flag,
        *(extra_args or []),
    ]
    return cmd


@dataclass
class PreviewState:
    socket_path: str = ""
    module_name: str = ""
    product_name: str = ""
    build_products_dir: str = ""
    app_path: str = ""
    sdk_version: str = ""

    def to_dict(self) -> dict:
        return {
            "socket_path": self.socket_path,
            "module_name": self.module_name,
            "product_name": self.product_name,
            "build_products_dir": self.build_products_dir,
            "app_path": self.app_path,
            "sdk_version": self.sdk_version,
        }

    @classmethod
    def from_dict(cls, d: dict) -> PreviewState:
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


def _save_state(state: PreviewState) -> None:
    _STATE_PATH.write_text(json.dumps(state.to_dict(), indent=2))


def _load_state() -> PreviewState | None:
    try:
        return PreviewState.from_dict(json.loads(_STATE_PATH.read_text()))
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        return None


def _clear_state() -> None:
    _STATE_PATH.unlink(missing_ok=True)


def _socket_path_for_device() -> str:
    return str(_TMP_BASE / f"utell_preview_{os.getpid()}.sock")


def _wait_for_socket(path: str, timeout: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if Path(path).exists():
            return True
        time.sleep(0.1)
    return False


class PreviewOrchestrator:

    def __init__(self, bridge: IOSBridgeClient) -> None:
        self._bridge = bridge
        self._state: PreviewState | None = None

    def _ensure_state(self) -> PreviewState:
        if self._state is None:
            self._state = _load_state()
        if self._state is None:
            raise RuntimeError(
                "No preview session. Run ios_preview_build first."
            )
        return self._state

    # -- Preview build -------------------------------------------------------

    def preview_build(
        self,
        scheme: str,
        project_path: str = "",
        workspace_path: str = "",
        preview_file: str = "",
    ) -> dict:
        if not _LOADER_DYLIB.exists():
            # Try building the dylib from source
            build_script = Path(__file__).parent / "native" / "build_loader.sh"
            if build_script.exists():
                try:
                    subprocess.run(
                        ["bash", str(build_script)],
                        capture_output=True, text=True, check=True,
                    )
                except subprocess.CalledProcessError as exc:
                    return {
                        "success": False,
                        "error": (
                            f"Loader dylib not found and auto-build failed.\n"
                            f"Run manually: bash {build_script}\n"
                            f"Build error: {exc.stderr}"
                        ),
                    }
            if not _LOADER_DYLIB.exists():
                return {"success": False, "error": f"Loader dylib not found: {_LOADER_DYLIB}. Run build_loader.sh first."}

        # Verify architecture compatibility
        host_arch = platform.machine()
        try:
            file_result = subprocess.run(
                ["file", str(_LOADER_DYLIB)],
                capture_output=True, text=True, check=False,
            )
            if host_arch in ("arm64", "aarch64") and "x86_64" in file_result.stdout:
                return {"success": False, "error": f"loader.dylib is x86_64 but host is {host_arch}. Rebuild with build_loader.sh."}
            if host_arch in ("x86_64",) and "arm64" in file_result.stdout:
                return {"success": False, "error": f"loader.dylib is arm64 but host is {host_arch}. Rebuild with build_loader.sh."}
        except Exception:
            pass

        xcode_flag = _resolve_xcode_flag(project_path, workspace_path)
        if isinstance(xcode_flag, dict):
            return xcode_flag

        shutil.rmtree(_DERIVED_DATA_PATH, ignore_errors=True)

        build_cmd = _build_xcodebuild_multi_platform(
            scheme=scheme,
            xcode_flag=xcode_flag,
            destination=_get_simulator_destination(),
            derived_data_path=str(_DERIVED_DATA_PATH),
            extra_args=[
                "OTHER_SWIFT_FLAGS=-Xfrontend -enable-implicit-dynamic -Xfrontend -enable-private-imports",
                "DEBUG_INFORMATION_FORMAT=dwarf",
                "SWIFT_OPTIMIZATION_LEVEL=-Onone",
            ],
        )

        build_result = subprocess.run(
            build_cmd, capture_output=True, text=True, check=False,
        )
        tail = "\n".join(build_result.stdout.splitlines()[-30:])
        if build_result.returncode != 0:
            return {"success": False, "error": "Build failed", "build_output": tail}

        products_dir = _DERIVED_DATA_PATH / "Build" / "Products" / "Debug-iphonesimulator"
        app_entries = list(products_dir.glob("*.app")) if products_dir.is_dir() else []
        if not app_entries:
            return {"success": False, "error": "No .app in derived data", "build_output": tail}

        app_path = app_entries[0]
        product_name = app_path.stem

        module_name = _resolve_module_name(scheme, xcode_flag)
        sdk_version = thunk_compiler.get_simulator_sdk_version()

        loader_dest = app_path / "Frameworks"
        loader_dest.mkdir(exist_ok=True)
        shutil.copy2(str(_LOADER_DYLIB), str(loader_dest / "utell_loader.dylib"))

        sock_path = _socket_path_for_device()
        thunk_dylib: str | None = None

        if preview_file and Path(preview_file).exists():
            thunk_result = _compile_thunk_for_file(
                file_path=preview_file,
                module_name=module_name,
                products_dir=products_dir,
                product_name=product_name,
                sdk_version=sdk_version,
            )
            if thunk_result.get("success"):
                shutil.copy2(thunk_result["dylib_path"], str(loader_dest / "__preview.dylib"))
                thunk_dylib = str(loader_dest / "__preview.dylib")

        install_result = subprocess.run(
            ["xcrun", "simctl", "install", "booted", str(app_path)],
            capture_output=True, text=True, check=False,
        )
        if install_result.returncode != 0:
            return {"success": False, "error": "Install failed", "build_output": tail}

        dyld_libs = ["@executable_path/Frameworks/utell_loader.dylib"]
        if thunk_dylib:
            dyld_libs.append("@executable_path/Frameworks/__preview.dylib")

        subprocess.Popen(
            ["xcrun", "simctl", "launch", "booted", self._bridge.bundle_id],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            env={**os.environ, "SIMCTL_CHILD_DYLD_INSERT_LIBRARIES": ":".join(dyld_libs),
                 "SIMCTL_CHILD_UTELL_PREVIEW_SOCKET_PATH": sock_path},
        )

        if not _wait_for_socket(sock_path, timeout=8.0):
            return {"success": False, "error": "Loader did not start (socket not created)", "build_output": tail}

        try:
            self._bridge.launch_app()
        except Exception as exc:
            logger.warning("WDA launch_app after preview build failed: %s", exc)

        state = PreviewState(
            socket_path=sock_path,
            module_name=module_name,
            product_name=product_name,
            build_products_dir=str(products_dir),
            app_path=str(app_path),
            sdk_version=sdk_version,
        )
        self._state = state
        _save_state(state)

        return {
            "success": True,
            "build_output": tail,
            "module_name": module_name,
            "socket_path": sock_path,
        }

    # -- Hot reload ----------------------------------------------------------

    def hot_reload(self, file_path: str) -> dict:
        state = self._ensure_state()

        if not Path(file_path).exists():
            return {"success": False, "error": f"File not found: {file_path}"}

        thunk_result = _compile_thunk_for_file(
            file_path=file_path,
            module_name=state.module_name,
            products_dir=Path(state.build_products_dir),
            product_name=state.product_name,
            sdk_version=state.sdk_version,
        )
        if not thunk_result.get("success"):
            return {
                "success": False,
                "error": thunk_result.get("error", "Thunk compilation failed"),
                "compile_output": thunk_result.get("compile_output", ""),
            }

        dylib_path = thunk_result["dylib_path"]
        socket_result = _send_to_loader(state.socket_path, dylib_path)
        shutil.rmtree(Path(dylib_path).parent, ignore_errors=True)

        if not socket_result["ok"]:
            return {"success": False, "error": f"Loader communication failed: {socket_result['error']}"}

        time.sleep(0.15)

        screenshot_result = _save_screenshot(self._bridge)
        return {
            "success": True,
            "screenshot_path": screenshot_result.get("screenshot_path"),
            "compile_output": thunk_result.get("compile_output", ""),
        }

    # -- Status --------------------------------------------------------------

    def status(self) -> dict:
        try:
            state = self._ensure_state()
        except RuntimeError:
            return {"active": False, "socket_path": None, "module_name": None}

        socket_ok = Path(state.socket_path).exists() if state.socket_path else False
        return {
            "active": socket_ok,
            "socket_path": state.socket_path,
            "module_name": state.module_name,
        }


# -- Shared helpers ----------------------------------------------------------


def _save_screenshot(bridge: IOSBridgeClient, output_path: str = "") -> dict:
    resp = bridge.screenshot()
    if resp.get("status") != "ok":
        return {"success": False, "error": f"Screenshot failed: {resp}"}

    png_b64 = resp.get("png_base64", "")
    if not png_b64:
        return {"success": False, "error": "Empty screenshot data"}

    if output_path:
        out = Path(output_path)
    else:
        out = Path(tempfile.gettempdir()) / f"utell_screenshot_{int(time.time())}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(png_b64))
    return {"success": True, "screenshot_path": str(out)}


def _compile_thunk_for_file(
    file_path: str,
    module_name: str,
    products_dir: Path,
    product_name: str,
    sdk_version: str,
) -> dict:
    parsed = swift_parser.parse_file(file_path)
    if not parsed.views:
        return {
            "success": False,
            "error": (
                f"No SwiftUI view structs found in {file_path}. "
                "Hot reload requires a struct conforming to View."
            ),
        }

    extra_imports = _extra_imports_from_parsed(parsed)
    source_file_name = Path(file_path).name

    view = parsed.views[0]
    struct_name = view.struct_name
    body_source = view.view_body

    if not body_source:
        return {"success": False, "error": "Could not extract view body"}

    thunk_src = thunk_generator.generate_thunk(
        module_name=module_name,
        source_file_name=source_file_name,
        struct_name=struct_name,
        view_body_source=body_source,
        extra_imports=extra_imports,
    )

    thunk_dir = Path(tempfile.mkdtemp(prefix="utell_thunk_"))
    thunk_swift = thunk_dir / "thunk.swift"
    thunk_swift.write_text(thunk_src)
    thunk_out = str(thunk_dir / "thunk.dylib")

    compile_result = thunk_compiler.compile_thunk(
        thunk_source_path=str(thunk_swift),
        output_dylib_path=thunk_out,
        build_products_dir=str(products_dir),
        product_name=product_name,
        sdk_version=sdk_version,
    )
    if not compile_result.success:
        shutil.rmtree(thunk_dir, ignore_errors=True)
        return {
            "success": False,
            "error": "Thunk compilation failed",
            "compile_output": compile_result.stderr,
        }

    return {"success": True, "dylib_path": thunk_out}


def _resolve_xcode_flag(
    project_path: str, workspace_path: str,
) -> list[str] | dict:
    if workspace_path:
        if not workspace_path.endswith(".xcworkspace"):
            return {"success": False, "error": "workspace_path must end with .xcworkspace"}
        if not Path(workspace_path).is_dir():
            return {"success": False, "error": f"workspace_path not found: {workspace_path}"}
        return ["-workspace", workspace_path]
    if project_path:
        if not project_path.endswith(".xcodeproj"):
            return {"success": False, "error": "project_path must end with .xcodeproj"}
        if not Path(project_path).is_dir():
            return {"success": False, "error": f"project_path not found: {project_path}"}
        return ["-project", project_path]
    cwd = Path.cwd()
    workspaces = list(cwd.glob("*.xcworkspace"))
    if workspaces:
        return ["-workspace", str(workspaces[0])]
    projects = list(cwd.glob("*.xcodeproj"))
    if projects:
        return ["-project", str(projects[0])]
    return {"success": False, "error": "No .xcodeproj or .xcworkspace found in CWD"}


def _resolve_module_name(scheme: str, xcode_flag: list[str]) -> str:
    cmd = ["xcodebuild", "-scheme", scheme, "-showBuildSettings", *xcode_flag]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    for line in result.stdout.splitlines():
        if "PRODUCT_MODULE_NAME" in line:
            parts = line.split("=", 1)
            if len(parts) == 2:
                return parts[1].strip()
    return scheme.replace("-", "_")


def _extra_imports_from_parsed(parsed: swift_parser.ParsedFile) -> str:
    lines = []
    for imp in parsed.imports:
        if imp not in ("SwiftUI", "UIKit", "Foundation"):
            lines.append(f"import {imp}")
    return "\n".join(lines)


def _send_to_loader(socket_path: str, dylib_path: str) -> dict:
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect(socket_path)
        sock.sendall(f"{dylib_path}\n".encode())

        response = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response += chunk
            if b"\n" in response:
                break
        sock.close()

        text = response.decode().strip()
        if text == "OK":
            return {"ok": True}
        return {"ok": False, "error": text}
    except socket.timeout:
        return {"ok": False, "error": "Socket timeout"}
    except FileNotFoundError:
        return {"ok": False, "error": f"Socket not found: {socket_path}"}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}
