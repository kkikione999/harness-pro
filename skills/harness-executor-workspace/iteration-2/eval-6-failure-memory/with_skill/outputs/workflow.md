# Workflow Analysis: Self-Repair Loop Failure for "Add caching to UserService"

## Scenario Recap

- **Task**: "Add caching to the UserService using the CacheManager from internal/cache/"
- **Complexity**: MEDIUM (delegated to sub-agent via Sonnet)
- **Failure point**: Step 6 (VALIDATE), pipeline step 2 (lint-deps)
- **Error**: `services/UserService.swift` (Layer 3) imports `internal/cache/CacheManager.swift` (Layer 1), but `internal/cache` is NOT in the layer mapping. services/ can import Layer 0-2 only.
- **Turn count at failure**: 38/60

---

## Question 1: What happens during the self-repair loop at each attempt?

### Pre-Repair Context

The sub-agent completed coding and reported:
```json
{
  "files_changed": ["services/UserService.swift"],
  "packages_affected": ["services"],
  "new_imports_added": true,
  "new_files_created": false
}
```

Because `new_imports_added: true`, the executor runs: `lint-deps -> build -> test` (per validation.md incremental rules). The pipeline stops at lint-deps with the layer violation error.

### Attempt 1: Move import to a higher layer

**Turns**: 38 -> ~42 (4 tool calls)

| Turn | Action |
|------|--------|
| 38 | Analyze lint-deps error output |
| 39 | Delegate fix to sub-agent: "Move the CacheManager import so it does not directly appear in services/ -- try routing through an intermediary" |
| 40-41 | Sub-agent reads files, moves the import statement to a wrapper in a different location |
| 42 | Re-run lint-deps |

**Result**: SAME ERROR. The lint-deps script still detects the transitive dependency. The import was moved but the layer violation persists because the underlying reference from Layer 3 to the unmapped `internal/cache` package remains.

**Context budget check**:
```
Turns used: ~42 / 60
Threshold: 40
42 >= 40 -> BUDGET EXCEEDED
Error is same as previous -> SAME ERROR REPEATS
Decision: Early-stop conditions met (turns >= 40 AND same error repeats)
Action: Executor notes the degradation but the 3-attempt ceiling is not yet reached.
         Signs of saturation NOT yet present (not repeating with minor variations).
         Proceeds to attempt 2 with caution.
```

### Attempt 2: Add internal/cache to Layer 1 mapping

**Turns**: ~42 -> ~47 (5 tool calls)

| Turn | Action |
|------|--------|
| 42-43 | Analyze why attempt 1 failed; hypothesize that the layer mapping itself is incomplete |
| 44 | Delegate fix to sub-agent: "Add internal/cache to the Layer 1 mapping in lint-deps configuration" |
| 45-46 | Sub-agent modifies the lint-deps config to map `internal/cache/` to Layer 1 |
| 47 | Re-run lint-deps |

**Result**: FAILURE. lint-deps now recognizes `internal/cache` as Layer 1, and Layer 3 (services) is allowed to import Layer 0-2. However, the architectural rule is more nuanced: services should not directly perform caching operations. The lint-deps script has a secondary check: services/ may only import from packages that are explicitly listed in a "services allowed imports" allowlist, and `internal/cache` is not on that list. Alternatively, the build may fail because the import still violates a design constraint that services must go through a protocol/interface for cross-cutting concerns like caching.

The exact failure: "services/ should not directly cache -- the caching concern must be abstracted behind a protocol at the correct layer."

**Context budget check**:
```
Turns used: ~47 / 60
Threshold: 40
47 >= 40 -> BUDGET EXCEEDED
Error type: still layer_violation (same category, different specific message)
Decision: The error is structurally similar but reveals a deeper architectural constraint.
         Saturation signs appearing: "Proposing changes that contradict earlier architecture decisions"
         The fix attempted to work around the lint rule rather than follow the architecture.
         Proceeds to attempt 3 as final attempt (approaching 3-attempt ceiling).
```

