# Phase 3: Simplified Unified Design Proposal

## Executive Summary

Design a minimal skill architecture (6 skills) that enables AI agents to autonomously complete software development tasks. The unified system merges Harness Engineering's atomic feature concept with Superpowers' execution discipline while eliminating redundant skills and complex decision trees. AI is trusted to figure out details; process design keeps it simple.

## Current Skill Inventory

| Skill | Classification | Rationale |
|-------|---------------|-----------|
| **using-superpowers** | MERGE | Gatekeeper function belongs in harness routing, not as separate skill |
| **brainstorming** | MERGE | Concept merges into decompose-requirement for feature discovery |
| **decompose-requirement** | KEEP (renamed) | CoreHarness concept - converts user intent to atomic feature |
| **writing-plans** | SIMPLIFY | Becomes lightweight plan generation, no spec-document-reviewer subagent |
| **plan-feature** | MERGE | Identical to writing-plans, remove duplicate |
| **subagent-driven-development** | REMOVE | Too complex; trust AI to execute with TDD discipline directly |
| **execute-plan** | MERGE | Becomes inline execution mode when subagents unavailable |
| **executing-plans** | REMOVE | Duplicate of execute-plan, confusing naming |
| **finishing-a-development-branch** | SIMPLIFY | Keep merge logic, remove worktree complexity |
| **test-driven-development** | KEEP | Essential TDD discipline for all code changes |
| **systematic-debugging** | KEEP | Critical for bug fixing without random changes |
| **verification-before-completion** | KEEP | Core quality gate, prevents false claims |
| **requesting-code-review** | REMOVE | Human review handled by finishing skill, automated quality via lint |
| **receiving-code-review** | REMOVE | No subagent-driven workflow means no manual review handling |
| **using-git-worktrees** | REMOVE | Over-engineering; trust AI to manage branches naturally |
| **dispatching-parallel-agents** | REMOVE | Simple parallel execution is built-in, doesn't need separate skill |
| **writing-skills** | REMOVE | Meta-skill for creating skills, out of scope |

## Proposed Unified Skill Architecture

### Skill 1: decompose-requirement
- **Purpose**: Convert user requests into atomic feature definitions with clear boundaries
- **Replaces**: brainstorming, using-superpowers (gatekeeping)
- **Triggers when**: User describes any new functionality, bug fix, or change request
- **Key behaviors**:
  - Explore existing features and codebase structure
  - Ask clarifying questions one at a time
  - Propose atomic feature with acceptance criteria
  - Define out_of_bound and dependencies
  - User confirms before proceeding
- **Quality mechanism**: Checklist-based validation ensures feature is atomic and verifiable

### Skill 2: create-plan
- **Purpose**: Generate lightweight execution plan from atomic feature definition
- **Replaces**: writing-plans, plan-feature
- **Triggers when**: Atomic feature approved and ready for implementation
- **Key behaviors**:
  - Read feature definition and explore codebase
  - Identify files to create/modify
  - Generate bite-sized tasks (2-5 minutes each)
  - No subagent review loops - trust AI judgment
  - Save plan to `.harness/file-stack/plan.md`
- **Quality mechanism**: Self-validation against Harness file-stack structure

### Skill 3: execute-task
- **Purpose**: Execute implementation plan using TDD discipline
- **Replaces**: subagent-driven-development, execute-plan, executing-plans, dispatching-parallel-agents
- **Triggers when**: Plan exists and ready to implement
- **Key behaviors**:
  - Follow plan step-by-step with TDD (RED → GREEN → REFACTOR)
  - Use test-driven-development skill for each task
  - Handle blocking by asking questions, not guessing
  - Commit frequently after each passing test
  - Update plan progress live
- **Quality mechanism**: TDD ensures every change has test proof

### Skill 4: test-driven-development
- **Purpose**: Enforce RED → GREEN → REFACTOR cycle for all code changes
- **Replaces**: (existing, unchanged)
- **Triggers when**: About to write or modify any production code
- **Key behaviors**:
  - Write failing test first
  - Verify it fails correctly
  - Write minimal implementation
  - Verify it passes
  - Refactor while green
  - Repeat for next behavior
- **Quality mechanism**: Iron law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"

### Skill 5: systematic-debugging
- **Purpose**: Find root cause before proposing fixes through scientific method
- **Replaces**: (existing, unchanged)
- **Triggers when**: Encountering bug, test failure, or unexpected behavior
- **Key behaviors**:
  - Phase 1: Root cause investigation (read errors, reproduce, check changes)
  - Phase 2: Pattern analysis (find working examples, compare)
  - Phase 3: Hypothesis and testing (single hypothesis, minimal test)
  - Phase 4: Implementation (test first, fix root cause, verify)
