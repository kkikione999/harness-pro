# Phase 1: Process Flow Conflict Analysis

## Executive Summary

Superpowers and Harness Engineering have fundamentally different design philosophies that create significant process conflicts. Superpowers follows a **multi-stage design-first workflow** (brainstorming → writing-plans → subagent-driven development → finishing) with extensive human collaboration points. Harness follows a **streamlined autonomy-first workflow** (decompose-requirement → plan-feature → execute-plan) designed for minimal human intervention. The primary conflicts are: (1) Different entry points and triggering mechanisms, (2) Redundant user collaboration checkpoints, (3) Incompatible artifact formats and locations, (4) Conflicting quality assurance philosophies, and (5) Different feature granularity models that don't align.

## Side-by-Side Process Mapping

| Stage | Superpowers Approach | Harness Approach | Key Differences |
|--------|-------------------|------------------|------------------|
| **Entry Point** | `using-superpowers` gatekeeper checks for ANY skill applicability (1% threshold) | `decompose-requirement` triggered only for feature requests | Superpowers is proactive/always-on; Harness is reactive/task-specific |
| **Requirements Analysis** | `brainstorming` (9-step checklist) with extensive user clarification loop | `decompose-requirement` (4-step focused) with targeted clarification | Superpowers explores full context upfront; Harness reads progressively |
| **Design Documentation** | `spec.md` in `docs/superpowers/specs/` | `index.md` in `features/{id}/` | Different locations and structures |
| **Planning** | `writing-plans` creates task-level plan in `docs/superpowers/plans/` | `plan-feature` creates file+function-level plan in `features/{id}/plan.md` | Different granularity (task vs file+function) and locations |
| **User Participation** | Multiple explicit checkpoints: brainstorming confirmation, plan review, execution choice | Only at intent→feature boundary (subsequent stages autonomous) | Superpowers: continuous checkpoints; Harness: single handoff |
| **Execution** | Choice: `subagent-driven-development` OR `executing-plans` | `execute-plan` (TDD-based) | Superpowers: parallel subagents with reviews; Harness: autonomous TDD |
| **Quality Assurance** | Per-task 2-stage review (spec compliance → code quality) + final code review | Per-milestone lint + Golden Principles enforcement | Different timing and philosophy |
| **Completion** | `finishing-a-development-branch` with 4 integration options | Delivered code + tests (no separate completion step) | Superpowers: explicit integration choice; Harness: implicit delivery |

## Identified Conflicts

### Conflict 1: Entry Point Chaos

**Superpowers approach**: `using-superpowers` acts as a global gatekeeper that checks for skill applicability on EVERY message with a 1% threshold. This means brainstorming can trigger unexpectedly even for simple clarifying questions.

**Harness approach**: `decompose-requirement` only triggers for explicit feature requests ("add functionality", "fix bug", requirement descriptions). Simple clarifications don't trigger the decomposition workflow.

**Severity**: HIGH

**Root cause**: Superpowers is designed as a universal entry guard that proactively suggests skills. Harness decompose-requirement is a focused decomposition skill. When both are present, brainstorming's "1% applies" rule can hijack conversations that should just be clarifying.

**Recommended resolution**:
1. **Modify `using-superpowers` to check for `decompose-requirement` first** - Before suggesting brainstorming, check if the message is a feature request that requires decomposition. If yes, invoke decompose-requirement instead.
2. **Clarify intent boundaries** - decompose-requirement should handle "clarify my requirement" type interactions, while brainstorming handles "explore design options" type interactions.
3. **Add explicit trigger phrases** - decompose-requirement description should specify what constitutes a "feature request" vs "exploratory question."

### Conflict 2: Redundant User Checkpoints

**Superpowers approach**: Multiple explicit user participation points:
- brainstorming: design confirmation (multiple rounds)
- writing-plans: scope check (if multiple subsystems, suggest splitting)
- writing-plans: execution choice (subagent-driven vs inline)

**Harness approach**: Single handoff point - user confirms feature definition, then AI is autonomous through plan → execute → test.

**Severity**: MEDIUM

**Root cause**: Superpowers was designed for manual development with AI assistance, where each stage requires human approval. Harness is designed for AI autonomy where humans only steer at the feature boundary.

**Recommended resolution**:
1. **Make Superpowers checkpoints optional/conditional** - brainstorming confirmation becomes required only for NEW features (not modifications to existing features). For well-understood feature spaces, skip to planning directly.
2. **Preserve Harness's single-handoff principle** - Keep the philosophy that after feature definition, the AI owns the process. User only intervenes if AI detects it needs clarification.
3. **Conditional execution choice** - writing-plans' "which approach?" choice should default to subagent-driven-development for most cases, with inline only as fallback or for very simple plans.

