# Layer Rules

How to define, infer, and enforce layer dependencies.

## Layer Definitions

| Layer | Name | Description | Rule |
|-------|------|-------------|------|
| L0 | Types | Pure type definitions, enums, interfaces | No internal imports |
| L1 | Utils | General-purpose helpers, utilities | Import only L0 |
| L2 | Config | Configuration, settings | Import L0, L1 |
| L3 | Services | Business logic, domain layer | Import L0, L1, L2 |
| L4+ | Interface | HTTP handlers, CLI, UI, controllers | Import any lower |

## The One Rule

> **Higher layers can import lower layers; lower layers CANNOT import higher layers.**

```
┌─────────────────────────────────────────────┐
│  L4+: Interface (handlers, CLI, UI)         │
│         ↑ can import                        │
├─────────────────────────────────────────────┤
│  L3: Services (business logic)              │
│         ↑ can import                        │
├─────────────────────────────────────────────┤
│  L2: Config                                 │
│         ↑ can import                        │
├─────────────────────────────────────────────┤
│  L1: Utils                                  │
│         ↑ can import                        │
├─────────────────────────────────────────────┤
│  L0: Types (no internal imports allowed)    │
└─────────────────────────────────────────────┘
```

## Inferring Layers from Imports

### Process

1. **Build dependency graph** — For each file, note which packages it imports
2. **Find source packages** — Packages with no internal imports = L0 candidates
3. **Assign layers bottom-up** — Packages that only import L0 = L1; those that import L1 but not L4 = L2; etc.
4. **Detect cycles** — If A imports B and B imports A, they should be same layer

### Example: MarkdownPreview

```swift
// MarkdownFileType.swift (L0)
// - No internal imports

// LinkHandling.swift (L1)
// - Imports: Foundation
// - Uses: MarkdownFileType (L0)

// MarkdownInteractions.swift (L3)
// - Imports: Foundation, LinkHandling
// - LinkHandling is L1, no L4 imports → L3

// AppState.swift (L4)
// - Imports: AppKit, Combine, SwiftUI, Foundation, MarkdownInteractions
// - Uses MarkdownInteractions (L3) → L4
```

## Layer Mapping Format

In scripts/lint-deps, define layers as associative array:

```bash
declare -A LAYERS=(
    ["MarkdownFileType"]=0
    ["MarkdownRenderMode"]=0
    ["LinkHandling"]=1
    ["MarkdownInteractions"]=3
    ["AppState"]=4
    ["AppWindowManager"]=4
)
```

Or by directory:

```bash
declare -A DIR_LAYERS=(
    ["Types"]=0
    ["Utils"]=1
    ["Services"]=3
    ["UI"]=4
)
```

## Writing Educational Error Messages

### Bad Error
```
Forbidden import
```

### Good Error (must include 4 parts: WHAT, WHICH RULE, WHY WRONG, HOW TO FIX)
```
✗ VIOLATION FOUND

File: services/UserService.swift (Layer 3)
Imports: ui/WindowManager.swift (Layer 4)

THE RULE: Higher layers can import lower layers; lower CANNOT import higher.
WHY WRONG: Layer 3 (business logic) should not depend on Layer 4 (UI).
  This creates tight coupling between business rules and interface.
  Business logic becomes hard to test and reuse without UI.

HOW TO FIX (choose one):
  1. Move the dependency to a lower layer (e.g., create a protocol in L1)
  2. Pass the needed value as a parameter from the calling layer
  3. Move the UI-dependent code to Layer 4

Example fix:
  Before: UserService (L3) imports WindowManager (L4)
  After:  UserService (L3) takes a WindowDelegate protocol as parameter
```

### Error Message Template

```
✗ VIOLATION FOUND

File: {source_file} (Layer {source_layer})
Imports: {target_file} (Layer {target_layer})

THE RULE: Higher layers can import lower layers; lower CANNOT import higher.
WHY WRONG: Layer {source_layer} ({source_desc}) should not depend on Layer {target_layer} ({target_desc}).
  This breaks the dependency rule and creates tight coupling.

HOW TO FIX:
  1. Move dependency to a lower layer
  2. Pass needed value as a parameter from the caller
  3. Create a protocol/abstraction in an intermediate layer
```

## Checking Violations

```bash
# Pseudo-code for violation check
for each file:
    source_layer = get_layer(file)
    for each import in file:
        if import is internal:
            target_layer = get_layer(import)
            if source_layer < target_layer:
                # Lower layer importing higher - VIOLATION
                report_violation()
```

## Swift-Specific Considerations

- Use module name (file basename without extension) as layer key
- `import` statements to check: Foundation, AppKit, SwiftUI, Combine, MarkdownUI
- External packages (MarkdownUI) don't count as internal layers

## Go-Specific Considerations

- Package path is the key: `github.com/user/project/types`
- Use `go list -json all` to get full package graph
- Import path without module prefix: `types`, `utils`, `services`

## TypeScript-Specific Considerations

- File path relative to `src/` is the layer indicator
- Check `import` and `export` statements
- `from 'react'` or `from '@/utils'` patterns

## Python-Specific Considerations

- Check `import` and `from ... import` statements
- Module path: `package.module`
- `__init__.py` indicates a package boundary
