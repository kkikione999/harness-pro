# Harness Executor Workflow: POST /users Endpoint (Medium Complexity)

Scenario: Task is "Add a new API endpoint POST /users that creates a user".
Complexity: MEDIUM (multi-file changes, consistent pattern -- touches types/, services/, handlers/, router, and tests).

---

## 1. Memory Lookups During Step 2 (Load Context)

Step 2 of the executor workflow reads AGENTS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, and checks harness/memory/INDEX.md for relevant patterns and past lessons. The memory lookups happen in this exact order:

**Lookup 1: Read INDEX.md (quick scan)**

The executor reads `harness/memory/INDEX.md` first. This provides a quick-scan summary of all memories. From the INDEX, the executor identifies three relevant entries:

- **Procedural**: `add-api-endpoint` -- 5-step flow, 5/6 success, last: 2026-04-18. This directly matches the task type ("add a new API endpoint").
- **Episodic**: `api-error-format` -- lesson about wrapping errors in a structured format. Relevant because the task involves creating an API endpoint that will return error responses.
- **Recent Failure**: `user-model-import` -- a layer violation where handlers imported services directly (L4 -> L3 skip), resolved via dependency injection. Relevant because this task will also create a handler that needs a service.

**Lookup 2: Load procedural memory (specific procedure)**

Because the task type "add a new API endpoint" matches the procedural memory entry `add-api-endpoint`, the executor loads `harness/memory/procedural/add-api-endpoint.md`. This yields the 5-step procedure:

1. Create type definition in types/api/ (Layer 0)
2. Create service method in services/ (Layer 3)
3. Create handler in handlers/ (Layer 4)
4. Register route in router
5. Write integration test

**Lookup 3: Load episodic memory (related lesson)**

Because the task involves API endpoint development and the episodic entry `api-error-format` is directly about API error responses, the executor loads `harness/memory/episodic/api-error-format.md`. This yields the lesson: always wrap error responses in `{"error": {"code": "ERROR_CODE", "message": "Human readable"}}` format.

**Lookup 4: Load recent failure (avoid known pitfall)**

Because the task involves creating handlers that use services (same modules implicated in the failure), the executor loads `harness/trace/failures/2026-04-17-user-import.json`. This yields: a handler directly imported a service (L4 -> L3 violation), fixed by using dependency injection instead of direct import.

---

## 2. How the Procedural Memory (add-api-endpoint) Affects Execution

The procedural memory directly dictates the execution steps. Because this is a MEDIUM complexity task (multi-file, consistent pattern), the executor delegates to a sub-agent, and the procedural memory provides the exact step sequence the sub-agent must follow.

**The executor follows ALL 5 steps from the procedural memory, in order:**

1. **Create type definition in types/api/ (Layer 0)** -- Define the CreateUserRequest and CreateUserResponse types. This goes in the lowest layer (pure types, no internal imports), ensuring no layer violations.

2. **Create service method in services/ (Layer 3)** -- Implement the business logic for creating a user in a service class. The service imports from Layer 0 (types) and potentially Layer 1 (utils) and Layer 2 (config), which is legal (L3 can import L0-L2).

3. **Create handler in handlers/ (Layer 4)** -- Create the HTTP handler for POST /users. The handler imports from Layer 0-3, which is legal (L4 can import any lower layer). However, informed by the recent failure, the handler uses dependency injection rather than a direct import of the service.

4. **Register route in router** -- Wire the new handler to the POST /users route in the application's router configuration.

5. **Write integration test** -- Create an integration test that validates the full flow: request comes in, user is created, correct response returned.

**Additionally**, because this is a MEDIUM task, the executor first creates an execution plan at `docs/exec-plans/add-post-users.md` using the template from `references/execution-plan.md`, listing the 5 steps above with impact scope and validation checklist. The plan is presented for human approval before execution begins (Step 4 of the executor workflow).

The sub-agent (model: sonnet, per model selection rules for medium complexity) receives these 5 steps as its task description and executes them in order, validating after each major step.

---

## 3. How the Episodic Memory (api-error-format) Affects the Code Written

The episodic memory imposes a concrete constraint on ALL error responses produced by the new endpoint. Specifically, it changes the code in these ways:

**Handler error responses (Step 3 of the procedure):**

