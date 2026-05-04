# User-Perspective E2E Verification

The e2e-runner's job is to confirm the system actually delivers the user's goal, not just that the code compiles and unit tests pass. This document spells out what that means for different project types.

## The principle

Test the user-facing contract from the user's side. If the user is a person clicking a UI, the e2e-runner clicks the UI. If the user is another service, the e2e-runner makes the same kind of HTTP/RPC call that service would. The e2e-runner should never reach into internal modules to "verify" something — that's the unit test's job, and it's already been done.

## By project type

### Web frontend
- Start the dev server (`pnpm dev`, `npm run dev`, etc.)
- Open the page in a real browser via the playwright/chrome-devtools MCP if available
- Click through the user flow described in the requirement
- For each "Done when" condition, take a screenshot or describe what the e2e-runner observed
- Watch the browser console for errors that might not surface in unit tests

### Backend API
- Start the service
- Call the endpoint(s) with realistic payloads — the kind of body a real client sends, including the auth header, content-type, etc.
- Check the response status, headers, and body
- Hit at least one error case (bad payload, missing auth) to confirm error handling works end-to-end

### CLI tool
- Run the actual command with the actual flags a user would use
- Check stdout, stderr, exit code
- For commands that produce files, verify the file content
- Try at least one common error case (wrong arg, missing file)

### Library / package
- Write a tiny consumer script in a separate file
- Import the public API the way a downstream user would (no reaching into internal modules)
- Exercise the main use case from the requirement
- Verify type checking passes for a TypeScript consumer (or equivalent)

### Mobile app
- If a simulator is available, install the build and walk through the flow
- If no simulator, run whatever automated UI tests exist (`xcodebuild test`, `gradlew connectedAndroidTest`, etc.)
- Note: simulator E2E may exceed reasonable runtime — escalate if no shortcut exists

## What "PASS" actually requires

For each "Done when" condition from the approved restatement, the e2e-runner must produce **observable evidence**:

- "Test suite passes": full test command output showing 0 failures
- "Dashboard loads in under 500ms": measured time from a real browser load
- "API rejects invalid input with 400": actual HTTP request + actual 400 response captured
- "User can log in with email": actual click-through, actual session token visible

"It looks like it works" is not evidence. "I'd expect it to work" is not evidence.

## What a e2e-runner should NOT do

- **Don't fix bugs.** The e2e-runner is a verifier, not an implementer. If it finds a bug, it returns FAIL with the bug description, and the orchestrator routes back to the review loop.
- **Don't read the source to figure out what should happen.** The e2e-runner goes by the approved restatement. If the restatement is ambiguous, the e2e-runner should report that ambiguity, not guess.
- **Don't stop at the first failure.** Run all the verification steps; the orchestrator wants the full picture, not just the first broken thing.

## When E2E genuinely can't be done

Some changes don't have a runnable E2E (e.g., pure refactoring with no behavioral change). The e2e-runner should still:
- Run the test suite
- Run any type-check / lint / build steps
- Confirm the diff doesn't change observable behavior (per the plan's "Done when")

If the change is "no observable behavior should change", that itself is the contract; the e2e-runner verifies by checking that pre-existing E2E tests still pass with the same outputs.
