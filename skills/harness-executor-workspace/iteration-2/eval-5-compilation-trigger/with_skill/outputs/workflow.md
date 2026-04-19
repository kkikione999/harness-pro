# Harness Executor Workflow: "Add User Database Model" — Compilation Trigger Scenario

Task: Add a new database model User with fields: id (UUID), name (string), email (string), created_at (timestamp)
Complexity: MEDIUM (multi-file changes, consistent pattern)

---

## Question 1: What happens during Step 2 (Load Context) when you find the already-compiled-ready procedure?

Step 2 performs the following sequence:

1. Read `AGENTS.md` (entry point, layer rules, build commands).
2. Read `docs/ARCHITECTURE.md` (layer diagram, package responsibilities).
3. Read `docs/DEVELOPMENT.md` (build commands, common tasks).
4. Check `harness/memory/INDEX.md` for relevant patterns.

Upon reading `harness/memory/INDEX.md`, the executor finds:

```
## Procedural (Successful Patterns)
- [add-database-model](procedural/add-database-model.md) — 4-step flow, 3/3 success, last: 2026-04-18 ← READY TO COMPILE
```

The `← READY TO COMPILE` marker signals that this procedure has already hit the compilation threshold (3/3 success with consistent steps). The executor then loads the full procedure from `harness/memory/procedural/add-database-model.md`:

```
# Procedure: add-database-model
## When to Use
Adding any new database model to the project
## Steps
1. Create type file in types/ (Layer 0)
2. Create model file in models/ (Layer 1)
3. Register in model registry
4. Write unit test
## Success Rate
3/3 successful executions
## Last Validated
2026-04-18
```

**This procedure matches the current task exactly** ("Adding any new database model to the project"). The executor uses this 4-step procedure as the blueprint for the execution plan in Step 3, rather than deriving steps from scratch. The procedural memory informs the plan that:

- Step 1 goes to `types/` (Layer 0 — pure type definition)
- Step 2 goes to `models/` (Layer 1 — model implementation)
- Step 3 touches the model registry
- Step 4 writes a unit test

The executor also notes that this procedure is flagged `← READY TO COMPILE`, meaning **during Step 8 (Complete), trajectory compilation will be triggered** because this execution will bring the count to 4/4.

---

## Question 2: What happens during Step 8 (Complete) with trajectory compilation?

Step 8 follows this exact sequence:

### 8a. Git Operations (Medium task = feature branch)

```bash
git checkout -b feat/add-user-model
git add types/User.ts models/User.ts models/registry.ts tests/models/User.test.ts
git commit -m "feat: add User database model with id, name, email, created_at fields"
```

### 8b. Memory Write

The executor updates the procedural memory file at `harness/memory/procedural/add-database-model.md` to reflect this 4th successful execution:

```markdown
# Procedure: add-database-model

## When to Use
Adding any new database model to the project

## Steps
1. Create type file in types/ (Layer 0)
2. Create model file in models/ (Layer 1)
3. Register in model registry
4. Write unit test

## Success Rate
4/4 successful executions

## Last Validated
2026-04-19
```

### 8c. Trace Write

A success trace is written to `harness/trace/` (not `harness/trace/failures/` since this succeeded).

### 8d. Trajectory Compilation Check

The executor checks the compilation trigger conditions:

1. Procedural memory exists for `add-database-model`? **YES**
2. Success count >= 3? **YES** (now 4/4)
3. Steps are consistent across executions? **YES** (same 4 steps in same order)

All three conditions are met. The INDEX.md already has `← READY TO COMPILE` on this entry.

The executor now executes the compilation process:

1. **Prompt user**: "Pattern 'add-database-model' succeeded 4x with consistent steps. Compile to deterministic script?"
2. **If user confirms**: Generate `scripts/add-database-model.sh`
3. **Update INDEX.md**: Change the marker from `← READY TO COMPILE` to `compiled → scripts/add-database-model.sh`

### 8e. Summary

