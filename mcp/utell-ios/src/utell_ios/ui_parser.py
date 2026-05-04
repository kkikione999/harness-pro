"""Pure functions for parsing iOS UI accessibility tree XML."""

from __future__ import annotations

import re


def find_screens(source_xml: str) -> list[str]:
    """Extract screen identifiers from the UI tree.

    Matches patterns like ``screen.Home`` and returns a sorted unique list
    of the identifier portion after the dot.
    """
    return sorted(set(re.findall(r"screen\.([A-Za-z0-9_]+)", source_xml)))


def find_semantic_ids(source_xml: str) -> list[tuple[str, str]]:
    """Extract all accessibility identifier and name attribute values from the XML.

    Each match captures one group from ``identifier="..."`` *or* ``name="..."``,
    so each tuple has exactly one non-empty element.  Returns a sorted unique
    list of ``(match_group1, match_group2)`` tuples where one element of each
    tuple may be empty.
    """
    raw = re.findall(r'identifier="([^"]+)"|name="([^"]+)"', source_xml)
    return sorted(set(raw))


def element_exists(source_xml: str, identifier: str) -> bool:
    """Check whether an element with the given identifier exists in the XML."""
    pattern = rf'(?:identifier|name)="{re.escape(identifier)}"'
    return bool(re.search(pattern, source_xml))


def get_element_bounds(source_xml: str, identifier: str) -> tuple[int, int] | None:
    """Compute the center coordinates of an element identified by *identifier*.

    Searches for the first element whose ``identifier`` or ``name`` attribute
    matches, then reads its ``x``, ``y``, ``width``, ``height`` attributes
    (either directly on the tag or from a ``rect`` attribute).  Returns
    ``(x + width // 2, y + height // 2)`` or ``None``.
    """
    escaped = re.escape(identifier)

    # Strategy 1: direct x/y/width/height attributes on the element tag.
    pattern_direct = (
        rf'<XCUIElementType\w+\s[^>]*?'
        rf'(?:identifier|name)="{escaped}"[^>]*?'
        rf'x="(\d+)"[^>]*?y="(\d+)"[^>]*?width="(\d+)"[^>]*?height="(\d+)"'
    )
    match = re.search(pattern_direct, source_xml, re.DOTALL)
    if not match:
        # Strategy 2: rect="{{x=… y=… width=… height=…}}" attribute.
        pattern_rect = (
            rf'<XCUIElementType\w+\s[^>]*?'
            rf'(?:identifier|name)="{escaped}"[^>]*?'
            rf'rect="\{{x=(\d+).*?y=(\d+).*?width=(\d+).*?height=(\d+)\}}"'
        )
        match = re.search(pattern_rect, source_xml, re.DOTALL)
    if not match:
        return None
    x, y, w, h = (
        int(match.group(1)),
        int(match.group(2)),
        int(match.group(3)),
        int(match.group(4)),
    )
    return (x + w // 2, y + h // 2)


def _iter_elements(source_xml: str):
    """Yield ``(element_type, attrs_dict)`` for each ``XCUIElementType*`` element."""
    for match in _ELEMENT_RE.finditer(source_xml):
        yield match.group(1), dict(_ATTR_RE.findall(match.group(2)))


def detect_foreground_app(source_xml: str) -> str | None:
    """Extract the top-level application element's ``name`` attribute from the XML.

    Searches for the first ``XCUIElementTypeApplication`` element and returns
    its ``name`` attribute value.  Returns ``None`` if no Application element
    is found at all.
    """
    for element_type, attrs in _iter_elements(source_xml):
        if element_type == "Application":
            return attrs.get("name")
    return None


# ---------------------------------------------------------------------------
# Accessibility coverage analysis
# ---------------------------------------------------------------------------

INTERACTIVE_TYPES: frozenset[str] = frozenset({
    "Button", "TextField", "SecureTextField", "TextView",
    "Switch", "Slider", "Picker", "Stepper",
    "Cell", "SearchField", "Link",
})

_ELEMENT_RE = re.compile(r"<XCUIElementType(\w+)([^>]*?)(?:/>|>)")
_ATTR_RE = re.compile(r'(\w+)="([^"]*)"')

SPRINGBOARD_IDENTIFIERS: frozenset[str] = frozenset({"SpringBoard", "com.apple.springboard"})


def _derive_identifier(name: str, element_type: str) -> str:
    """Derive a snake_case accessibility identifier from element name and type."""
    type_suffix = {
        "Button": "btn",
        "TextField": "textfield",
        "SecureTextField": "securefield",
        "TextView": "textview",
        "Switch": "switch",
        "Slider": "slider",
        "Picker": "picker",
        "Stepper": "stepper",
        "Cell": "cell",
        "SearchField": "searchfield",
        "Link": "link",
    }.get(element_type, element_type.lower())

    if name:
        s = re.sub(r"[^a-z0-9]+", "_", name.lower().strip()).strip("_")
        if s:
            return f"{s}_{type_suffix}"
    return f"set_accessibility_id_for_{type_suffix}"


def analyze_accessibility(source_xml: str) -> dict:
    """Analyze accessibility coverage of interactive UI elements.

    Scans all interactive elements (buttons, text fields, switches, etc.)
    and reports how many have an accessible name (``name`` or ``label``
    attribute in XCUI source XML).  Elements without any ``name`` or
    ``label`` are considered missing accessibility coverage.

    For elements missing a name, generates a suggested
    ``accessibilityIdentifier`` and Swift code snippets for both SwiftUI
    and UIKit, so developers can set explicit identifiers that make
    ``ios_find_element(strategy="accessibility id", ...)`` work reliably.

    Returns:
        ``{"total_interactive": int, "with_identifier": int,
        "coverage_percent": int, "missing": list[dict]}``
    """
    missing: list[dict] = []
    total = 0
    with_id = 0

    for element_type, attrs in _iter_elements(source_xml):
        if element_type not in INTERACTIVE_TYPES:
            continue

        total += 1
        name = attrs.get("name", "") or attrs.get("label", "")

        if name:
            with_id += 1
        else:
            suggested_id = _derive_identifier(name, element_type)
            missing.append({
                "element_type": element_type,
                "name": "",
                "suggested_id": suggested_id,
                "swiftui": f'.accessibilityIdentifier("{suggested_id}")',
                "uikit": f'.accessibilityIdentifier = "{suggested_id}"',
                "guidance": "Set an accessibilityIdentifier on this element so automated tests can find it.",
            })

    # Deduplicate by suggested_id, keeping first occurrence
    seen_ids: set[str] = set()
    deduped: list[dict] = []
    for entry in missing:
        if entry["suggested_id"] not in seen_ids:
            seen_ids.add(entry["suggested_id"])
            deduped.append(entry)

    coverage = round(with_id / total * 100) if total > 0 else 0

    return {
        "total_interactive": total,
        "with_identifier": with_id,
        "coverage_percent": coverage,
        "missing": deduped,
    }
