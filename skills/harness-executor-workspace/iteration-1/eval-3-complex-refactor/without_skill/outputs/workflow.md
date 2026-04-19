# Workflow: Break Circular Dependency Between UserService and AuthService

## Task Summary

`services/UserService.swift` and `services/AuthService.swift` import each other, creating a circular dependency. The refactoring must break this cycle using a protocol-based approach while preserving existing behavior.

## Step 1: Understand the Current Dependency Graph

**Goal**: Map the exact import relationships and public API surface before changing anything.

**Actions**:
1. Read `services/UserService.swift` to identify:
   - What it imports from `AuthService` (types, functions, protocols).
   - What it exposes publicly that `AuthService` consumes.
   - All methods and properties that reference `AuthService` types.
2. Read `services/AuthService.swift` to identify the same in reverse.
3. Draw a dependency map: which specific symbols flow in which direction.
4. Read any test files for both services to understand expected behavior.

**Validation**: Confirm the circular dependency exists and identify the minimal set of symbols that create the cycle.

## Step 2: Determine the Dependency Direction

**Goal**: Decide which layer should be the "lower" layer (imported by the other).

**Decision criteria**:
- `AuthService` is fundamentally about authentication (token management, credential verification). This is infrastructure-level.
- `UserService` is about user data management (profiles, preferences). This is domain-level.
- Convention: infrastructure should not depend on domain. Domain depends on infrastructure.
- Therefore: `AuthService` should be the lower layer. `UserService` may import `AuthService`, but NOT the reverse.

**If the cycle goes both ways**: Extract the shared interface into a protocol in a separate, lower-level module that both can depend on.

**Validation**: Write down the chosen direction and verify it aligns with the project's existing layering rules (check `docs/ARCHITECTURE.md` or `CLAUDE.md` for dependency constraints).

## Step 3: Extract Protocols to Break the Cycle

**Goal**: Define protocols that decouple the two services.

**Actions**:
1. Create a new file: `services/protocols/UserServiceProtocol.swift`
   - Define a protocol declaring the methods on `UserService` that `AuthService` currently calls directly.
   - Example: `protocol UserServiceProviding { func getUser(by id: UserID) -> User? }`
2. Create a new file: `services/protocols/AuthServiceProtocol.swift`
   - Define a protocol declaring the methods on `AuthService` that `UserService` currently calls directly.
   - Example: `protocol AuthServiceProviding { func validateToken(_ token: String) -> UserIdentity? }`
3. Ensure protocols live in a location that does NOT import either service. They should import only foundation types or shared models.

**Validation**:
- Protocols compile independently.
- Neither protocol file imports `UserService` or `AuthService`.
- Protocol methods match the existing signatures exactly (no behavior change).

## Step 4: Conform Services to Protocols

**Goal**: Make each service adopt the corresponding protocol without changing behavior.

**Actions**:
1. Update `UserService`:
   - Remove the direct import of `AuthService`.
   - Import `AuthServiceProtocol` instead.
   - Add `: UserServiceProviding` conformance to the class declaration.
   - Accept an `AuthServiceProviding` instance via initializer injection (dependency injection).
   - Replace all direct `AuthService` calls with calls through the protocol.
2. Update `AuthService`:
   - Remove the direct import of `UserService`.
   - Import `UserServiceProtocol` instead.
   - Add `: AuthServiceProviding` conformance to the class declaration.
   - Accept a `UserServiceProviding` instance via initializer injection.
   - Replace all direct `UserService` calls with calls through the protocol.

**Validation**:
- Neither service file imports the other.
- Both compile against their respective protocol.
- All existing public methods remain with identical signatures.

## Step 5: Update Dependency Injection / Assembly

**Goal**: Wire up the now-decoupled services at the composition root.

**Actions**:
1. Find where `UserService` and `AuthService` are instantiated (e.g., a DI container, app delegate, or assembly file).
2. Update the wiring to pass protocol-conforming instances to each service's initializer.
3. If both services need each other at init time, use lazy initialization or a factory pattern to resolve the chicken-and-egg problem:
   - Option A: Pass one as a lazy reference or closure `() -> UserServiceProviding`.
   - Option B: Use a two-phase setup (init then configure).
   - Option C: Introduce a small coordinator/assembly that holds both references.
4. Update any mock/stub implementations used in tests to conform to the new protocols.

**Validation**:
- The app compiles and links without circular import errors.
- Runtime wiring produces correctly initialized instances.

## Step 6: Update and Run Tests

**Goal**: Verify no behavior was lost or altered.

**Actions**:
1. Run existing tests for `UserService` and `AuthService`. All must pass.
2. If tests previously relied on concrete types, update them to use protocol types where appropriate.
3. Add a new test that verifies:
   - `UserService` can be instantiated with a mock `AuthServiceProviding`.
   - `AuthService` can be instantiated with a mock `UserServiceProviding`.
   - Neither test file imports both concrete services.
4. Run the full test suite to catch any integration regressions.

**Validation**:
- All pre-existing tests pass.
- New isolation tests pass.
- Test coverage for both services remains at or above 80%.

## Step 7: Run Architecture Lint and Final Verification

**Goal**: Confirm the circular dependency is gone and no new violations were introduced.

**Actions**:
1. Run `scripts/lint-deps` (dependency direction checker) if available. Otherwise, manually verify:
   - `services/protocols/` imports nothing from `services/` (except shared model types).
   - `UserService` imports `AuthServiceProtocol` but NOT `AuthService`.
   - `AuthService` imports `UserServiceProtocol` but NOT `UserService`.
2. Run `scripts/lint-quality` if available for quality rule checks.
3. Run a full build: `xcodebuild build` or equivalent.
4. Run `scripts/validate.py` (unified validation entry) if it exists.

**Validation**:
- Build succeeds with zero errors and zero new warnings.
- Dependency lint reports no circular imports.
- No files exceed 800 lines.
- All protocols and conformances follow Swift naming conventions.

## Step 8: Code Review

**Goal**: Get a second set of eyes on the structural change.

**Review checklist**:
- [ ] Protocol methods match original service signatures exactly.
- [ ] No behavior was silently changed (only structure changed).
- [ ] Dependency injection is wired correctly at the composition root.
- [ ] No new circular dependencies introduced.
- [ ] Protocol files have no unnecessary imports.
- [ ] Test coverage maintained at 80%+.
- [ ] No hardcoded dependencies remain (all injected).

## Step 9: Commit

**Goal**: Commit with a clear message describing the structural change.

**Commit message format**:
```
refactor: break circular dependency between UserService and AuthService

Extract AuthServiceProviding and UserServiceProviding protocols into
services/protocols/. Both services now depend on protocols rather than
concrete types, with wiring handled at the composition root.

No behavior changes. All existing tests pass.
```

**Files to stage**:
- `services/protocols/AuthServiceProtocol.swift` (new)
- `services/protocols/UserServiceProtocol.swift` (new)
- `services/AuthService.swift` (modified)
- `services/UserService.swift` (modified)
- Dependency injection / assembly file (modified)
- Any updated test files (modified)
