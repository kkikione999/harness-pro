# Phase 2: Quality System Gap Analysis

> Based on comparison between Superpowers quality mechanisms and Harness Engineering three-layer quality system
> Analysis Date: 2026-04-16
> Design Philosophy: "AI is smart enough, keep process design simple, don't over-design complexity"

---

## Executive Summary

Superpowers and Harness Engineering share the same quality goals but implement them differently. Superpowers relies on **agent-driven workflows with explicit skills** (TDD, code review, verification), while Harness relies on **mechanical enforcement and automated gates** (Golden Principles, P0 linters, GC Engine). Key findings: (1) Superpowers' TDD workflow maps perfectly to Harness's Evals implementation detail; (2) Harness's P0 linters can replace manual verification in Superpowers; (3) Both systems have overlapping code review mechanisms that need consolidation; (4) Significant over-engineering exists in Superpowers with redundant quality checks.

---

## Quality Mechanism Comparison Table

| Quality Aspect | Superpowers | Harness | Gap/Overlap |
|----------------|--------------|---------|---------------|
| **Code Quality** | test-driven-development skill, Code Quality Reviewer subagent | Golden Principles (P0 linters), GC Engine | Superpowers provides implementation detail; Harness provides mechanical enforcement |
| **Specification Review** | Spec Reviewer subagent | Plan agent reviews plan.md against spec | Overlap with different agents |
| **Code Review** | Code Quality Reviewer subagent + requesting/receiving-code-review skills | No explicit code review (relies on P0 linters) | Harness missing agent-to-agent review workflow |
| **Testing Strategy** | TDD (RED-GREEN-REFACTOR), verification-before-completion | Evals (regression tests + capability benchmarks), 80% coverage requirement | Superpowers TDD provides methodology; Harness provides coverage targets |
| **Pre-commit Validation** | verification-before-completion skill | P0 linters block merge, milestone-boundary lint checks | Harness has stronger mechanical enforcement |
| **Continuous Quality** | Code review before each task in subagent-driven-dev | GC Engine (weekly auto PRs for tech debt + drift) | Both address ongoing quality, Harness more automated |
| **Debugging Process** | systematic-debugging skill (4 phases: root cause → pattern → hypothesis → implementation) | No explicit debugging skill (relies on agents) | Superpowers provides structured debugging; Harness missing this |
| **Architecture Enforcement** | Not explicitly defined | Six-layer architecture with dependency direction linter | Harness has stronger architectural control |
| **Rule Hierarchy** | Progressive rules (Enforced/Advisory/Knowledge) | Golden Principles (P0/P1/P2), progressive-rules design | Compatible approaches, different terminology |
| **Evidence Requirements** | verification-before-completion: "Evidence before claims" | Linter provides mechanical proof, but no explicit evidence discipline | Superpowers has stronger evidence culture |

---

## Identified Gaps

### Gap 1: Agent-to-Agent Code Review Missing in Harness

**In Superpowers**: Code Quality Reviewer subagent dispatches for each task in subagent-driven-development workflow, reviewing code quality, architecture, testing, and requirements. Uses structured template with Strengths/Issues/Critical/Important/Minor categorization.

**In Harness**: No explicit agent-to-agent code review mechanism. Relies on P0 linters and GC Engine for quality, but lacks human-like peer review between agents for subjective quality aspects (architecture, maintainability, extensibility).

**Impact**: HIGH - Without agent-to-agent review, subjective quality issues (design patterns, maintainability) may not be caught until GC cycle or manual review.

**Recommended integration**: Adopt Superpowers' code-reviewer subagent workflow as the "peer review" layer in Harness. Integrate with P0 linters: linters catch mechanical violations, code-reviewer catches subjective quality issues. Place review at milestone boundaries.

### Gap 2: Structured Debugging Methodology Missing in Harness

**In Superpowers**: systematic-debugging skill provides 4-phase process (Root Cause Investigation → Pattern Analysis → Hypothesis & Testing → Implementation). Includes specific techniques (root-cause-tracing, defense-in-depth, condition-based-waiting). Iron law: "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST."

**In Harness**: No explicit debugging skill. Agents expected to debug independently without structured methodology.

