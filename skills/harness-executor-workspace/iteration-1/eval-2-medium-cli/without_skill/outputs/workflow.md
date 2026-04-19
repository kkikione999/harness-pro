# Workflow: Add 'harness validate' CLI Command

## Task Summary

Add a new CLI command `harness validate` that invokes `scripts/validate.py` and returns its exit code. This requires changes across multiple files: a new command module, registration in the CLI entry point, and potential configuration updates.

## Complexity Assessment

**Classification: Medium**

Rationale: The task can be described as "add a CLI command that wraps the existing validate script" but it affects multiple files in a consistent pattern (new command file + registration + config). It does not require architectural decisions or new module creation. It follows a well-established pattern (command registration).

## Step-by-Step Process

### Phase 1: Discovery and Context Loading

1. **Read AGENTS.md** (if it exists) to understand the project's layer rules, build commands, and directory conventions.

2. **Read docs/ARCHITECTURE.md** (if it exists) to understand:
   - Where CLI commands live in the project structure
   - How existing commands are organized
   - What layer the CLI entry point belongs to and what it is allowed to import

3. **Read docs/DEVELOPMENT.md** (if it exists) for development conventions, common task patterns, and build/test commands.

4. **Examine existing CLI structure** by searching the codebase:
   - Find the main CLI entry point (e.g., `cli/__main__.py`, `cli/main.py`, or `src/cli.py`)
   - Identify how existing commands are registered (decorator pattern, command map, plugin system, etc.)
   - Find an existing command to use as a reference implementation

5. **Examine scripts/validate.py** to understand:
   - Its exit code contract (0 for success, non-zero for failure)
   - Whether it accepts any arguments or flags
   - Whether it has any dependencies or side effects

### Phase 2: Planning

6. **Create an execution plan** at `docs/exec-plans/harness-validate.md` containing:
   - List of files to create or modify
   - Dependency graph between changes
   - Validation steps to run after each change
   - Rollback strategy if something goes wrong

7. **Identify the specific files affected**:
   - **New file**: Command module (e.g., `cli/commands/validate.py` or equivalent following existing patterns)
   - **Modified file**: CLI entry point (to register the new command)
   - **Potentially modified**: Configuration file if command metadata is config-driven
   - **Potentially new**: Test file for the new command (e.g., `tests/test_validate_command.py`)

8. **Present the plan for human approval** before proceeding with any code changes. The plan should include the exact file paths and the nature of each change.

### Phase 3: Implementation

9. **Create the new command module** (e.g., `cli/commands/validate.py`):
    - Define the command handler function/class
    - Use `subprocess.run` to invoke `scripts/validate.py`
    - Capture and propagate the exit code
    - Stream stdout/stderr to the terminal for real-time feedback
    - Handle the case where `scripts/validate.py` does not exist (fail with a clear error message)

10. **Register the command in the CLI entry point**:
    - Add the import for the new command module
    - Register the command name (`validate`) and its handler
    - Follow the exact registration pattern used by existing commands (decorator, `add_command()`, dictionary entry, etc.)

11. **Update configuration if needed**:
    - If commands are declared in a config file (e.g., `pyproject.toml`, `setup.cfg`, `commands.yaml`), add the new command entry
    - If no config-driven registration exists, skip this step

### Phase 4: Testing (TDD Discipline)

12. **Write tests first** (RED phase):
    - Unit test: mock `subprocess.run` and verify the command calls `scripts/validate.py` with the correct arguments
    - Unit test: verify exit code 0 is propagated when validate.py succeeds
    - Unit test: verify non-zero exit codes are propagated when validate.py fails
    - Unit test: verify error handling when validate.py is missing
    - Integration test: invoke the CLI entry point with `validate` argument and verify end-to-end behavior

13. **Run tests** and confirm they fail (no implementation yet or partial implementation).

14. **Complete implementation** if not already done in Phase 3.

15. **Run tests again** and confirm they pass (GREEN phase).

16. **Refactor if needed** (IMPROVE phase):
    - Ensure no code duplication with other command modules
    - Verify function sizes are under 50 lines
    - Check that error messages are user-friendly

### Phase 5: Validation Pipeline

17. **Run the full validation pipeline** in order, stopping on first failure:

    a. **Build**: Run the project's build command to ensure the new code compiles/imports correctly.

    b. **Lint Architecture** (`scripts/lint-deps`): Verify that the new command module does not violate any layer import rules. The CLI layer should only import from layers below it, never from higher layers.

    c. **Lint Quality** (`scripts/lint-quality`): Check formatting, naming conventions, and code quality rules.

    d. **Test**: Run the full test suite, not just the new tests, to catch any regressions.

    e. **Verify E2E** (`scripts/verify/run.py`): Run end-to-end verification if available.

18. **If any step fails**: Analyze the error, fix the issue, and re-run from the failed step (not from the beginning).

### Phase 6: Cross-Review

19. **Delegate code review to a different perspective** (or model, in an AI context):
    - Present the full diff of all changed files
    - Ask the reviewer to check for: logic errors, missing error handling, layer violations, security issues, and consistency with existing command patterns
    - Classify any issues found as CRITICAL, HIGH, MEDIUM, or LOW

20. **Address review findings**:
    - Fix all CRITICAL and HIGH issues
    - Fix MEDIUM issues when practical
    - Re-run validation after fixes

### Phase 7: Completion

21. **Commit the changes** with a properly formatted commit message:
    ```
    feat: add 'harness validate' CLI command

    Registers a new 'validate' command that invokes scripts/validate.py
    and propagates its exit code. Includes unit and integration tests.
    ```

22. **Write memory/trace records** (if the harness memory system is set up):
    - Episodic: Record that this pattern (adding a CLI command) was successful
    - Update `harness/memory/INDEX.md` if it exists

23. **Summarize the result**: Report which files were changed, which validations passed, and any issues encountered.

## Files Likely Affected

| File | Action | Purpose |
|------|--------|---------|
| `cli/commands/validate.py` | Create | New command handler |
| `cli/main.py` (or equivalent) | Modify | Register the validate command |
| `tests/test_validate_command.py` | Create | Tests for the new command |
| `docs/exec-plans/harness-validate.md` | Create | Execution plan (transient) |
| Config file (if applicable) | Modify | Command metadata registration |

## Risk Assessment

- **Low risk**: The task follows an existing pattern (other CLI commands already exist). The validate.py script already works independently.
- **Primary concern**: Ensuring the new command module adheres to layer import rules. The CLI layer must not import from unintended layers.
- **Secondary concern**: Handling edge cases where validate.py is missing or not executable.

## Edge Cases to Handle

1. `scripts/validate.py` does not exist at the expected path
2. `scripts/validate.py` is not executable
3. The subprocess is interrupted (SIGINT/SIGTERM)
4. The project root is not the current working directory when the command runs
5. Python interpreter path mismatch (shebang line in validate.py)