Every error response in the POST /users handler must use this exact structure:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable description"
  }
}
```

This affects:
- **400 Bad Request** (e.g., missing required fields): `{"error": {"code": "VALIDATION_ERROR", "message": "Email field is required"}}`
- **409 Conflict** (e.g., user already exists): `{"error": {"code": "USER_ALREADY_EXISTS", "message": "A user with this email already exists"}}`
- **500 Internal Server Error** (e.g., database failure): `{"error": {"code": "INTERNAL_ERROR", "message": "Failed to create user"}}`

The executor explicitly does NOT use bare string errors like `"User not found"` or flat structures like `{"error": "Something went wrong"}`.

**Service layer error handling (Step 2 of the procedure):**

The service throws domain-specific errors (or returns error types) that the handler then wraps into the required error envelope format. The service itself does not produce HTTP-specific error JSON; it produces domain errors that the handler translates. But the handler MUST use the envelope format consistently.

**Integration test assertions (Step 5 of the procedure):**

The integration test must verify error responses match the envelope format. Test cases include:
- Sending a malformed request and asserting the response body contains `{"error": {"code": ..., "message": ...}}`
- Sending a duplicate user request and asserting the same envelope structure

---

## 4. How the Recent Failure (user-model-import) Affects Execution

The failure record describes: "handlers/UserHandler.swift imports services/UserService.swift directly (L4 -> L3 skip), resolved by using dependency injection."

**This is NOT a layer violation in the strict sense** (L4 CAN import L3; the layer rules say "Higher layers can import lower layers"). However, the failure record indicates the project's lint-deps rule caught a specific import pattern as problematic -- likely the handler directly instantiated or imported a concrete service class rather than depending on an abstraction/protocol.

**What the executor avoids:**

The executor does NOT write code where the handler directly imports and instantiates a concrete UserService class. Instead, it uses dependency injection:

- The handler receives the UserService (or a protocol/abstraction that UserService conforms to) via its constructor/initializer, NOT by importing and creating it internally.
- The wiring of the concrete service to the handler happens in the router configuration or a DI container (Step 4 of the procedure), which is the appropriate place for composition.
- The service is passed as a parameter from the composition root, not fetched from within the handler.

**Pre-validation rule applied:**

Per the SKILL.md "Pre-validation rule", before creating the handler file and adding any cross-module imports, the executor runs `./scripts/lint-deps` to catch layer violations BEFORE they happen. This ensures the dependency injection approach passes the architecture lint on the first attempt.

**Execution plan note:**

The execution plan at `docs/exec-plans/add-post-users.md` explicitly notes: "Use dependency injection for service in handler (per failure memory: user-model-import). Handler must NOT directly instantiate service."

---

## 5. Memory Updates After Successful Completion

After the task completes successfully (all validations pass, cross-review passes), Step 8 (Complete) triggers these memory updates:

**Update 1: Procedural memory -- increment success count**

`harness/memory/procedural/add-api-endpoint.md` is updated:
- Success rate changes from `5/6` to `6/7`
- Last Validated changes to `2026-04-19` (today's date)

**Update 2: INDEX.md -- update procedural entry and check compilation trigger**

`harness/memory/INDEX.md` is updated:
- The add-api-endpoint entry changes from "5/6 success" to "6/7 success, last: 2026-04-19"
- Since the success count is now 6 (well above the 3+ threshold) and the steps remain consistent, the executor flags this pattern as ready for compilation:
  ```
  - [add-api-endpoint](procedural/add-api-endpoint.md) -- 5-step flow, 6/7 success, last: 2026-04-19 <-- READY TO COMPILE
  ```

**Update 3: Trajectory compilation prompt**

Per the trajectory compilation trigger in `references/memory.md`, the executor prompts the human:
> "Pattern 'add-api-endpoint' succeeded 6x. Steps are consistent. Compile to script?"

If the human confirms, the executor generates `scripts/add-api-endpoint.sh` -- a deterministic script that automates the 5-step flow. The INDEX.md entry is updated to: `compiled -> scripts/add-api-endpoint.sh`.

**Update 4: Trace -- write success record**

A success record is written to `harness/trace/` (not in the failures directory). This records:
- Task name: `add-post-users`
- Timestamp: 2026-04-19
- Steps completed: all 5 from the procedure
- Validation results: all passed
- Cross-review result: PASS

**Update 5: Checkpoint -- save final phase**

A checkpoint is saved at `harness/trace/checkpoints/add-post-users/phase-5-reviewed.json` recording the final state, files changed, and validation results.

**Update 6: Episodic memory -- no new entry (unless a new lesson was discovered)**

If the execution revealed a new non-obvious lesson (e.g., a quirk about the router configuration), it would be written to `harness/memory/episodic/`. But if the task followed the known procedure without surprises, no new episodic memory is created.

**Update 7: Failure memory -- no new entry (task succeeded)**

No failure record is written since the task succeeded. The existing failure record for `user-model-import` remains in place but is now 2 days old; it will age out of the "Recent Failures (Last 7 days)" section after 2026-04-24.

**Update 8: Git commit**

Files are staged specifically (not `git add -A`) and committed with message:
```
feat: add POST /users endpoint for user creation
```

For this MEDIUM task, a feature branch is used, with an optional PR created afterward.