- **Quality mechanism**: Iron law: "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"

### Skill 6: complete-work
- **Purpose**: Verify completion and handle integration options
- **Replaces**: finishing-a-development-branch, verification-before-completion
- **Triggers when**: All tasks complete and tests passing
- **Key behaviors**:
  - Run fresh verification (tests, lint, build)
  - Present 4 options: merge locally, push PR, keep branch, discard
  - Execute chosen option
  - Cleanup resources appropriately
- **Quality mechanism**: Iron law: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"

## Unified Workflow

```
User Request
    ↓
[decompose-requirement]
    ↓ Explore features, clarify, define atomic feature
    ↓ User confirms feature
    ↓
[create-plan]
    ↓ Generate lightweight plan, map files, define tasks
    ↓
[execute-task] ← [systematic-debugging] if blocked/bug
    ↓ Follow plan with TDD discipline
    ↓ Tasks complete, tests pass
    ↓
[complete-work]
    ↓ Verify, present options, execute, cleanup
    ↓
Done
```

**Single path, no decision trees.** Skills chain sequentially. Debugging skill can interrupt at any point when issues arise.

## Quality Simplification

Three mechanisms cover all quality needs:

1. **TDD Iron Law** (test-driven-development): Every change has test proof before implementation. Prevents unverified code and regressions.

2. **Verification Gate** (complete-work): Fresh evidence before any success claim. Prevents false positives and "it should work" assumptions.

3. **Scientific Debugging** (systematic-debugging): Root cause investigation before fixes. Prevents symptom patches and new bugs.

**No subagent reviews, no spec-document-reviewer, no code-reviewer.** Trust AI to produce quality work. Automated linters catch violations; human reviews handle integration decisions.

## File Stack Mapping

Harness `.harness/file-stack/` artifacts map directly:

| Harness Artifact | Unified Skill Output | Location |
|----------------|---------------------|----------|
| **prompt.md** | User's original request + decomposed atomic feature | `.harness/file-stack/prompt.md` |
| **plan.md** | Lightweight execution plan with tasks | `.harness/file-stack/plan.md` |
| **documentation.md** | Live progress, decisions, surprises (updated during execution) | `.harness/file-stack/documentation.md` |

**Simplified mapping**: No spec.md separate document. plan.md is lightweight. documentation.md is the single living artifact updated during execute-task.

## Migration Path

From current Superpowers to unified system:

1. **Phase 1**: Implement decompose-requirement skill, replacing brainstorming gatekeeper
2. **Phase 2**: Simplify writing-plans into create-plan (no subagent reviews)
3. **Phase 3**: Remove subagent-driven-development, trust AI with TDD discipline
4. **Phase 4**: Merge execute-plan/executing-plans into execute-task
5. **Phase 5**: Simplify finishing-a-development-branch into complete-work
6. **Phase 6**: Deprecate redundant skills (requesting/receiving-code-review, using-git-worktrees, dispatching-parallel-agents)

**Backward compatibility**: Existing Superpowers skills can coexist during migration. New skills take precedence via using-superpowers routing.

## What We're Removing and Why

| Removed Element | Justification |
|----------------|---------------|
| **Spec-document-reviewer subagent** | Too complex; AI generates correct plans when feature is atomic. Trust AI judgment. |
| **Spec compliance review loop** | Adds iterations without value. Decomposed feature already has clear requirements. |
| **Implementer subagent** | Unnecessary layer. AI can execute with TDD discipline directly. |
| **Code-quality-reviewer subagent** | Automated linters catch violations. Code review becomes human integration decision, not AI-to-AI loop. |
| **Two-stage review (spec then quality)** | Redundant. TDD + verification-before-completion covers quality. |
| **using-git-worktrees complexity** | Over-engineering. AI can create branches naturally. Worktree cleanup handled by complete-work. |
| **dispatching-parallel-agents** | Parallel execution is built-in to AI systems. Separate skill adds confusion. |
| **writing-plans self-review** | Self-paralysis. Trust AI to generate plan, verify through execution. |
| **Multiple execution paths** | Confusing choice between subagent-driven and executing-plans. Single path with fallback. |
| **requesting-code-review skill** | Human review happens at PR time, not during development. Automates what doesn't need automating. |
| **receiving-code-review skill** | No human-in-the-middle workflow. AI executes; human reviews at integration boundary. |

**Core philosophy**: AI is smart enough. Process design stays simple. Quality through mechanical checks (TDD, verification gates), not complex review processes.
