# Fix utell-ios: Hot Reload Framework Search & Multi-Platform Build Support

## Feature

Fix three confirmed bugs in the utell-ios MCP server that prevent hot reload and build from working with projects that use cross-framework imports and/or watchOS embedded targets.

## Background

Source analysis confirmed three root causes:

1. **`thunk_compiler.py:102`** — Only `-I` (module search path) is passed; no `-F` (framework search path). Framework-bundled modules like `HpSleeperKit.framework/Modules/HpSleeperKit.swiftmodule/` cannot be resolved.

2. **`preview_loader.py:196`** — Build always targets `platform=iOS Simulator` with `-scheme`. No multi-platform handling; watchOS embedding validation fails.

3. **`server.py:769`** — Same issue as #2 for `ios_build_and_install`.

## In Scope

- Add `-F {build_products_dir}` to thunk compiler for framework module resolution
- Add multi-platform build support to `preview_build` (skip or pre-build watchOS targets)
- Add multi-platform build support to `ios_build_and_install`
- Unit tests for all three fixes
- Backward compatible — no behavior change for projects without cross-framework imports or watchOS targets

## Out of Scope

- Changes to the native `loader.m` or `build_loader.sh`
- Changes to `thunk_generator.py` or `swift_parser.py`
- Support for tvOS, macOS, or visionOS embedded targets (can be added later)
- Any changes to non-utell-ios code

---

## Scenarios

### Scenario 1: Hot reload resolves framework-bundled module imports

**Preconditions:**
- A SwiftUI view file imports a project-internal framework (e.g., `import HpSleeperKit`)
- The framework is built as a separate target and produces a `.framework` bundle in the build products directory
- `ios_preview_build` has completed successfully

**Actions:**
1. Call `ios_preview_hot_reload` with the view file path
2. The thunk compiler is invoked with the file's parsed imports

**Expected Results:**
- The thunk compilation command includes `-F {build_products_dir}` in addition to the existing `-I {build_products_dir}`
- Compilation succeeds without `no such module` errors for framework-bundled modules
- The resulting dylib is injected into the running app
- A screenshot is captured and returned

### Scenario 2: Preview build succeeds with watchOS embedded target

**Preconditions:**
- The Xcode project has an iOS app target with an embedded watchOS app
- The scheme includes both iOS and watchOS targets
- An iOS simulator is booted

**Actions:**
1. Call `ios_preview_build` with the scheme name
2. The build orchestrator detects watchOS targets in the scheme

**Expected Results:**
- watchOS targets are either pre-built for the correct platform or excluded from the iOS build
- The iOS app builds and installs on the simulator without platform validation errors
- The loader dylib is injected and the preview socket is created
- The response includes `success: true` with the module name and socket path

### Scenario 3: Build and install succeeds with watchOS embedded target

**Preconditions:**
- Same preconditions as Scenario 2
- An iOS simulator is booted

**Actions:**
1. Call `ios_build_and_install` with the scheme name

**Expected Results:**
- The build handles multi-platform targets the same way as Scenario 2
- The app builds and installs on the booted simulator
- The response includes `success: true` with the app path

### Scenario 4: Backward compatibility — no regression for simple projects

**Preconditions:**
- A simple iOS project with no cross-framework imports and no watchOS targets
- An iOS simulator is booted

**Actions:**
1. Call `ios_build_and_install` with the scheme name
2. Call `ios_preview_build` followed by `ios_preview_hot_reload`

**Expected Results:**
- All three tools behave identically to their current behavior
- The added `-F` flag does not cause errors when no frameworks exist in the products directory
- Multi-platform detection finds no watchOS targets and takes no extra action
- Build, install, and hot reload all succeed as before

## Error Paths

- **No booted simulator**: Existing error handling applies; no change needed
- **Framework not in products dir**: Compiler will emit the same `no such module` error — this is correct behavior (the framework genuinely isn't built yet)
- **watchOS target build fails**: Should not block the iOS build; log the failure and continue