```
Completed: add-user-model
Validated: build PASS, lint-arch PASS, lint-quality PASS, test PASS, verify PASS, cross-review PASS
Memory: procedural/add-database-model.md updated (4/4 success)
Compilation: scripts/add-database-model.sh generated
```

---

## Question 3: EXACT script content generated at `scripts/add-database-model.sh`

```bash
#!/bin/bash
# Auto-compiled from trajectory: add-database-model
# Success rate: 4/4, last validated: 2026-04-19
#
# Usage: ./scripts/add-database-model.sh <ModelName> <field1:type1> <field2:type2> ...
# Example: ./scripts/add-database-model.sh User id:uuid name:string email:string created_at:timestamp

set -e

MODEL_NAME="$1"
shift

if [ -z "$MODEL_NAME" ]; then
    echo "Usage: $0 <ModelName> <field1:type1> <field2:type2> ..."
    echo "Example: $0 User id:uuid name:string email:string created_at:timestamp"
    exit 1
fi

# Convert ModelName to snake_case for file naming
# e.g., UserProfile -> user_profile
SNAKE_NAME=$(echo "$MODEL_NAME" | sed -E 's/([A-Z])/_\L\1/g' | sed 's/^_//')
LOWER_NAME=$(echo "$MODEL_NAME" | tr '[:upper:]' '[:lower:]')

echo "=== Adding database model: $MODEL_NAME ==="
echo "=== File prefix: $SNAKE_NAME ==="

# -------------------------------------------------------
# Step 1: Create type file in types/ (Layer 0)
# -------------------------------------------------------
echo "[Step 1/4] Creating type file in types/ (Layer 0)..."

TYPE_FILE="types/${SNAKE_NAME}.ts"
if [ -f "$TYPE_FILE" ]; then
    echo "ERROR: Type file already exists: $TYPE_FILE"
    exit 1
fi

# Build type fields from arguments
TYPE_FIELDS=""
for field_def in "$@"; do
    field_name=$(echo "$field_def" | cut -d: -f1)
    field_type=$(echo "$field_def" | cut -d: -f2)
    case "$field_type" in
        uuid)      ts_type="string" ;;
        string)    ts_type="string" ;;
        int|integer) ts_type="number" ;;
        float)     ts_type="number" ;;
        bool|boolean) ts_type="boolean" ;;
        timestamp|datetime) ts_type="Date" ;;
        *)         ts_type="unknown /* $field_type */" ;;
    esac
    TYPE_FIELDS="${TYPE_FIELDS}  ${field_name}: ${ts_type};
"
done

mkdir -p types
cat > "$TYPE_FILE" << EOF
export interface ${MODEL_NAME} {
${TYPE_FIELDS}}
EOF
echo "  Created: $TYPE_FILE"

# -------------------------------------------------------
# Step 2: Create model file in models/ (Layer 1)
# -------------------------------------------------------
echo "[Step 2/4] Creating model file in models/ (Layer 1)..."

MODEL_FILE="models/${SNAKE_NAME}.ts"
if [ -f "$MODEL_FILE" ]; then
    echo "ERROR: Model file already exists: $MODEL_FILE"
    exit 1
fi

mkdir -p models
cat > "$MODEL_FILE" << EOF
import type { ${MODEL_NAME} } from '../types/${SNAKE_NAME}';

export const ${LOWER_NAME}Model = {
  tableName: '${LOWER_NAME}s',

  create(data: Omit<${MODEL_NAME}, 'id' | 'created_at'>): ${MODEL_NAME} {
    return {
      id: crypto.randomUUID(),
      created_at: new Date(),
      ...data,
    } as ${MODEL_NAME};
  },

  validate(data: Partial<${MODEL_NAME}>): data is ${MODEL_NAME} {
    return !!(data.id && data.name && data.email && data.created_at);
  },
};
EOF
echo "  Created: $MODEL_FILE"

# -------------------------------------------------------
# Step 3: Register in model registry
# -------------------------------------------------------
echo "[Step 3/4] Registering in model registry..."

REGISTRY_FILE="models/registry.ts"
if [ ! -f "$REGISTRY_FILE" ]; then
    mkdir -p models
    cat > "$REGISTRY_FILE" << 'REGISTRY_EOF'
// Model Registry — auto-managed by add-database-model.sh
// Each model is imported and re-exported for centralized access

REGISTRY_EOF
fi

# Check if already registered
if grep -q "${LOWER_NAME}Model" "$REGISTRY_FILE" 2>/dev/null; then
    echo "  WARNING: ${MODEL_NAME} already registered in $REGISTRY_FILE"
else
    echo "import { ${LOWER_NAME}Model } from './${SNAKE_NAME}';" >> "$REGISTRY_FILE"
    echo "export { ${LOWER_NAME}Model };" >> "$REGISTRY_FILE"
    echo "  Registered: ${LOWER_NAME}Model in $REGISTRY_FILE"
fi

# -------------------------------------------------------
# Step 4: Write unit test
# -------------------------------------------------------
echo "[Step 4/4] Writing unit test..."

TEST_FILE="tests/models/${SNAKE_NAME}.test.ts"
if [ -f "$TEST_FILE" ]; then
    echo "ERROR: Test file already exists: $TEST_FILE"
    exit 1
fi

mkdir -p tests/models
cat > "$TEST_FILE" << EOF
import { describe, it, expect } from 'vitest';
import { ${LOWER_NAME}Model } from '../../models/${SNAKE_NAME}';
import type { ${MODEL_NAME} } from '../../types/${SNAKE_NAME}';

describe('${MODEL_NAME} Model', () => {
  it('should create a ${MODEL_NAME} with generated id and created_at', () => {
    const ${LOWER_NAME} = ${LOWER_NAME}Model.create({
      name: 'Test User',
      email: 'test@example.com',
    });

    expect(${LOWER_NAME}.id).toBeDefined();
    expect(${LOWER_NAME}.name).toBe('Test User');
    expect(${LOWER_NAME}.email).toBe('test@example.com');
    expect(${LOWER_NAME}.created_at).toBeInstanceOf(Date);
  });

  it('should validate a complete ${MODEL_NAME} object', () => {
    const ${LOWER_NAME} = ${LOWER_NAME}Model.create({
      name: 'Test User',
      email: 'test@example.com',
    });

    expect(${LOWER_NAME}Model.validate(${LOWER_NAME})).toBe(true);
  });

  it('should reject an incomplete ${MODEL_NAME} object', () => {
    expect(${LOWER_NAME}Model.validate({})).toBe(false);
    expect(${LOWER_NAME}Model.validate({ name: 'only name' } as any)).toBe(false);
  });
});
EOF
echo "  Created: $TEST_FILE"

# -------------------------------------------------------
# Validate
# -------------------------------------------------------
echo ""
echo "=== Running validation pipeline ==="

# Check if validate.py exists
if [ -f "scripts/validate.py" ]; then
    python3 scripts/validate.py
else
    echo "WARNING: scripts/validate.py not found. Running basic checks:"
    echo "  [1/2] Checking type file..."
    test -f "$TYPE_FILE" && echo "  PASS: $TYPE_FILE exists"
    echo "  [2/2] Checking model file..."
    test -f "$MODEL_FILE" && echo "  PASS: $MODEL_FILE exists"
fi

echo ""
echo "=== Done: ${MODEL_NAME} model added successfully ==="
echo "Files created:"
echo "  - $TYPE_FILE"
echo "  - $MODEL_FILE"
echo "  - $TEST_FILE"
echo "  - Updated: $REGISTRY_FILE"
```