### Conflict 3: Artifact Format and Location Incompatibility

**Superpowers approach**:
- `spec.md`: Full design specification in `docs/superpowers/specs/`
- `plan.md`: Task-level plan in `docs/superpowers/plans/` with checkboxes
- No persistent feature registry

**Harness approach**:
- `index.md`: Feature definition (YAML) in `features/{id}/`
- `plan.md`: File+function-level plan in `features/{id}/plan.md` with Change/Order structure
- Persistent `features/` directory as feature registry

**Severity**: HIGH

**Root cause**: Superpowers predates the Harness feature-centric model. It uses documentation directories for specs/plans. Harness uses a `features/` directory that serves as a living registry of what exists and what each feature's scope is.

**Recommended resolution**:
1. **Unify artifact locations** - Migrate Superpowers specs/plans into Harness `features/{id}/` structure:
   - `docs/superpowers/specs/{name}.md` → `features/{id}/index.md` (convert to YAML structure)
   - `docs/superpowers/plans/{name}.md` → `features/{id}/plan.md` (convert to Change/Order structure)
2. **Maintain `features/` as single source of truth** - Both systems should read/write from `features/` directory. Superpowers skills should detect this structure and adapt.
3. **Adapt plan format conversion** - writing-plans should produce Harness-compatible plan.md format (Context/Changes/Order/Validation/Risks) instead of task-checklist format.

### Conflict 4: Quality Assurance Timing Conflicts

**Superpowers approach**: Per-task quality gates:
- After each task: spec compliance review → code quality review
- Final code review for entire implementation
- Reviews happen DURING execution, as checkpoints

**Harness approach**: Per-milestone quality gates:
- After each milestone (not each task): lint against Golden Principles
- Pre-commit: P0 rules block merge
- Quality shifts left (lint during planning, not after)

**Severity**: MEDIUM

**Root cause**: Different philosophies on when quality checks should happen. Superpowers believes in catching issues immediately during implementation. Harness believes in preventing issues through pre-planning lint and blocking them at merge time.

**Recommended resolution**:
1. **Adopt hybrid approach** - Use per-task reviews for NEW features (where patterns are still forming) and per-milestone reviews for ESTABLISHED feature spaces.
2. **Unify lint rules** - Superpowers' code quality reviewers should use the same Golden Principles that Harness defines, checking against `.harness/golden-principles/`.
3. **Preserve P0 blocking** - Keep Harness's "P0 rules block merge" philosophy. Superpowers reviews should be advisory except for P0 violations.

### Conflict 5: Feature Granularity Mismatch

**Superpowers approach**: brainstorming produces `spec.md` which writing-plans breaks into task-level steps. A spec could map to one feature or multiple. There's no atomic feature concept - specs can be large.

**Harness approach**: decompose-requirement produces atomic features with explicit boundaries. Each feature must be independently verifiable with clear `out_of_bound`.

**Severity**: HIGH

**Root cause**: Superpowers doesn't have the concept of "atomic feature" as a unit of work. Its spec granularity is flexible and determined by user needs. Harness enforces atomicity at the requirement decomposition stage.

**Recommended resolution**:
1. **Adopt Harness atomic feature model** - Make Superpowers specs align with atomic feature boundaries. One spec = one atomic feature (or map one spec to multiple atomic features if needed).
2. **Add granularity check in writing-plans** - Before writing task plan, check if it corresponds to a single atomic feature. If scope seems too large, suggest breaking into multiple features first.
3. **Preserve feature dependencies** - Use Harness's `dependencies` field to track atomic feature DAG, replacing Superpowers' implicit dependency management.

### Conflict 6: Documentation Philosophy Mismatch

**Superpowers approach**: writing-plans assumes "engineer has zero context" and documents everything exhaustively. Plans include complete file paths, exact commands, expected outputs.

**Harness approach**: plan-feature produces "lightweight pointers" (code_scope_hint) that give AI entry points. AI is trusted to explore and understand details. plan.md is file+function level, not line-level.

**Severity**: LOW

**Root cause**: Superpowers was designed for human engineers who need explicit instructions. Harness assumes AI is smart enough to explore from lightweight guidance.

