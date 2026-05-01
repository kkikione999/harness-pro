# Layer Rules Reference

For executor validation. See `harness-creator/references/layer-rules.md` for full details.

## The One Rule

> **Higher layers can import lower layers; lower layers CANNOT import higher layers.**

## Layer Definitions

| Layer | Name | Description | Rule |
|-------|------|-------------|------|
| L0 | Types | Pure type definitions, enums, interfaces | No internal imports |
| L1 | Utils | General-purpose helpers, utilities | Import only L0 |
| L2 | Config | Configuration, settings | Import L0, L1 |
| L3 | Services | Business logic, domain layer | Import L0, L1, L2 |
| L4+ | Interface | HTTP handlers, CLI, UI, controllers | Import any lower |

## Executor Usage

Before adding a cross-module import or creating files in new locations:

```bash
./scripts/lint-deps
```

If violation found, the error message will include:
- **WHAT**: Which file imports what
- **WHICH RULE**: The layer rule being violated
- **WHY WRONG**: Why this creates tight coupling
- **HOW TO FIX**: Specific remediation steps

## Error Message Example

```
✗ VIOLATION FOUND

File: services/UserService.swift (Layer 3)
Imports: ui/WindowManager.swift (Layer 4)

THE RULE: Higher layers can import lower layers; lower CANNOT import higher.
WHY WRONG: Layer 3 (business logic) should not depend on Layer 4 (UI).
  This creates tight coupling between business rules and interface.

HOW TO FIX:
  1. Move the dependency to a lower layer
  2. Pass needed value as a parameter from the caller
  3. Create a protocol/abstraction in an intermediate layer
```

## Layer Directory Mapping

```
Layer 0: types/       # Pure types, no internal dependencies
Layer 1: utils/       # Utilities, import only L0
Layer 2: config/      # Configuration, import L0, L1
Layer 3: services/    # Business logic, import L0-L2
Layer 4+: ui/ cli/   # Interface layer, import any lower
```