**Impact**: MEDIUM - Debugging is core activity, but without structured approach, may lead to symptom-fixing (band-aid solutions) rather than root cause resolution.

**Recommended integration**: Adopt systematic-debugging as a Harness skill or integrate into Plan agent workflow. The 4-phase process complements TDD and prevents thrashing. Key is the iron law discipline.

### Gap 3: Evidence-First Culture Stronger in Superpowers

**In Superpowers**: verification-before-completion skill enforces "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE." Gate function requires IDENTIFY→RUN→READ→VERIFY→ONLY THEN claim. Prohibits "should," "probably," "seems to."

**In Harness**: Linters provide mechanical proof, but no explicit evidence discipline for agents. Agents may claim completion without running fresh verification commands.

**Impact**: MEDIUM - Harness lacks the cultural discipline of fresh verification evidence. Linters provide evidence but agents may not be disciplined about verification.

**Recommended integration**: Adopt verification-before-completion as a post-milestone gate. Agents must run verification commands and provide output before claiming task completion. This strengthens the "evidence culture" around mechanical linter evidence.

### Gap 4: TDD as Implementation Detail Missing in Harness Evals

**In Superpowers**: test-driven-development skill provides RED-GREEN-REFACTOR cycle as implementation methodology. Iron law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST." Includes detailed verification checkpoints (verify RED, verify GREEN, verify refactor).

**In Harness**: Evals defined as "regression tests + capability benchmarks" but no implementation methodology specified. 80% coverage requirement exists but no TDD process.

**Impact**: HIGH - Without TDD methodology, agents may write tests after code (violating "tests after achieve different purpose"). TDD provides discipline that tests-after lacks.

**Recommended integration**: Explicitly define TDD as the implementation detail for Evals. Evals verify TDD adherence: (1) test written before code, (2) test failed for expected reason, (3) minimal code to pass, (4) all tests pass. This transforms Evals from coverage metrics to process validation.

### Gap 5: Progressive-Rules vs Golden Principles Terminology Conflict

**In Superpowers**: progressive-rules design uses Enforced/Advisory/Knowledge classification with mechanical verification for Enforced rules.

**In Harness**: Golden Principles uses P0/P1/P2 classification. P0 = Linter verification and block merge. P1 = GC cycle fix. P2 = advisory.

**Impact**: LOW - Compatible concepts but different terminology creates cognitive load when bridging systems.

**Recommended integration**: Harmonize terminology. Map P0→Enforced, P1→Advisory, P2→Knowledge. Use progressive-rules design as the implementation framework for Golden Principles.

### Gap 6: Spec Reviewer Workflow Missing in Harness

**In Superpowers**: Spec Reviewer subagent verifies code matches spec (not missing, not extra) during subagent-driven-development. Returns "✅ Spec compliant / ❌ Issues found."

**In Harness**: Plan agent reviews plan.md against atomic feature, but no explicit "verify implementation matches spec" step in execution.

**Impact**: MEDIUM - Without spec verification during execution, scope creep (extra work not in spec) or missing requirements may not be caught until end of milestone.

**Recommended integration**: Add spec verification at task completion or milestone boundary. Verify: (1) All requirements implemented, (2) No extra work beyond scope, (3) No misunderstandings of requirements.

---

## Overlap Analysis

### Overlap 1: Code Review Mechanisms

**Superpowers**: Code Quality Reviewer subagent + requesting-code-review + receiving-code-review skills. Three-way: (1) implementer dispatches review, (2) code-reviewer evaluates, (3) receiving-code-review handles feedback.

**Harness**: P0 linters (mechanical) + GC Engine (periodic review). No agent-to-agent review.

**Analysis**: Both aim for quality but differ fundamentally. Superpowers = human-like peer review (subjective + objective). Harness = mechanical enforcement (objective only).

**Recommendation**: Combine. P0 linters catch mechanical violations fast. Code-reviewer catches subjective quality (architecture, patterns, maintainability). Place code-reviewer at milestone boundaries, linters at commit time.

### Overlap 2: Testing Quality Gates