---

## Question 4: What updates to INDEX.md and procedural memory happen?

### INDEX.md Update

**Before** (current state):

```markdown
## Procedural (Successful Patterns)
- [add-database-model](procedural/add-database-model.md) — 4-step flow, 3/3 success, last: 2026-04-18 ← READY TO COMPILE
```

**After** (post-completion, post-compilation):

```markdown
## Procedural (Successful Patterns)
- [add-database-model](procedural/add-database-model.md) — 4-step flow, 4/4 success, last: 2026-04-19, compiled → scripts/add-database-model.sh
```

Changes:
- Success count updated from `3/3` to `4/4`
- Last validated date updated from `2026-04-18` to `2026-04-19`
- `← READY TO COMPILE` marker **replaced** with `compiled → scripts/add-database-model.sh`
- The entry now points to the compiled script as the primary execution path

### Procedural Memory Update

**Before** (current state at `harness/memory/procedural/add-database-model.md`):

```markdown
# Procedure: add-database-model

## When to Use
Adding any new database model to the project

## Steps
1. Create type file in types/ (Layer 0)
2. Create model file in models/ (Layer 1)
3. Register in model registry
4. Write unit test

## Success Rate
3/3 successful executions

## Last Validated
2026-04-18
```

**After** (post-completion):

```markdown
# Procedure: add-database-model

## When to Use
Adding any new database model to the project

## Steps
1. Create type file in types/ (Layer 0)
2. Create model file in models/ (Layer 1)
3. Register in model registry
4. Write unit test

## Success Rate
4/4 successful executions

## Last Validated
2026-04-19

## Compiled
This procedure has been compiled to a deterministic script: scripts/add-database-model.sh
Subsequent executions should use the script directly. Fall back to agent execution only if the script fails.
```

