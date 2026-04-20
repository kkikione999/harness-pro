# Validation Pipeline

The executor runs these validations in order. **Stop on first failure.**

## Pipeline Steps

```bash
# Step 1: BUILD
# Verify code compiles
swift build    # Swift
go build      # Go
npm build     # TypeScript/Node
make build    # Or use project's build command

# Step 2: LINT ARCHITECTURE
# Verify layer dependencies are correct
./scripts/lint-deps

# Step 3: LINT QUALITY
# Verify code quality standards
./scripts/lint-quality

# Step 4: TEST
# Run unit and integration tests
swift test    # Swift
go test      # Go
npm test     # TypeScript/Node
make test    # Or use project's test command

# Step 5: VERIFY (E2E)
# Run end-to-end functional verification
python3 scripts/verify/run.py
```

## When to Run Each Step

| Scenario | Steps to Run |
|----------|-------------|
| Simple file edit | build → test |
| Cross-module change | build → lint-deps → test |
| New file in new location | lint-deps → build → test |
| Any structural change | Full pipeline (all 5) |

## Incremental Validation

After sub-agent completes a task step, run only the steps relevant to the change scope. Sub-agent reports `impact_scope`:

```json
{
  "files_changed": ["services/UserService.swift"],
  "packages_affected": ["services"],
  "new_imports_added": false,
  "new_files_created": false
}
```

Map impact to validation steps:

| Impact Scope | Validation Steps |
|-------------|-----------------|
| Single file, no new imports | build → test (affected package only) |
| New imports across packages | lint-deps → build → test |
| New files created | lint-deps → lint-quality → build → test |
| Structural/architectural change | Full pipeline |

## Validation Scripts

### validate.py (Unified Entry Point)

```bash
python3 scripts/validate.py
```

This runs all steps in order. Use this as the standard validation entry.

### Individual Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/lint-deps` | Check layer dependencies |
| `./scripts/lint-quality` | Check code quality (file length, logging, hardcoded strings) |

## Exit Behavior

```
build FAIL    → STOP, report build error
lint-deps FAIL → STOP, report layer violation
lint-quality FAIL → STOP, report quality issue
test FAIL     → STOP, report test failure
verify FAIL   → STOP, report verification failure
all PASS      → Continue to completion
```

## Self-Repair Loop

```
Validation failed
    ↓
Analyze error type
    ↓
┌─────────────────────────────────────────┐
│ If build/lint/test error:                │
│   → Sub-agent fixes the specific error   │
│   → Re-run that step only                │
│   → If passes, continue pipeline         │
│   → If fails again, count as 2nd attempt │
└─────────────────────────────────────────┘
    ↓
[Loop up to 3 times]
    ↓
If still failing after 3 self-repair attempts:
    → STOP execution
    → Save to harness/trace/failures/
    → Report to human for manual intervention
```

## Verify (E2E) Skeleton

If `scripts/verify/run.py` doesn't exist yet:

```bash
# Create the skeleton
mkdir -p scripts/verify
cat > scripts/verify/run.py << 'EOF'
#!/usr/bin/env python3
"""E2E verification runner."""

def main():
    print("TODO: Implement E2E verification for your project")
    print("This should verify the actual functionality works end-to-end")
    return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)
EOF
chmod +x scripts/verify/run.py
```

Fill in the TODOs based on your project's core user flows.