**Recommended resolution**:
1. **Keep Harness's lightweight approach** - Trust AI to explore from code_scope_hint rather than documenting everything exhaustively.
2. **Adaptive detail level** - Writing-plans can provide more detail for NEW/COMPLEX features while plan-feature can be lighter for ESTABLISHED/SIMPLE features.
3. **Unified plan structure** - Use Harness plan.md structure but allow Superpowers-style task checklists as "detailed Change entries" for complex changes.

## Feature Granularity Analysis

**Superpowers Model**:
- spec.md can be any size - determined by user request scope
- writing-plans breaks spec into task-level steps (2-5 minutes each)
- No concept of atomic features as boundary units
- Features emerge from specs, not defined upfront

**Harness Model**:
- decompose-requirement produces atomic features with explicit boundaries
- Each atomic feature has: id, name, problem, acceptance_criteria, dependencies, code_scope_hint, out_of_bound
- Features are independently verifiable units
- Features are defined BEFORE planning, not after spec

**Key Gaps**:
1. **No atomic feature registry in Superpowers** - Without `features/` directory, there's no persistent view of what exists and what each feature's scope is.
2. **Inconsistent feature boundaries** - Superpowers' spec granularity is variable, leading to potential scope creep.
3. **No dependency tracking** - Superpowers doesn't have explicit feature dependencies, making it harder to understand impact of changes.

**Alignment Strategy**:
- **Adopt Harness's atomic feature model** as the canonical way to define feature boundaries
- **Use decompose-requirement** to ensure specs map to atomic features before planning
- **Preserve Superpowers' task breakdown** within atomic features - writing-plans can still produce detailed tasks, but bounded by feature scope

## User Participation Map

### Superpowers User Touchpoints
1. **brainstorming stage**:
   - Clarifying questions (multiple rounds, one at a time)
   - Design section confirmation (presented segment-by-segment)
   - Design doc review (after spec written)

2. **writing-plans stage**:
   - Scope check (confirm single subsystem)
   - Execution choice (subagent-driven vs inline)

3. **subagent-driven-development**:
   - Implicit: Questions from implementer subagents (answered before proceeding)

4. **finishing-a-development-branch**:
   - Integration choice (4 options: merge/PR/keep/discard)
   - Branch deletion confirmation

**Total**: 5-7 explicit touchpoints per feature, plus intermittent questions during execution.

### Harness User Touchpoints
1. **decompose-requirement stage**:
   - Clarification loop (AI exposes understanding, user confirms/corrects)
   - Acceptance criteria confirmation (AI proposes, user validates)

2. **plan-feature stage**: None (fully autonomous)

3. **execute-plan stage**: None (fully autonomous unless blocked, which requires escalation)

**Total**: 1-3 touchpoints per feature (clarification + acceptance criteria + potential escalation).

**Redundancy**: Superpowers has 2-4x more user touchpoints than Harness for the same work.

## Key Recommendations

1. **Merge entry points** - `using-superpowers` should check for `decompose-requirement` first before suggesting brainstorming. This prevents unexpected brainstorming triggers for simple clarifying questions.

2. **Unify artifact structure** - Adopt Harness's `features/{id}/` directory as single source of truth for feature definitions and plans. Migrate Superpowers specs/plans to this structure.

3. **Preserve single-handoff philosophy** - Keep Harness's principle that after feature definition, AI is autonomous. Make Superpowers' intermediate checkpoints (plan review, execution choice) optional or automatic for well-understood contexts.

4. **Adopt atomic feature model** - Use Harness's explicit feature boundaries (out_of_bound, acceptance_criteria) as the granularity unit. Map Superpowers specs to atomic features before planning.

5. **Unify quality gates** - Use Golden Principles from Harness as the quality standard for both systems. Align per-task reviews (Superpowers) with per-milestone reviews (Harness).

6. **Simplify documentation** - Trust AI to explore from lightweight code_scope_hint rather than documenting exhaustively. Reserve detailed plans for genuinely complex/new features.

7. **Conditional skill invocation** - Make brainstorming and writing-plans optional/conditional based on context maturity. For established feature spaces, skip directly to plan-feature/execute-plan.

8. **Preserve TDD discipline** - Both systems value TDD. Ensure execution follows RED-GREEN-REFACTOR regardless of which path is chosen.

9. **Adaptive granularity** - writing-plans can produce detailed task breakdowns for NEW/COMPLEX features while plan-feature produces lighter plans for ESTABLISHED/SIMPLE features. Both use Harness plan.md structure.

10. **Track dependencies explicitly** - Use Harness's `dependencies` field in feature definitions. This provides visibility into feature DAG and impact analysis.