Changes:
- Success Rate updated from `3/3` to `4/4`
- Last Validated updated from `2026-04-18` to `2026-04-19`
- New `## Compiled` section added, documenting the script location and fallback behavior

---

## Question 5: On the NEXT execution of this same task type, what changes in the executor's behavior?

The next time a user asks "Add a new database model X with fields ...", the executor's behavior changes significantly at two specific steps:

### Change at Step 2 (Load Context)

Previously, the executor found the procedure, noted it was `← READY TO COMPILE`, and used the steps as a *blueprint* to manually plan and delegate.

Now, the executor finds:

```
compiled → scripts/add-database-model.sh
```

This changes the loading behavior. Instead of merely reading the procedure for guidance, the executor recognizes that a **deterministic compiled script exists** and can be run directly.

### Change at Step 5 (Execute)

**Previous behavior (this execution):**

The executor treated this as a Medium-complexity task and delegated to a sub-agent:

```python
Agent(
    description="Execute: add-user-model",
    model="sonnet",
    prompt="""Add User database model...
    Read: docs/ARCHITECTURE.md
    Read: docs/DEVELOPMENT.md
    Execute the assigned steps
    Validate after each major step
    Report back with diff + validation results"""
)
```

**New behavior (next execution):**

The executor checks for compiled scripts **first**, per the trajectory compilation design:

```
Subsequent executions check for compiled scripts first.
→ Script exists? Run it directly.
→ Script fails? Fall back to agent execution.
```

The execution becomes:

```bash
# Direct script execution instead of agent delegation
./scripts/add-database-model.sh Product id:uuid name:string price:float created_at:timestamp
```

Then run validation:

```bash
python3 scripts/validate.py
```

**No sub-agent delegation is needed.** The coordinator runs the script directly, validates, and completes.

### What stays the same

- Step 1 (Detect): Unchanged — still checks for AGENTS.md
- Step 3 (Complexity Analysis): Still classifies as Medium, but execution path differs
- Step 4 (Plan & Approve): May be **skippable** since the compiled script IS the plan — the executor may present a simpler confirmation ("Run compiled script add-database-model.sh with args X?") instead of a full execution plan
- Step 6 (Validate): Still runs the full validation pipeline after script execution
- Step 7 (Cross-Review): May be skipped for compiled script executions since the pattern has been validated 4+ times already (the compilation itself is evidence of stable correctness)
- Step 8 (Complete): Still commits and writes trace, but no compilation step needed (already compiled)

### Fallback behavior

If `./scripts/add-database-model.sh` fails (exit code != 0), the executor falls back to the original agent-delegation path:

1. Log the script failure to `harness/trace/failures/`
2. Fall back to sub-agent execution using the procedural memory steps
3. After successful fallback, review whether the script needs updating

This is the core value of trajectory compilation: a proven 4-step procedure that required agent delegation becomes a 1-command script execution, reducing context usage, time, and error surface area.
