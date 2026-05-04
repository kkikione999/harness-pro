from __future__ import annotations

import json
import subprocess
from typing import Any
from urllib import error, request

from utell_ios import proxy

_W3C_ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"


class IOSBridgeClient:
    """WebDriverAgent HTTP client for iOS simulator automation."""

    def __init__(
        self,
        bundle_id: str,
        host: str = "127.0.0.1",
        port: int = 8100,
        timeout: int = 30,
    ) -> None:
        self.bundle_id = bundle_id
        self.host = host
        self.port = port
        self.timeout = timeout
        self.session_id: str | None = None
        self._opener: request.OpenerDirector = proxy.build_opener(self.host)

    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"

    # -- HTTP layer ----------------------------------------------------------

    def _urlopen(self, req: request.Request) -> Any:
        return self._opener.open(req, timeout=self.timeout)

    def _request(self, method: str, endpoint: str, data: dict | None = None) -> dict:
        url = f"{self.base_url}{endpoint}"
        body = None
        headers = {"Accept": "application/json"}

        if data is not None:
            body = json.dumps(data, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"

        try:
            req = request.Request(url, data=body, method=method, headers=headers)
            with self._urlopen(req) as resp:
                raw = resp.read().decode("utf-8")
                return {"status": "ok", "value": json.loads(raw) if raw else {}}
        except error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            return {"status": "error", "code": exc.code, "body": raw}
        except error.URLError as exc:
            return {"status": "error", "code": "connection", "body": str(exc.reason)}

    def _get(self, endpoint: str) -> dict:
        return self._request("GET", endpoint)

    def _post(self, endpoint: str, data: dict | None = None) -> dict:
        return self._request("POST", endpoint, data)

    def _delete(self, endpoint: str) -> dict:
        return self._request("DELETE", endpoint)

    # -- Session management --------------------------------------------------

    def create_session(self) -> dict:
        resp = self._post("/session", {
            "capabilities": {
                "bundleId": self.bundle_id,
                "platformName": "iOS",
            }
        })
        if resp["status"] == "ok":
            sid = resp["value"].get("value", {}).get("sessionId")
            if not sid:
                sid = resp["value"].get("sessionId")
            self.session_id = sid
        return resp

    def delete_session(self) -> dict:
        if not self.session_id:
            return {"status": "ok"}
        resp = self._delete(f"/session/{self.session_id}")
        self.session_id = None
        return resp

    def ensure_session(self) -> dict:
        if self.session_id:
            return {"status": "ok", "session_id": self.session_id}
        return self.create_session()

    # -- Runtime state -------------------------------------------------------

    def get_source(self) -> str:
        """Retrieve the full UI accessibility tree as an XML string."""
        self.ensure_session()
        resp = self._get(f"/session/{self.session_id}/source")
        value = resp.get("value", {})
        if isinstance(value, dict) and "value" in value:
            return value["value"]
        return str(value)

    def health_check(self) -> dict:
        resp = self._get("/status")
        if resp["status"] != "ok":
            return {"ready": False, "error": resp.get("body")}
        value = resp.get("value", {})
        if isinstance(value, dict) and "value" in value:
            value = value["value"]
        return {"ready": value.get("ready", False), "state": value}

    # -- Element finding -----------------------------------------------------

    def find_element(self, strategy: str, value: str) -> dict:
        """Find a single element by the given strategy and value.

        Supports both legacy (ELEMENT) and W3C (element-6066-11e4-a52e-4f735466cecf)
        element ID keys.
        """
        self.ensure_session()
        resp = self._post(
            f"/session/{self.session_id}/element",
            {"using": strategy, "value": value},
        )
        if resp["status"] == "ok":
            elem = resp.get("value", {}).get("value", resp.get("value", {}))
            if isinstance(elem, dict):
                eid = elem.get("ELEMENT") or elem.get(_W3C_ELEMENT_KEY)
                if eid:
                    return {"status": "ok", "element_id": eid, "element": elem}
        return {"status": "error", "response": resp}

    def find_elements(self, strategy: str, value: str) -> dict:
        """Find multiple elements by the given strategy and value.

        Returns a list of elements with both legacy and W3C element ID keys.
        """
        self.ensure_session()
        resp = self._post(
            f"/session/{self.session_id}/elements",
            {"using": strategy, "value": value},
        )
        if resp["status"] == "ok":
            elems = resp.get("value", {}).get("value", resp.get("value", []))
            if isinstance(elems, list):
                results = []
                for e in elems:
                    eid = e.get("ELEMENT") or e.get(_W3C_ELEMENT_KEY)
                    results.append({"element_id": eid, "element": e})
                return {"status": "ok", "elements": results, "count": len(results)}
        return {"status": "error", "response": resp}

    # -- Interaction operations ----------------------------------------------

    def tap(self, element_id: str) -> dict:
        """Tap the specified element."""
        self.ensure_session()
        return self._post(f"/session/{self.session_id}/element/{element_id}/click", {})

    def tap_coordinates(self, x: int, y: int) -> dict:
        """Tap at the specified coordinates."""
        self.ensure_session()
        return self._post(f"/session/{self.session_id}/actions", {
            "actions": [{
                "type": "pointer",
                "id": "finger1",
                "parameters": {"pointerType": "touch"},
                "actions": [
                    {"type": "pointerMove", "duration": 0, "x": x, "y": y},
                    {"type": "pointerDown", "button": 0},
                    {"type": "pause", "duration": 50},
                    {"type": "pointerUp", "button": 0},
                ],
            }]
        })

    def input_text(self, element_id: str, text: str) -> dict:
        """Input text into the specified element."""
        self.ensure_session()
        return self._post(
            f"/session/{self.session_id}/element/{element_id}/value",
            {"text": text, "value": list(text)},
        )

    def clear_text(self, element_id: str) -> dict:
        """Clear text in the specified element."""
        self.ensure_session()
        return self._post(f"/session/{self.session_id}/element/{element_id}/clear", {})

    def swipe(self, x1: int, y1: int, x2: int, y2: int, duration_ms: int = 500) -> dict:
        """Perform a swipe gesture from (x1, y1) to (x2, y2)."""
        self.ensure_session()
        return self._post(f"/session/{self.session_id}/actions", {
            "actions": [{
                "type": "pointer",
                "id": "finger1",
                "parameters": {"pointerType": "touch"},
                "actions": [
                    {"type": "pointerMove", "duration": 0, "x": x1, "y": y1},
                    {"type": "pointerDown", "button": 0},
                    {"type": "pause", "duration": duration_ms},
                    {"type": "pointerMove", "duration": duration_ms, "x": x2, "y": y2},
                    {"type": "pointerUp", "button": 0},
                ],
            }]
        })

    # -- App lifecycle -------------------------------------------------------

    def launch_app(self) -> dict:
        """Launch the app via simctl and create a WDA session."""
        subprocess.run(
            ["xcrun", "simctl", "launch", "booted", self.bundle_id],
            capture_output=True, text=True, check=False,
        )
        if self.session_id:
            self.delete_session()
        result = self.create_session()
        # Best-effort: bring the app to the foreground after launch.
        if self.session_id:
            try:
                self.activate_app()
            except Exception:
                pass  # activate is best-effort; do not fail the launch
        return result

    def terminate_app(self) -> dict:
        """Terminate the app via simctl and delete the WDA session."""
        subprocess.run(
            ["xcrun", "simctl", "terminate", "booted", self.bundle_id],
            capture_output=True, text=True, check=False,
        )
        return self.delete_session()

    # -- App activation ------------------------------------------------------

    def activate_app(self) -> dict:
        """Bring the app to the foreground via WDA activate endpoint.

        Requires an active WDA session.  Returns a safe result when no
        session is established, without making any HTTP call.
        """
        if not self.session_id:
            return {"status": "error", "value": "No active session"}
        return self._post(
            f"/session/{self.session_id}/wda/activate",
            {"bundleId": self.bundle_id},
        )

    # -- Session auto-recovery -----------------------------------------------

    def retry_on_invalid_session(self, fn: Any) -> dict:
        """Retry an operation once if the WDA session has expired."""
        resp = fn()
        if resp.get("status") == "error":
            error_body = str(resp.get("body", "")).lower()
            if "invalid session id" in error_body or "session does not exist" in error_body:
                self.session_id = None
                self.create_session()
                resp = fn()
        return resp

    # -- Screenshot ----------------------------------------------------------

    def screenshot(self) -> dict:
        """Take a screenshot via WDA.

        Returns ``{"status": "ok", "png_base64": str}`` on success.
        The value is a base64-encoded PNG image.
        """
        self.ensure_session()
        resp = self._get(f"/session/{self.session_id}/screenshot")
        if resp["status"] != "ok":
            return resp
        value = resp.get("value", {})
        png_b64 = value.get("value", "") if isinstance(value, dict) else str(value)
        return {"status": "ok", "png_base64": png_b64}

    # -- Alert handling ------------------------------------------------------

    def dismiss_alerts(self) -> dict:
        """Dismiss or accept any system alert that is currently displayed.

        Tries the dismiss endpoint first; if that fails (no alert present),
        falls back to the accept endpoint.  Returns a dict indicating whether
        an alert was found and which action was taken.
        """
        if not self.session_id:
            return {"status": "ok", "alert_present": False}

        dismiss_resp = self._post(
            f"/session/{self.session_id}/wda/alert/dismiss"
        )
        if dismiss_resp.get("status") == "ok":
            return {"status": "ok", "alert_present": True, "action": "dismiss"}

        accept_resp = self._post(
            f"/session/{self.session_id}/wda/alert/accept"
        )
        if accept_resp.get("status") == "ok":
            return {"status": "ok", "alert_present": True, "action": "accept"}

        return {"status": "ok", "alert_present": False}
