# Audit Logic

How to assess a codebase and generate a 0-100 score.

## Scoring Dimensions

### 1. Documentation Coverage (25%)

Check for existence and quality of:

| File | Weight | Check |
|------|--------|-------|
| `AGENTS.md` | 8% | Exists, ≤100 lines |
| `docs/ARCHITECTURE.md` | 9% | Exists, has layer diagram |
| `docs/DEVELOPMENT.md` | 8% | Exists, has build/test commands |

**Scoring:**
- Missing file = 0
- Exists but poor = 0.5
- Good quality = 1.0

### 2. Lint Architecture Coverage (35%)

| File | Weight | Check |
|------|--------|-------|
| `scripts/lint-deps` | 20% | Exists, covers all packages, educational errors |
| `scripts/lint-quality` | 15% | Exists, checks file length, logging, hardcoded strings |

**Scoring:**
- Missing = 0
- Exists but basic = 0.5
- Comprehensive = 1.0

### 3. Validation Pipeline (25%)

| Component | Weight | Check |
|-----------|--------|-------|
| `scripts/validate.py` | 10% | Exists, runs build → lint → test |
| Build step defined | 5% | Can build project |
| Test step defined | 5% | Can run tests |
| Verify step exists | 5% | E2E verification: `scripts/verify/run.py` with real content OR `docs/E2E.md` with tool guide |

### 4. Harness Structure (15%)

| Directory | Weight | Check |
|-----------|--------|-------|
| `harness/` | 3% | Exists |
| `harness/tasks/` | 4% | Exists |
| `harness/trace/` | 4% | Exists |
| `harness/memory/` | 4% | Exists |

## Audit Process

### Step 1: Check File System

```bash
# Check what exists
ls -la AGENTS.md docs/ scripts/ harness/

# Count lines of AGENTS.md
wc -l AGENTS.md  # Must be ≤100
```

### Step 2: Detect Language

```bash
if [ -f "go.mod" ]; then
    LANGUAGE="go"
elif [ -f "Package.swift" ]; then
    LANGUAGE="swift"
elif [ -f "package.json" ]; then
    LANGUAGE="typescript"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    LANGUAGE="python"
else
    LANGUAGE="unknown"
fi
```

### Step 3: Scan for Layer Mapping

For each source file, extract imports and build dependency graph:

```bash
# Example for Swift
grep -h "^import " Sources/**/*.swift | sort | uniq -c | sort -rn

# Example for Go
grep -h "\"[^\"]*\"" **/*.go | sort | uniq -c | sort -rn

# Example for TypeScript
grep -h "^import \|from '" **/*.ts | sort | uniq -c | sort -rn
```

### Step 4: Calculate Score

```python
def calculate_score(doc_score, lint_score, validation_score, harness_score):
    return (
        doc_score * 0.25 +
        lint_score * 0.35 +
        validation_score * 0.25 +
        harness_score * 0.15
    )
```

## Output Format

After audit, output:

```markdown
# Harness Audit Report

## Overall Score: XX/100

| Dimension | Score | Status |
|-----------|-------|--------|
| Documentation | XX% | GOOD/NEEDS_WORK/MISSING |
| Lint Coverage | XX% | GOOD/NEEDS_WORK/MISSING |
| Validation | XX% | GOOD/NEEDS_WORK/MISSING |
| Harness | XX% | GOOD/NEEDS_WORK/MISSING |

## Actions Needed

1. [Priority] Create AGENTS.md
2. [Priority] Generate scripts/lint-deps
3. ...

## Layer Mapping (inferred)

```
Layer 0: types/
Layer 1: utils/
Layer 2: config/
Layer 3: services/
Layer 4: handlers/
```
```
