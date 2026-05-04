"""Generate SwiftUI dynamic replacement thunk code for hot-reload."""

from __future__ import annotations

from utell_ios.swift_parser import SwiftViewInfo

REFRESH_SYMBOL = "axe_preview_refresh"

_THUNK_TEMPLATE = """\
import SwiftUI
{extra_imports}
@_private(sourceFile: "{source_file}") import {module_name}

extension {struct_name} {{
    @_dynamicReplacement(for: body)
    var _hotreload_body: some View {{
    {view_body}
    }}
}}

import UIKit

@_cdecl("{refresh_symbol}")
public func _utellPreviewRefresh() {{
    DispatchQueue.main.async {{
        for scene in UIApplication.shared.connectedScenes {{
            guard let ws = scene as? UIWindowScene else {{ continue }}
            for window in ws.windows {{
                window.rootViewController?.view.setNeedsLayout()
                window.rootViewController?.view.layoutIfNeeded()
            }}
        }}
    }}
}}
"""


def generate_thunk(
    module_name: str,
    source_file_name: str,
    struct_name: str,
    view_body_source: str,
    extra_imports: str = "",
) -> str:
    body = _indent_body(view_body_source)
    return _THUNK_TEMPLATE.format(
        module_name=module_name,
        source_file=source_file_name,
        struct_name=struct_name,
        view_body=body,
        extra_imports=extra_imports,
        refresh_symbol=REFRESH_SYMBOL,
    )


def generate_thunk_from_view(
    module_name: str,
    view: SwiftViewInfo,
    extra_imports: str = "",
) -> str:
    return generate_thunk(
        module_name=module_name,
        source_file_name=view.source_file,
        struct_name=view.struct_name,
        view_body_source=view.view_body,
        extra_imports=extra_imports,
    )


def _indent_body(body: str, spaces: int = 4) -> str:
    indent = " " * spaces
    lines = body.splitlines()
    return "\n".join(indent + line if line.strip() else line for line in lines)
