# Skeleton Bootstrap

This file is loaded only when decompose-requirement detects that the project skeleton is missing (no CLAUDE.md in project root). It provides the bootstrap logic and templates.

## When This Runs

- User enters decompose-requirement for the first time in a project
- CLAUDE.md does not exist in the project root
- This runs ONCE per project; subsequent entries skip directly to Two Paths

## Two Scenarios

### Scenario A: New Project

The codebase is empty or near-empty (no src/, no existing application code).

**Action**: Create `CLAUDE.md` with the template below, filling in what you know from the user's context.

### Scenario B: Existing Project

The codebase has substantial existing code (src/, lib/, app/, etc.).

**Action**: Scan the codebase first, then generate `CLAUDE.md` reflecting the project's actual state.

**Scanning process**:
1. Directory structure → infer architecture layers
2. Code patterns → infer conventions (naming, style, error handling)
3. Dependency graph → infer module boundaries
4. Existing docs/tests → infer standards

**Principle**: Document what IS, not what should be. The skeleton reflects reality.

## CLAUDE.md Template

```markdown
# {Project Name}

{One-line description of what this project does}

## Tech Stack

- Language: {language + version}
- Framework: {framework}
- Build tool: {build tool}
- Test framework: {test framework}
- Package manager: {package manager}

## Project Structure

{Brief description of directory layout. For existing projects, describe what actually exists.}

## Development

```bash
# Install
{install command}

# Test
{test command}

# Build
{build command}

# Run
{run command}
```

## Architecture

{For existing projects: describe the actual architecture layers and dependency direction.}
{For new projects: leave as placeholder, will be filled during first create-plan.}

## Conventions

{For existing projects: patterns discovered from scanning.}
{For new projects: basic constraints agreed with user.}

- Naming: {convention}
- Error handling: {convention}
- Testing: {coverage requirement}

## Harness Engineering

This project uses Harness Engineering workflow:
- Feature definitions live in `features/{feature-id}/index.md`
- Execution plans live in `features/{feature-id}/plan.md`
- Working state lives in `.harness/file-stack/`
- Directories are created when first needed (no empty shells)
```

## After Bootstrap

Once CLAUDE.md is created:

1. Create `.harness/` directory structure if it doesn't exist:
   ```
   .harness/
   ├── controllability/
   ├── observability/
   └── file-stack/
   ```

2. Do NOT create these yet — they'll be created when first needed:
   - `features/` → created by decompose-requirement when first feature is defined
   - `docs/` → created when first design doc is needed
   - `ARCHITECTURE.md` → created when first architectural decision is made

3. Proceed to normal decompose-requirement flow (Two Paths)
