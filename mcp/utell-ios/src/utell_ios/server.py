"""MCP Server exposing iOS simulator automation tools via the MCP protocol."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

from utell_ios import persistence, ui_parser
from utell_ios.bridge_client import IOSBridgeClient
from utell_ios.preview_loader import (
    PreviewOrchestrator,
    _get_simulator_destination,
    _resolve_xcode_flag,
    _save_screenshot,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _tool_error_guard(fn):
    """Decorator that catches exceptions and returns a standard error dict.

    Also checks for degraded-mode configuration before executing the tool.
    """
    import functools

    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        config_error = _require_config()
        if config_error:
            return {"success": False, "error": config_error}
        try:
            return fn(*args, **kwargs)
        except Exception as exc:
            return {"success": False, "error": str(exc)}
    return wrapper


def _build_error(
    error: str,
    build_output: str = "",
    install_output: str = "",
    app_path: str | None = None,
) -> dict[str, Any]:
    return {
        "success": False,
        "build_output": build_output,
        "install_output": install_output,
        "app_path": app_path,
        "error": error,
    }

# ---------------------------------------------------------------------------
# Module-level state
# ---------------------------------------------------------------------------

_bridge: IOSBridgeClient | None = None
_preview_orchestrator: PreviewOrchestrator | None = None


def _get_bridge() -> IOSBridgeClient:
    """Return the lazily-created singleton ``IOSBridgeClient``."""
    global _bridge
    if _bridge is None:
        if not _bundle_id:
            raise EnvironmentError(
                "UTELL_BUNDLE_ID is not configured. "
                "Set it in the plugin's userConfig or MCP env block."
            )
        _bridge = IOSBridgeClient(
            bundle_id=_bundle_id, host=_wda_host, port=int(_wda_port),
        )
    return _bridge


def _get_preview_orchestrator() -> PreviewOrchestrator:
    """Return the lazily-created singleton ``PreviewOrchestrator``."""
    global _preview_orchestrator
    if _preview_orchestrator is None:
        _preview_orchestrator = PreviewOrchestrator(_get_bridge())
    return _preview_orchestrator


# ---------------------------------------------------------------------------
# MCP server instance & runtime config
# ---------------------------------------------------------------------------

mcp = FastMCP("utell-ios")

_bundle_id: str = ""
_wda_host: str = "127.0.0.1"
_wda_port: str = "8100"


def _require_config() -> str | None:
    """Return an error message if the server is in degraded mode, else None."""
    if not _bundle_id:
        return (
            "utell-ios is not configured. Set UTELL_BUNDLE_ID in plugin settings "
            "(e.g., via the plugin's userConfig or MCP env block) to enable iOS tools."
        )
    return None


# ---------------------------------------------------------------------------
# Platform guard
# ---------------------------------------------------------------------------

def _check_platform() -> dict[str, Any]:
    """Verify the runtime platform supports iOS simulator automation."""
    issues: list[str] = []
    if sys.platform != "darwin":
        issues.append(f"Not running on macOS (current: {sys.platform}). iOS simulator tools require macOS.")
    for tool in ("xcrun", "xcodebuild"):
        if shutil.which(tool) is None:
            issues.append(f"{tool} not found — install Xcode CLI tools: xcode-select --install")
    return {"supported": len(issues) == 0, "issues": issues}


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------


@mcp.tool()
@_tool_error_guard
def ios_check_environment() -> dict[str, Any]:
    """Check whether the iOS automation environment is ready.

    Verifies WebDriverAgent connectivity and returns its status.

    Returns:
        ``{"ready": bool, "wda_state": dict}``
    """
    bridge = _get_bridge()
    result = bridge.health_check()
    return {"success": True, "ready": result.get("ready", False), "wda_state": result}


@mcp.tool()
@_tool_error_guard
def ios_launch_app() -> dict[str, Any]:
    """Launch the target app on the booted iOS simulator.

    Starts the app via ``xcrun simctl launch`` and creates a new WDA session.

    Returns:
        ``{"success": bool, "session_id": str | None}``
    """
    bridge = _get_bridge()
    result = bridge.launch_app()
    success = result.get("status") == "ok"
    return {"success": success, "session_id": bridge.session_id}


@mcp.tool()
@_tool_error_guard
def ios_terminate_app() -> dict[str, Any]:
    """Terminate the target app on the booted iOS simulator.

    Kills the app via ``xcrun simctl terminate`` and deletes the WDA session.

    Returns:
        ``{"success": bool}``
    """
    bridge = _get_bridge()
    bridge.terminate_app()
    return {"success": True}


@mcp.tool()
@_tool_error_guard
def ios_get_source() -> dict[str, Any]:
    """Retrieve the full UI accessibility tree of the running app.

    Fetches the XML source, then extracts screen identifiers and semantic IDs.

    Returns:
        ``{"source_length": int, "screens": list[str],
        "semantic_ids": list, "source_preview": str}``
        where *source_preview* is the first 2000 characters of the XML.
    """
    bridge = _get_bridge()
    bridge.ensure_session()
    source = bridge.get_source()
    screens = ui_parser.find_screens(source)
    semantic_ids = ui_parser.find_semantic_ids(source)
    return {
        "success": True,
        "source_length": len(source),
        "screens": screens,
        "semantic_ids": semantic_ids,
        "source_preview": source[:2000],
    }


@mcp.tool()
@_tool_error_guard
def ios_find_element(strategy: str, value: str) -> dict[str, Any]:
    """Find a single UI element using the given locator strategy.

    Args:
        strategy: Locator strategy (e.g. ``"accessibility id"``,
            ``"xpath"``, ``"class name"``).
        value: The locator value to search for.

    Returns:
        ``{"found": bool, "element_id": str | None}``
    """
    bridge = _get_bridge()
    result = bridge.find_element(strategy, value)
    found = result.get("status") == "ok"
    return {"success": True, "found": found, "element_id": result.get("element_id")}


@mcp.tool()
@_tool_error_guard
def ios_find_elements(strategy: str, value: str) -> dict[str, Any]:
    """Find multiple UI elements using the given locator strategy.

    Args:
        strategy: Locator strategy (e.g. ``"accessibility id"``,
            ``"xpath"``, ``"class name"``).
        value: The locator value to search for.

    Returns:
        ``{"found": bool, "count": int, "element_ids": list[str]}``
    """
    bridge = _get_bridge()
    result = bridge.find_elements(strategy, value)
    found = result.get("status") == "ok"
    count = result.get("count", 0)
    elements = result.get("elements", [])
    element_ids = [
        e.get("element_id") for e in elements if e.get("element_id")
    ]
    return {"success": True, "found": found, "count": count, "element_ids": element_ids}


@mcp.tool()
@_tool_error_guard
def ios_tap(element_id: str) -> dict[str, Any]:
    """Tap a UI element by its element ID.

    Args:
        element_id: The WDA element identifier to tap.

    Returns:
        ``{"success": bool}``
    """
    bridge = _get_bridge()
    result = bridge.retry_on_invalid_session(lambda: bridge.tap(element_id))
    success = result.get("status") == "ok"
    return {"success": success}


@mcp.tool()
@_tool_error_guard
def ios_tap_coordinates(x: int, y: int) -> dict[str, Any]:
    """Tap at the specified screen coordinates.

    Args:
        x: Horizontal coordinate.
        y: Vertical coordinate.

    Returns:
        ``{"success": bool}``
    """
    bridge = _get_bridge()
    result = bridge.tap_coordinates(x, y)
    success = result.get("status") == "ok"
    return {"success": success}


@mcp.tool()
@_tool_error_guard
def ios_input_text(
    element_id: str,
    text: str,
    strategy: str = "",
    value: str = "",
) -> dict[str, Any]:
    """Input text into a UI element, with optional stale-element protection.

    If *strategy* and *value* are provided, the element is re-found before
    typing.  If re-finding fails, the original *element_id* is used as a
    fallback.

    Args:
        element_id: The WDA element identifier.
        text: The text to type.
        strategy: Optional locator strategy for re-finding the element.
        value: Optional locator value for re-finding the element.

    Returns:
        ``{"success": bool, "element_refound": bool}``
    """
    bridge = _get_bridge()
    element_refound = False
    effective_id = element_id

    if strategy and value:
        find_result = bridge.find_element(strategy, value)
        if find_result.get("status") == "ok" and find_result.get(
            "element_id"
        ):
            effective_id = find_result["element_id"]
            element_refound = True

    result = bridge.input_text(effective_id, text)
    success = result.get("status") == "ok"
    return {"success": success, "element_refound": element_refound}


@mcp.tool()
@_tool_error_guard
def ios_clear_text(element_id: str) -> dict[str, Any]:
    """Clear text in a UI element.

    Args:
        element_id: The WDA element identifier to clear.

    Returns:
        ``{"success": bool}``
    """
    bridge = _get_bridge()
    result = bridge.clear_text(element_id)
    success = result.get("status") == "ok"
    return {"success": success}


@mcp.tool()
@_tool_error_guard
def ios_swipe(
    x1: int,
    y1: int,
    x2: int,
    y2: int,
    duration_ms: int = 500,
) -> dict[str, Any]:
    """Perform a swipe gesture between two points.

    Args:
        x1: Start horizontal coordinate.
        y1: Start vertical coordinate.
        x2: End horizontal coordinate.
        y2: End vertical coordinate.
        duration_ms: Duration of the swipe in milliseconds (default 500).

    Returns:
        ``{"success": bool}``
    """
    bridge = _get_bridge()
    result = bridge.swipe(x1, y1, x2, y2, duration_ms)
    success = result.get("status") == "ok"
    return {"success": success}


@mcp.tool()
@_tool_error_guard
def ios_element_exists(identifier: str) -> dict[str, Any]:
    """Check whether an element with the given identifier exists in the UI tree.

    Args:
        identifier: The accessibility identifier or name to search for.

    Returns:
        ``{"exists": bool}``
    """
    bridge = _get_bridge()
    bridge.ensure_session()
    source = bridge.get_source()
    exists = ui_parser.element_exists(source, identifier)
    return {"success": True, "exists": exists}


@mcp.tool()
@_tool_error_guard
def ios_get_element_bounds(identifier: str) -> dict[str, Any]:
    """Get the center coordinates of an element by its identifier.

    Args:
        identifier: The accessibility identifier or name to search for.

    Returns:
        ``{"found": bool, "x": int | None, "y": int | None}``
    """
    bridge = _get_bridge()
    bridge.ensure_session()
    source = bridge.get_source()
    bounds = ui_parser.get_element_bounds(source, identifier)
    if bounds is not None:
        return {"success": True, "found": True, "x": bounds[0], "y": bounds[1]}
    return {"success": True, "found": False, "x": None, "y": None}


@mcp.tool()
@_tool_error_guard
def ios_verify_persistence(
    token: str,
    expected_format: str = "",
) -> dict[str, Any]:
    """Verify that a token is persisted in the app's simulator data storage.

    Uses ripgrep to search for the token (and optionally its formatted form)
    inside the app's data directory on the booted simulator.

    Args:
        token: The raw token string to search for.
        expected_format: Optional formatted version of the token to search
            for first.

    Returns:
        The full verification result dict with keys ``pass``, ``level``,
        ``detail``, and ``matches``.
    """
    bridge = _get_bridge()
    result = persistence.verify_persistence(
        bundle_id=bridge.bundle_id,
        token=token,
        expected_format=expected_format or None,
    )
    return {**result, "success": True}


@mcp.tool()
@_tool_error_guard
def ios_build_and_install(
    scheme: str,
    project_path: str = "",
    workspace_path: str = "",
) -> dict[str, Any]:
    """Build an Xcode project and install the resulting app on the booted simulator.

    Runs ``xcodebuild build`` followed by ``xcrun simctl install booted``.

    Args:
        scheme: The Xcode scheme to build (alphanumeric, dashes, underscores).
        project_path: Optional path to a ``.xcodeproj`` directory.
        workspace_path: Optional path to a ``.xcworkspace`` directory.

    Returns:
        ``{"success": bool, "build_output": str, "install_output": str,
        "app_path": str | None}``
    """
    # -- Validate scheme -------------------------------------------------------
    if not re.fullmatch(r"[A-Za-z0-9_-]+", scheme):
        return _build_error(f"Invalid scheme '{scheme}': must match ^[A-Za-z0-9_-]+$")

    # -- Determine project or workspace flag -----------------------------------
    xcode_flag_result = _resolve_xcode_flag(project_path, workspace_path)
    if isinstance(xcode_flag_result, dict):
        return _build_error(xcode_flag_result.get("error", "Unknown xcode resolution error"))
    xcode_flag = xcode_flag_result

    derived_data_path = os.path.join(tempfile.gettempdir(), "utell_ios_build")
    shutil.rmtree(derived_data_path, ignore_errors=True)

    # -- Build -----------------------------------------------------------------
    build_cmd: list[str] = [
        "xcodebuild",
        "build",
        "-scheme", scheme,
        "-destination", _get_simulator_destination(),
        "-derivedDataPath", derived_data_path,
        *xcode_flag,
    ]
    build_result = subprocess.run(
        build_cmd,
        capture_output=True,
        text=True,
        check=False,
    )

    build_output_lines = build_result.stdout.splitlines()
    build_output_tail = "\n".join(build_output_lines[-50:])

    if build_result.returncode != 0:
        return _build_error("Build failed", build_output=build_output_tail)

    # -- Find .app in derived data ---------------------------------------------
    products_dir = Path(derived_data_path) / "Build" / "Products" / "Debug-iphonesimulator"
    app_entries = list(products_dir.glob("*.app")) if products_dir.is_dir() else []

    if not app_entries:
        return _build_error("Build succeeded but no .app found in derived data", build_output=build_output_tail)

    app_path = str(app_entries[0])

    # -- Install ---------------------------------------------------------------
    install_cmd: list[str] = [
        "xcrun", "simctl", "install", "booted", app_path,
    ]
    install_result = subprocess.run(
        install_cmd,
        capture_output=True,
        text=True,
        check=False,
    )

    install_output = install_result.stdout
    if install_result.returncode != 0:
        return _build_error(
            "Install failed",
            build_output=build_output_tail,
            install_output=install_result.stderr or install_output,
            app_path=app_path,
        )

    return {
        "success": True,
        "build_output": build_output_tail,
        "install_output": install_output,
        "app_path": app_path,
    }


# ---------------------------------------------------------------------------
# Preview / Hot-reload tools
# ---------------------------------------------------------------------------


@mcp.tool()
@_tool_error_guard
def ios_screenshot(output_path: str = "") -> dict[str, Any]:
    """Take a screenshot of the iOS simulator screen.

    Captures the current screen via the WebDriverAgent screenshot endpoint
    and saves it as a PNG file.

    Args:
        output_path: Optional path to save the PNG. Defaults to /tmp.

    Returns:
        ``{"success": bool, "screenshot_path": str}``
    """
    return _save_screenshot(_get_bridge(), output_path=output_path)


@mcp.tool()
@_tool_error_guard
def ios_preview_build(
    scheme: str,
    project_path: str = "",
    workspace_path: str = "",
    preview_file: str = "",
) -> dict[str, Any]:
    """Build the app with preview support and launch it on the simulator.

    Runs ``xcodebuild`` with dynamic replacement flags, injects a loader
    dylib, and launches the app. This is a one-time slow operation (full
    build). After this, use ``ios_preview_hot_reload`` for fast updates.

    Args:
        scheme: The Xcode scheme to build.
        project_path: Optional path to a ``.xcodeproj`` directory.
        workspace_path: Optional path to a ``.xcworkspace`` directory.
        preview_file: Swift file to preview initially (containing #Preview or View).

    Returns:
        ``{"success": bool, "module_name": str, "build_output": str}``
    """
    orchestrator = _get_preview_orchestrator()
    return orchestrator.preview_build(
        scheme=scheme,
        project_path=project_path,
        workspace_path=workspace_path,
        preview_file=preview_file,
    )


@mcp.tool()
@_tool_error_guard
def ios_preview_hot_reload(file_path: str) -> dict[str, Any]:
    """Hot-reload a modified SwiftUI file and take a screenshot.

    Parses the Swift file, compiles only the changed view body into a dylib
    (seconds), injects it into the running app, and captures a screenshot.

    Requires a prior successful ``ios_preview_build`` call.

    Args:
        file_path: Absolute path to the modified Swift file.

    Returns:
        ``{"success": bool, "screenshot_path": str | None,
        "compile_output": str}``
    """
    orchestrator = _get_preview_orchestrator()
    return orchestrator.hot_reload(file_path=file_path)


@mcp.tool()
@_tool_error_guard
def ios_preview_status() -> dict[str, Any]:
    """Check whether the SwiftUI preview system is active.

    Returns:
        ``{"active": bool, "socket_path": str | None,
        "module_name": str | None}``
    """
    orchestrator = _get_preview_orchestrator()
    return orchestrator.status()


# ---------------------------------------------------------------------------
# Smoke test
# ---------------------------------------------------------------------------


def _check_foreground(
    bridge: IOSBridgeClient, source: str
) -> tuple[dict[str, Any], str]:
    """Check foreground app status, auto-retrying once if SpringBoard is detected.

    Returns ``(check_dict, updated_source)``.
    """
    fg_app = ui_parser.detect_foreground_app(source)
    if fg_app is None:
        return {"status": "warn", "detail": "Could not determine foreground app from UI tree"}, source
    if fg_app not in ui_parser.SPRINGBOARD_IDENTIFIERS:
        return {"status": "pass", "detail": f"App in foreground: {fg_app}"}, source
    # SpringBoard detected -- retry once
    try:
        bridge.launch_app()
        source = bridge.get_source()
        fg_app = ui_parser.detect_foreground_app(source)
    except Exception:
        pass
    if fg_app in ui_parser.SPRINGBOARD_IDENTIFIERS or fg_app is None:
        return {
            "status": "fail",
            "detail": "App not in foreground; SpringBoard detected. The app may have crashed or was not installed.",
        }, source
    return {"status": "pass", "detail": f"App in foreground: {fg_app}"}, source


def _smoke_result(
    checks: dict[str, Any],
    suggestions: list[dict],
    overall: str,
) -> dict[str, Any]:
    return {
        "success": True,
        "overall_status": overall,
        "checks": checks,
        "suggestions": suggestions,
    }


@mcp.tool()
@_tool_error_guard
def ios_smoke_test(include_interaction: bool = False) -> dict[str, Any]:
    """Run a smoke test to check utell-ios compatibility with the target app.

    Performs a sequence of checks:

    1. Environment prerequisites (ripgrep)
    2. WebDriverAgent connectivity
    3. App launch
    4. UI accessibility tree retrieval
    5. Accessibility name/label coverage analysis

    If *include_interaction* is True, also tests a basic tap (may affect app
    state).

    For each interactive element missing a ``name`` or ``label`` in the XCUI
    source XML, the result includes a suggested ``accessibilityIdentifier``
    and Swift code snippets (SwiftUI and UIKit) to fix it.

    Args:
        include_interaction: Whether to include a basic interaction test.

    Returns:
        ``{"overall_status": str, "checks": dict, "suggestions": list}``
    """
    checks: dict[str, Any] = {}
    suggestions: list[dict] = []

    # 1. Environment prerequisites
    rg_available = shutil.which("rg") is not None
    checks["environment"] = {
        "status": "pass" if rg_available else "warn",
        "detail": (
            "All tools available"
            if rg_available
            else "ripgrep not found — persistence checks will be unavailable"
        ),
        "ripgrep_available": rg_available,
    }

    # 2. WDA connectivity
    try:
        bridge = _get_bridge()
        health = bridge.health_check()
        wda_ready = health.get("ready", False)
        checks["wda_connectivity"] = {
            "status": "pass" if wda_ready else "fail",
            "detail": (
                "WebDriverAgent is reachable and ready"
                if wda_ready
                else f"WDA not ready: {health}"
            ),
        }
    except Exception as exc:
        checks["wda_connectivity"] = {
            "status": "fail",
            "detail": f"Cannot connect to WebDriverAgent: {exc}",
        }
        return _smoke_result(checks, suggestions, "fail")

    # 3. App launch
    try:
        bridge.launch_app()
        launched = bridge.session_id is not None
        checks["app_launch"] = {
            "status": "pass" if launched else "fail",
            "detail": (
                f"App launched (session: {bridge.session_id})"
                if launched
                else "App launch returned no session"
            ),
        }
    except Exception as exc:
        checks["app_launch"] = {
            "status": "fail",
            "detail": f"App launch error: {exc}",
        }
        return _smoke_result(checks, suggestions, "fail")

    # 3b. Alert dismissal
    try:
        alert_result = bridge.dismiss_alerts()
        alert_present = alert_result.get("alert_present", False)
        action = alert_result.get("action", "")
        checks["alert_dismissal"] = {
            "status": "info",
            "detail": (
                f"System alert found and dismissed (action: {action})"
                if alert_present
                else "No system alert present"
            ),
            "alert_present": alert_present,
        }
    except Exception as exc:
        checks["alert_dismissal"] = {
            "status": "info",
            "detail": f"Alert dismissal check skipped: {exc}",
            "alert_present": False,
        }

    # 4. UI tree
    try:
        source = bridge.get_source()
        screens = ui_parser.find_screens(source)
        checks["ui_tree"] = {
            "status": "pass" if source else "fail",
            "detail": (
                f"Retrieved {len(source)} chars, found {len(screens)} screen(s)"
            ),
            "screens": screens,
        }
    except Exception as exc:
        checks["ui_tree"] = {
            "status": "fail",
            "detail": f"UI tree error: {exc}",
        }
        return _smoke_result(checks, suggestions, "fail")

    # 4b. Foreground detection
    checks["foreground_detection"], source = _check_foreground(bridge, source)

    # 5. Accessibility coverage
    try:
        analysis = ui_parser.analyze_accessibility(source)
        coverage = analysis["coverage_percent"]
        if coverage >= 80:
            status = "pass"
        elif coverage >= 40:
            status = "warn"
        else:
            status = "fail"
        checks["accessibility_coverage"] = {
            "status": status,
            "detail": (
                f"{coverage}% ({analysis['with_identifier']}/"
                f"{analysis['total_interactive']}) interactive elements "
                f"have name or label"
            ),
            "total_interactive": analysis["total_interactive"],
            "with_identifier": analysis["with_identifier"],
            "coverage_percent": coverage,
        }
        suggestions = analysis["missing"]
    except Exception as exc:
        checks["accessibility_coverage"] = {
            "status": "warn",
            "detail": f"Accessibility analysis error: {exc}",
        }

    # 6. Optional interaction test
    if include_interaction:
        try:
            result = bridge.tap_coordinates(100, 100)
            ok = result.get("status") == "ok"
            checks["interaction"] = {
                "status": "pass" if ok else "fail",
                "detail": "Basic tap succeeded" if ok else "Tap failed",
            }
        except Exception as exc:
            checks["interaction"] = {
                "status": "fail",
                "detail": f"Interaction error: {exc}",
            }

    # Overall status
    statuses = [c["status"] for c in checks.values()]
    if "fail" in statuses:
        overall = "fail"
    elif "warn" in statuses:
        overall = "warn"
    else:
        overall = "pass"

    return _smoke_result(checks, suggestions, overall)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    """Start the utell-ios MCP server on stdio transport.

    If UTELL_BUNDLE_ID is not set, the server starts in degraded mode —
    tools are registered but return a configuration error when called.
    This prevents a hard crash from breaking the entire MCP subsystem.
    """
    global _bundle_id, _wda_host, _wda_port  # noqa: PLW0603

    _bundle_id = os.environ.get("UTELL_BUNDLE_ID", "")
    _wda_host = os.environ.get("UTELL_WDA_HOST", "127.0.0.1")
    _wda_port = os.environ.get("UTELL_WDA_PORT", "8100")

    if not _bundle_id:
        print(
            "[utell-ios] WARNING: UTELL_BUNDLE_ID is not set. "
            "Server starting in degraded mode — tools will return config errors. "
            "Set UTELL_BUNDLE_ID in plugin settings to enable full functionality.",
            file=sys.stderr,
        )

    platform_check = _check_platform()
    if platform_check["supported"]:
        print(
            f"[utell-ios] Starting server — bundle: {_bundle_id or '(not configured)'}, "
            f"WDA: {_wda_host}:{_wda_port}",
            file=sys.stderr,
        )
    else:
        for issue in platform_check["issues"]:
            print(f"[utell-ios] WARNING: {issue}", file=sys.stderr)

    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
