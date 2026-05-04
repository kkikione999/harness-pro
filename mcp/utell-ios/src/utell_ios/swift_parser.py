"""Pure functions for parsing Swift source to extract SwiftUI view info."""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class SwiftViewInfo:
    struct_name: str
    view_body: str
    source_file: str
    conformances: tuple[str, ...] = ()


@dataclass(frozen=True)
class PreviewBlock:
    name: str | None
    body: str
    source_file: str


@dataclass(frozen=True)
class ParsedFile:
    views: tuple[SwiftViewInfo, ...] = ()
    previews: tuple[PreviewBlock, ...] = ()
    imports: tuple[str, ...] = ()


def parse_file(file_path: str) -> ParsedFile:
    with open(file_path, encoding="utf-8") as f:
        source = f.read()
    return parse_source(source, file_path)


def parse_source(source: str, source_file: str = "") -> ParsedFile:
    clean = _strip_comments(source)
    masked = _mask_strings(clean)
    return ParsedFile(
        views=tuple(_find_view_structs(clean, source_file, masked)),
        previews=tuple(_find_preview_blocks(clean, source_file, masked)),
        imports=tuple(_find_imports(clean)),
    )


def _strip_comments(source: str) -> str:
    source = re.sub(r"//.*?$", "", source, flags=re.MULTILINE)
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return source


def _find_imports(source: str) -> list[str]:
    return re.findall(r"^\s*import\s+(\w+)", source, re.MULTILINE)


def _find_view_structs(source: str, source_file: str, masked: str) -> list[SwiftViewInfo]:
    results = []
    pattern = re.compile(
        r"struct\s+(\w+)\s*(?::\s*([^{]+?))?\s*\{",
        re.MULTILINE,
    )
    for m in pattern.finditer(source):
        struct_name = m.group(1)
        conformances_str = m.group(2) or ""
        conformances = tuple(c.strip() for c in conformances_str.split(","))
        is_view = any("View" in c for c in conformances)
        if not is_view:
            continue
        brace_start = m.end() - 1
        body_match = _find_body_property(source, brace_start, masked)
        if body_match:
            results.append(SwiftViewInfo(
                struct_name=struct_name,
                view_body=body_match,
                source_file=source_file,
                conformances=conformances,
            ))
    return results


def _find_body_property(source: str, struct_start: int, masked: str) -> str | None:
    body_pat = re.compile(r"var\s+body\s*:\s*some\s+View\s*\{")
    search_region = source[struct_start:]
    m = body_pat.search(search_region)
    if not m:
        return None
    abs_start = struct_start + m.end() - 1
    return _extract_brace_block(source, masked, abs_start)


def _find_preview_blocks(source: str, source_file: str, masked: str) -> list[PreviewBlock]:
    results = []
    pattern = re.compile(
        r"#Preview\s*(?:\(\s*(?:\"([^\"]*)\"|trailingClosure)?\s*\))?\s*\{",
        re.MULTILINE,
    )
    for m in pattern.finditer(source):
        name = m.group(1)
        brace_start = m.end() - 1
        body = _extract_brace_block(source, masked, brace_start)
        if body is not None:
            results.append(PreviewBlock(
                name=name,
                body=body,
                source_file=source_file,
            ))
    return results


def _extract_brace_block(source: str, masked: str, start: int) -> str | None:
    if start >= len(source) or source[start] != "{":
        return None
    depth = 0
    for i in range(start, len(masked)):
        ch = masked[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : i].strip()
    return None


def _mask_strings(source: str) -> str:
    result = re.sub(r'"""[\s\S]*?"""', lambda m: " " * len(m.group()), source)
    result = re.sub(r'"(?:[^"\\]|\\.)*"', lambda m: " " * len(m.group()), result)
    return result
