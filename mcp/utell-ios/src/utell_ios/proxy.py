from __future__ import annotations

from urllib import request


def build_opener(host: str) -> request.OpenerDirector:
    """Build a URL opener that bypasses proxies for localhost addresses.

    Returns a ProxyHandler-based opener when host is a local address,
    otherwise returns the default opener.
    """
    if host in {"127.0.0.1", "localhost", "::1"}:
        return request.build_opener(request.ProxyHandler({}))
    return request.build_opener()
