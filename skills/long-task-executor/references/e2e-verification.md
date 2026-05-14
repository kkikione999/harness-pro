# User-Perspective E2E Verification

The e2e-runner's job is to confirm the system actually delivers the user's goal by executing BDD Scenarios as complete journeys. This document spells out what that means for different project types.

## The principle

Execute each BDD Scenario from start to finish as a real user would. The e2e-runner should never reach into internal modules to "verify" something — that's the functional-tester's job. The e2e-runner verifies the journey, not the functions.

## By project type

### Web frontend
- Start the dev server (`pnpm dev`, `npm run dev`, etc.)
- For each BDD Scenario, execute the Actions in order using playwright/chrome-devtools MCP
- Set up Preconditions (create test user, log in, etc.)
- Click/type/navigate through each Action
- Verify Expected Results by observing the UI (screenshot, text capture)
- Watch browser console for errors that might not surface in unit tests

### Backend API
- Start the service
- For each BDD Scenario, make the HTTP requests described in Actions
- Use realistic payloads — the kind a real client sends
- Verify Expected Results by checking responses (status, body, headers)
- Execute the full scenario, not just individual endpoints

### CLI tool
- For each BDD Scenario, run the commands described in Actions
- Check stdout, stderr, exit code for each step
- Verify Expected Results match the CLI output
- Try the complete workflow, not just isolated commands

### Library / package
- Write a consumer script for each BDD Scenario
- Import the public API and exercise the journey described in Actions
- Verify Expected Results by checking the script output
- The script should mirror how a real downstream user would use the library

### Mobile app
- If a simulator is available, install and walk through each Scenario
- If no simulator, run whatever automated UI tests exist
- Note: simulator E2E may exceed reasonable runtime — escalate if no shortcut exists

## What "PASS" actually requires

For each **BDD Scenario**, the e2e-runner must produce **observable evidence** that the complete journey worked:

- "User can reset password" → actual click-through of: request reset → receive email → click link → set new password → log in with new password
- "API rejects invalid input" → actual request sequence through the full scenario, not just one endpoint
- "Dashboard loads in under 500ms" → measured time from a real browser load as part of a user journey

"It looks like it works" is not evidence. "I'd expect it to work" is not evidence.

## What a e2e-runner should NOT do

- **Don't fix bugs.** The e2e-runner is a verifier, not an implementer. If it finds a bug, it returns FAIL with the bug description, and the orchestrator routes to the e2e-fix loop.
- **Don't read the source to figure out what should happen.** The e2e-runner goes by the BDD Scenario. If the Scenario is ambiguous, the e2e-runner should report that ambiguity, not guess.
- **Don't stop at the first failure.** Run all Scenarios; the orchestrator wants the full picture.
- **Don't verify individual functions.** That's the functional-tester's job. You verify journeys.

## When E2E genuinely can't be done

Some changes don't have a runnable E2E (e.g., pure refactoring with no behavioral change). The e2e-runner should still:
- Confirm any existing E2E tests still pass
- Confirm the diff doesn't change observable behavior

If the change is "no observable behavior should change", that itself is the contract; verify by checking that pre-existing E2E tests still pass with the same outputs.