### Attempt 3: Create a CachingService protocol in Layer 2

**Turns**: ~47 -> ~53 (6 tool calls)

| Turn | Action |
|------|--------|
| 47-48 | Analyze attempts 1-2; recognize that a protocol-based abstraction is needed |
| 49 | Delegate fix to sub-agent: "Create a CachingService protocol in Layer 2 (protocols/ or interfaces/), implement it using CacheManager, inject into UserService via protocol" |
| 50-51 | Sub-agent creates new protocol file, implements concrete class, modifies UserService to depend on protocol |
| 52 | Re-run lint-deps -> PASSES (protocol is in Layer 2, services can import Layer 2) |
| 53 | Re-run build -> PASSES. Re-run test -> FAILS |

**Result**: NEW ERROR. lint-deps passes, build passes, but tests fail. The test failures are because:
- The new CachingService protocol was not accompanied by a mock/stub for unit tests
- Existing UserServiceTests now fail because the constructor requires a CachingService dependency
- Integration tests fail because no concrete CachingService implementation is registered in the dependency injection container

```
Test Suite 'UserServiceTests' failed:
  - test_init_requiresCacheService: XCTAssertNotNil failed - UserService init now requires CachingService parameter
  - test_fetchUser_returnsCachedValue: Missing mock for CachingService
  - test_saveUser_invalidatesCache: Missing mock for CachingService
3 tests failed, 0 crashed
```

**Context budget check**:
```
Turns used: ~53 / 60
Threshold: 40
53 >= 40 -> BUDLET EXCEEDED
Error is NEW (test_failure vs layer_violation) but 3 attempts exhausted
Decision: MAX ATTEMPTS REACHED (3/3). Context budget also deeply exceeded.
         Multiple signs of saturation present:
         - 53/60 turns used (88.3% of hard budget)
         - Fixes are getting more complex (from import move -> config change -> new protocol + DI)
         - Each fix introduces new problems that need further fixing
         STOP. Escalate to human.
```

---

## Question 2: What failure memory gets written? EXACT JSON content.

Per `references/memory.md` failure format:

```json
{
  "timestamp": "2026-04-19T10:45:00Z",
  "task": "add-caching-to-userservice",
  "error_type": "layer_violation",
  "error_message": "File: services/UserService.swift (Layer 3) Imports: internal/cache/CacheManager.swift (Layer 1) THE RULE: services/ can import Layer 0-2, but internal/cache is NOT in the layer mapping.",
  "attempted_fixes": [
    "Moved CacheManager import to a higher layer wrapper -- failed: same lint-deps error (transitive dependency still detected)",
    "Added internal/cache to Layer 1 mapping in lint-deps config -- failed: architectural rule that services should not directly cache requires protocol abstraction",
    "Created CachingService protocol in Layer 2 with CacheManager implementation -- lint-deps passed, build passed, but test failures: 3 tests failed due to missing mock/stub for CachingService and unregistered DI dependency"
  ],
  "resolved": false,
  "resolution": null
}
```

Per `references/completion.md` failure format:

```json
{
  "timestamp": "2026-04-19T10:45:00Z",
  "task": "add-caching-to-userservice",
  "error_type": "layer_violation",
  "error_message": "File: services/UserService.swift (Layer 3) Imports: internal/cache/CacheManager.swift (Layer 1) THE RULE: services/ can import Layer 0-2, but internal/cache is NOT in the layer mapping.",
  "attempted_fixes": [
    "Moved CacheManager import to a higher layer wrapper -- failed: same lint-deps error (transitive dependency still detected)",
    "Added internal/cache to Layer 1 mapping in lint-deps config -- failed: architectural rule that services should not directly cache requires protocol abstraction",
    "Created CachingService protocol in Layer 2 with CacheManager implementation -- lint-deps passed, build passed, but test failures: 3 tests failed due to missing mock/stub for CachingService and unregistered DI dependency"
  ],
  "resolved": false,
  "context_turns_at_failure": 53
}
```