**Superpowers**: TDD skill enforces test-first + verification checkpoints. verification-before-completion enforces fresh test run before claiming complete.

**Harness**: 80% coverage requirement + Evals (regression tests). Linters may include test validation.

**Analysis**: Both test but different enforcement. Superpowers = process discipline (write test first). Harness = outcome metric (80% coverage).

**Recommendation**: Adopt TDD process for implementation, use 80% coverage as Evals verification. Process (TDD) prevents coverage gaming (useless tests to hit 80%).

### Overlap 3: Milestone-Based Quality Checks

**Superpowers**: Code review after EACH task in subagent-driven-development. verification-before-completion before claiming any status.

**Harness**: Milestone-boundary lint checks (Worker agent completes milestone →强制跑 lint). Plan agent scans code_scope compliance (前馈).

**Analysis**: Both use boundaries but different granularity. Superpowers = per-task granularity. Harness = per-milestone granularity.

**Recommendation**: Keep Harness milestone boundary approach (more efficient than per-task). Add verification-before-completion at milestone completion.

### Overlap 4: Continuous Quality Monitoring

**Superpowers**: Code review before merge (manual trigger). Systematic debugging catches drift during development.

**Harness**: GC Engine (weekly auto PRs for tech debt + drift). Progressive-rules with P1 GC cycle fixes.

**Analysis**: Both address ongoing quality. Superpowers = manual/agent-driven. Harness = automated GC.

**Recommendation**: Harness's GC Engine is more automated and scalable. Keep GC Engine, use Superpowers' systematic-debugging for GC to identify drift causes.

---

## Over-Engineering Assessment

### Over-Engineering 1: Triple Code Review in Superpowers

**Problem**: Superpowers has three code review mechanisms:
1. Code Quality Reviewer subagent (during subagent-driven-development)
2. requesting-code-review skill (before major features, before merge)
3. receiving-code-review skill (when receiving feedback)

**Analysis**: These overlap significantly. requesting-code-review and receiving-code-review are two sides of same interaction. Code Quality Reviewer duplicates this with subagent workflow.