**Note**: See Question 6 for the inconsistency between these two formats.

---

## Question 3: Does the context budget trigger early stop? Why or why not?

**Yes, the context budget triggers the stop, in combination with the 3-attempt ceiling.**

The early-stop condition is evaluated after each repair attempt:

| Attempt | Turns After | Budget Check (threshold: 40) | Same Error? | Early-Stop? | Action |
|---------|-------------|------|------------|-------------|--------|
| 1 | ~42 | 42 >= 40 -- EXCEEDED | Yes (same lint-deps error) | Yes (both conditions met) | Noted, but executor proceeds -- saturation signs not yet strong |
| 2 | ~47 | 47 >= 40 -- EXCEEDED | Yes (still layer_violation) | Yes (both conditions met) | Saturation signs appearing: fixes contradicting architecture. Executor proceeds as penultimate attempt. |
| 3 | ~53 | 53 >= 40 -- EXCEEDED | No (new error: test_failure) | Yes (turns >= 40) | MAX ATTEMPTS REACHED + budget exceeded. STOP. |

The stop is triggered because:
1. **3-attempt ceiling reached**: The "Max 3 attempts" rule from SKILL.md is an absolute maximum.
2. **Context budget exceeded**: At turns ~53, the executor is at 88% of the hard 60-turn limit and 33% past the 40-turn soft threshold.
3. **Signs of context saturation are present** (per completion.md):
   - "Repeating the same fix attempt with minor variations" -- attempts 1 and 2 are variations on bypassing the lint rule
   - "Proposing changes that contradict earlier architecture decisions" -- attempt 2 tried to change the layer mapping rather than follow the architecture
   - Each fix introduces new complexity requiring further fixes -- attempt 3 fixed lint but broke tests
4. **The error has evolved but not resolved**: The original layer_violation became a test_failure, meaning the repair is creating cascading issues rather than converging on a solution.

The executor does NOT attempt a 4th repair to fix the test failures from attempt 3 because:
- 3/3 attempts exhausted (hard ceiling per SKILL.md)
- Context budget deeply exceeded (53 >> 40)
- Continuing risks the agent losing track of its original objective

---

## Question 4: What gets reported to the human?

Per `references/completion.md`: "Report: 'Blocker at {step}: {error}. Manual intervention required.'"

The executor reports:

```
BLOCKER at Step 6 (VALIDATE): lint-deps layer violation

Task: Add caching to the UserService using the CacheManager from internal/cache/
Status: FAILED after 3 self-repair attempts (turns: 53/60)

Original Error:
  File: services/UserService.swift (Layer 3)
  Imports: internal/cache/CacheManager.swift (Layer 1)
  THE RULE: services/ can import Layer 0-2, but internal/cache is NOT in the layer mapping.

Repair Attempts:
  1. Moved import to higher layer wrapper -> same error (transitive dep detected)
  2. Added internal/cache to Layer 1 mapping -> same error (architectural rule: services should not directly cache)
  3. Created CachingService protocol in Layer 2 -> lint passed, build passed, but 3 test failures
     (missing mock/stub for CachingService, unregistered DI dependency)

Root Cause: internal/cache is not in the layer mapping AND the architecture requires
  protocol-based abstraction for cross-cutting concerns like caching. A CachingService
  protocol in Layer 2 is the correct approach but requires accompanying test infrastructure.

Recommended Actions:
  1. Add internal/cache to the layer mapping as Layer 1 (infrastructure)
  2. Create CachingService protocol at Layer 2 with proper mock for tests
  3. Register concrete CachingService in DI container
  4. Update UserServiceTests with CachingService mock

Context budget: 53/60 turns used (exceeded 40-turn repair threshold)
Failure saved to: harness/trace/failures/2026-04-19-add-caching-to-userservice.json
Manual intervention required.
```