**Simplification**: Merge into single code review workflow:
- Implementer dispatches review → code-reviewer evaluates → receiving-code-review handles feedback
- Remove requesting-code-review as separate skill (it's the dispatch action, not separate mechanism)
- Remove receiving-code-review as separate skill (it's the response pattern, not separate mechanism)

**Impact**: Reduce 3 mechanisms to 1 workflow. Cognitive load reduced.

### Over-Engineering 2: Per-Task Code Review in Superpowers

**Problem**: "Review after EACH task in subagent-driven-development" from SUPERPOWERS-CALL-CHAIN.md.

**Analysis**: For a feature with 10 tasks, this means 10 code reviews. Milestone boundary review (Harness approach) would be 1-3 reviews depending on milestone granularity.

**Simplification**: Review at milestone boundaries instead of per-task. Catch accumulated issues at milestones rather than constant review overhead.

**Impact**: 90% reduction in review overhead. Quality maintained if milestones well-defined.

### Over-Engineering 3: Multiple Verification Gates in Superpowers

**Problem**: verification-before-completion applies to:
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Analysis**: This is overly broad. "ANY expression of satisfaction" catches legitimate communication ("This approach looks good" vs "This implementation is complete").

**Simplification**: Narrow scope to: (1) Task completion, (2) Commit/PR, (3) Delegation result. Remove "expression of satisfaction" from gate.

**Impact**: Reduce gate noise while maintaining verification discipline for completion claims.

### Over-Engineering 4: Spec Reviewer + Code Quality Reviewer Duplication

**Problem**: Superpowers has two separate subagents:
1. Spec Reviewer: Verifies code matches spec (missing/extra)
2. Code Quality Reviewer: Verifies quality (architecture, testing, requirements)

**Analysis**: These overlap significantly. Code Quality Reviewer's "Requirements" category covers spec verification. Spec Reviewer's "Misunderstandings" category is subset of code review.

**Simplification**: Merge into single code-reviewer subagent that checks: (1) Spec compliance (missing/extra), (2) Quality (architecture, patterns, testing), (3) Requirements completeness.

**Impact**: Reduce 2 subagents to 1. Single review pass more efficient.

### Over-Engineering 5: Progressive-Rules Implementation Complexity

**Problem**: progressive-rules design includes:
- _registry.json (global rule registry)
- _registry.schema.json (JSON Schema validation)
- Multiple YAML config files (_meta.yaml, _extends.yaml)
- CLI tools (validate, check, diff, migrate, docs)
- Linters directory
- Migrations directory

**Analysis**: This is complex for what should be simple rule enforcement. CLI tools add maintenance overhead. Registry adds another file to track.

**Simplification**: Use existing Golden Principles format. Add mechanical verification frontmatter. Skip CLI tools (use existing linters). Skip registry (file system is registry).

**Impact**: Remove 50% of progressive-rules complexity. Maintain rule management simplicity.

---

## Minimal Viable Quality System

Based on "AI is smart enough, keep it simple" philosophy, here's the minimal viable quality system combining best of both:

### Core Components (4 components)

**1. TDD as Implementation Methodology**
- Adopt test-driven-development skill's RED-GREEN-REFACTOR cycle
- Enforce with verification-before-completion gate
- Iron law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- Replace: Superpowers' TDD skill + verification gate

**2. Mechanical Enforcement (Golden Principles)**
- P0 rules = linters that block merge
- Keep 3-5 P0 rules (dependency direction, API envelope, no empty catch, hardcoded secrets)
- Replace: Superpowers' manual code checks

**3. Agent-to-Agent Review at Milestone Boundaries**
- Code-reviewer subagent reviews at milestone completion
- Checks: spec compliance, code quality, architecture, testing
- Replaces: per-task reviews (too many), spec reviewer (duplicate)
- Keeps: Superpowers' peer review benefit

**4. Automated GC Engine**
- Weekly scan for tech debt + drift
- Auto-creates PRs for P1 violations
- Replace: Manual code review before merge

### What to Remove (over-engineering)

- ❌ requesting-code-review as separate skill (it's dispatch action)
- ❌ receiving-code-review as separate skill (it's response pattern)
- ❌ Spec Reviewer as separate subagent (merge into code-reviewer)
- ❌ Progressive-rules CLI tools (use existing linters)
- ❌ Progressive-rules registry (file system is registry)
- ❌ Per-task code review (use milestone boundaries)

### What to Keep (best of both)

- ✅ TDD RED-GREEN-REFACTOR cycle (Superpowers)
- ✅ Verification-before-completion gate (Superpowers)
- ✅ Systematic-debugging methodology (Superpowers)
- ✅ P0 mechanical linters (Harness)
- ✅ GC Engine automation (Harness)
- ✅ Milestone-boundary quality gates (Harness efficiency)

### Workflow Integration

```
Atomic Feature → Plan → Execute
                           ↓
                    TDD (RED-GREEN-REFACTOR)
                           ↓
              [Per task implementation]
                           ↓
         Milestone Complete?
              ↓ Yes
         Agent Code Review (single pass)
                           ↓
        Verification Before Completion
                           ↓
              P0 Linter Check (merge gate)
```

---

## Key Recommendations

### Recommendation 1: Adopt TDD as Evals Implementation Detail

**Why**: Harness Evals lack implementation methodology. Superpowers TDD provides proven RED-GREEN-REFACTOR discipline.

**How**: Define Evals as verification of TDD adherence:
1. Test written before code (check git history for test-first commit)
2. Test failed for expected reason (not typo)
3. Minimal code to pass (no YAGNI violations)
4. All tests pass (80% coverage minimum)

**Benefit**: Transforms Evals from coverage metrics to process validation. Prevents tests-after gaming.

### Recommendation 2: Implement Single Code-Reviewer Subagent

**Why**: Superpowers has 3 overlapping code review mechanisms (Code Quality Reviewer, requesting-code-review, receiving-code-review). Harness lacks agent-to-agent review entirely.

**How**: Create single code-reviewer subagent that:
1. Checks spec compliance (missing/extra work)
2. Evaluates code quality (architecture, patterns, maintainability)
3. Validates testing (real tests, edge cases, integration tests)
4. Verifies requirements completeness

**Placement**: Run at milestone boundaries, not per-task. Reduces overhead while maintaining quality.

**Benefit**: Eliminates mechanism duplication. Provides Harness the missing agent-to-agent review capability.

### Recommendation 3: Adopt Verification-Before-Completion as Milestone Gate

**Why**: Harness lacks evidence culture. Superpowers verification-before-completion enforces "Evidence before claims."

**How**: Add milestone completion gate requiring:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute fresh verification command
3. READ: Full output, check exit code
4. VERIFY: Does output confirm claim?
5. ONLY THEN: Claim completion

**Benefit**: Strengthens evidence discipline. Prevents false completion claims.

### Recommendation 4: Simplify Progressive-Rules Implementation

**Why**: progressive-rules design is over-engineered (registry, schema, CLI tools, migrations).

**How**:
1. Use existing Golden Principles format with frontmatter
2. Add `mechanically_verifiable: true` to frontmatter
3. Use existing linters (no custom CLI tools)
4. File system as registry (no _registry.json)
5. P0 = block merge, P1 = GC cycle, P2 = advisory

**Benefit**: Reduces progressive-rules complexity by 50%. Maintains rule clarity.

### Recommendation 5: Add Systematic-Debugging as Harness Skill

**Why**: Harness lacks structured debugging methodology. Debugging is core activity.

**How**: Adopt systematic-debugging skill with iron law "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST."

**Integration**:
- Use during execution phase
- Require root cause investigation before any fix
- Apply 4-phase process: Root Cause → Pattern → Hypothesis → Implementation

**Benefit**: Prevents symptom-fixing. Reduces debugging thrashing.

### Recommendation 6: Harmonize Terminology

**Why**: P0/P1/P2 (Harness) vs Enforced/Advisory/Knowledge (progressive-rules) creates cognitive load.

**How**: Map explicitly:
- P0 → Enforced (mechanically verifiable, blocks merge)
- P1 → Advisory (mechanically detectable, warning only)
- P2 → Knowledge (cannot be automated, documentation only)

**Benefit**: Unified terminology reduces bridging cost between systems.

### Recommendation 7: GC Engine Focus on What Cannot Be Mechanically Verified

**Why**: Mechanical linters (P0) catch objective violations. GC Engine should focus on subjective quality drift that linters cannot catch.

**How**: GC Engine targets:
- Architecture violations (patterns not enforced by linters)
- Maintainability issues (complexity, duplication)
- Testing quality gaps (meaningless tests, missing edge cases)
- Documentation drift (docs not matching code)

**Benefit**: Complements mechanical linters. GC catches what automation cannot.

---

## Integration Roadmap

### Phase 1: Immediate Simplifications (Week 1)

- [ ] Merge Code Quality Reviewer, requesting-code-review, receiving-code-review into single workflow
- [ ] Remove per-task code review, use milestone boundaries
- [ ] Narrow verification-before-completion scope (remove "expression of satisfaction" gate)

### Phase 2: Core Quality Components (Week 2-3)

- [ ] Implement TDD RED-GREEN-REFACTOR as Evals implementation detail
- [ ] Create single code-reviewer subagent (spec + quality + testing)
- [ ] Add verification-before-completion at milestone boundaries
- [ ] Add systematic-debugging skill to Harness

### Phase 3: Progressive-Rules Simplification (Week 4)

- [ ] Simplify progressive-rules (remove registry, CLI tools, migrations)
- [ ] Harmonize P0/P1/P2 → Enforced/Advisory/Knowledge terminology
- [ ] Implement P0 linters using frontmatter metadata
- [ ] Define GC Engine scope (focus on non-mechanical violations)

### Phase 4: Validation (Week 5)

- [ ] Run pilot with minimal viable quality system
- [ ] Measure: review overhead, bug rate, agent satisfaction
- [ ] Iterate based on feedback

---

> **Design Philosophy Applied**: Throughout this analysis, prioritized simplicity. Removed over-engineering (triple code review, CLI tools, per-task reviews) while preserving core quality mechanisms (TDD, mechanical enforcement, agent-to-agent review).