---

## Question 5: Does this failure get flagged for Critic analysis? Why?

**Yes, this failure is flagged for Critic analysis.**

Per `references/memory.md`, failure memory is written "When to write" under these conditions:

| Condition | Met? | Evidence |
|-----------|------|----------|
| Same error occurs 2+ times | YES | The layer_violation error occurred 3 times: the original failure + attempt 1 + attempt 2 |
| Error required human intervention | YES | The executor exhausted all 3 repair attempts and the context budget, escalating to human |
| Error reveals missing lint rule | YES | `internal/cache` is NOT in the layer mapping, meaning the lint-deps configuration is incomplete |

All three conditions are met. The failure is written to `harness/trace/failures/` and will be picked up by the Critic's periodic analysis job.

**What the Critic would detect:**

The Critic (periodic job) scans `harness/trace/failures/` and would identify this pattern:
- Error type: `layer_violation` involving `internal/cache`
- Root cause: The `internal/cache` package exists in the codebase but is unmapped in `lint-deps`
- The correct architectural intent requires a protocol-based abstraction (CachingService in Layer 2)

**What the Refiner would do after Critic analysis:**

1. **Update lint-deps rules**: Add `internal/cache/` to the layer mapping (likely Layer 1 -- infrastructure)
2. **Update error messages**: Make the lint-deps error more actionable -- e.g., "internal/cache is unmapped. If this is infrastructure, add to Layer 1 mapping. If services need caching, create a protocol in Layer 2."
3. **Update documentation**: Add `internal/cache` to `docs/ARCHITECTURE.md` with its layer assignment and usage rules
4. **Optionally update lint-deps**: Add a specific rule that services/ importing cache-related packages must use protocol abstraction

---

## Question 6: Is the failure JSON format consistent between what memory.md specifies and what completion.md specifies?

**No, there is an inconsistency between the two specifications.**

### memory.md specifies this failure format:

```json
{
  "timestamp": "...",
  "task": "...",
  "error_type": "...",
  "error_message": "...",
  "attempted_fixes": ["..."],
  "resolved": true|false,
  "resolution": "..." | null       // <-- FIELD PRESENT
}
```

Fields: 7 total. Includes `resolution` (nullable string describing how the error was fixed, or null).

### completion.md specifies this failure format:

```json
{
  "timestamp": "...",
  "task": "...",
  "error_type": "...",
  "error_message": "...",
  "attempted_fixes": ["..."],
  "resolved": false,
  "context_turns_at_failure": 42    // <-- FIELD PRESENT
}
```

Fields: 7 total. Includes `context_turns_at_failure` (integer). Does NOT include `resolution`.

### Specific discrepancies:

| Aspect | memory.md | completion.md |
|--------|-----------|---------------|
| `resolution` field | Present (string or null) | **Missing** |
| `context_turns_at_failure` field | **Missing** | Present (integer) |
| `resolved` example | Shows both `true` and `false` | Shows only `false` |
| Total field count | 7 | 7 |

### Why this matters:

1. **An executor writing failure memory after context budget exhaustion** needs `context_turns_at_failure` to inform the Critic about budget state, but memory.md does not specify this field.
2. **An executor writing failure memory after eventual resolution** needs `resolution` to record the fix, but completion.md does not specify this field.
3. **The two specs define the SAME record type (failure memory in `harness/trace/failures/`)** but with different schemas.

### Recommended unified format:

```json
{
  "timestamp": "2026-04-19T10:45:00Z",
  "task": "{task-name}",
  "error_type": "layer_violation|circular_dependency|test_failure|build_failure",
  "error_message": "{full error}",
  "attempted_fixes": ["{fix 1}", "{fix 2}"],
  "resolved": false,
  "resolution": null,
  "context_turns_at_failure": 53
}
```

This merged format includes both `resolution` (for when failures are eventually resolved) and `context_turns_at_failure` (for context budget tracking and Critic analysis).
