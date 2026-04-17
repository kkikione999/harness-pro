# Skeleton Bootstrap

This file is loaded only when decompose-requirement detects that the project skeleton is missing (no CLAUDE.md in project root). It provides the bootstrap logic and templates.

## When This Runs

- User enters decompose-requirement for the first time in a project
- CLAUDE.md does not exist in the project root
- This runs ONCE per project; subsequent entries skip directly to Two Paths

## Three-Layer Progressive Disclosure Structure

```
项目根目录/
├── CLAUDE.md                    ← L0 入口（几乎不变）
└── docs/
    ├── ARCHITECTURE.md          ← L1 架构（很少变动）
    └── features/                ← L2 Feature（每个 feature 更新）
        └── {feature-id}/
            ├── index.md         ← Feature 定义
            └── plan.md          ← 执行计划
```

- **不需要 design-docs/**，feature 里的 index.md + plan.md 已覆盖
- **不需要预先创建 features/ 下任何内容**，第一个 feature 时自然创建

## Two Scenarios

### Scenario A: New Project

The codebase is empty or near-empty (no src/, no existing application code).

**Action**: Create `CLAUDE.md` and `docs/ARCHITECTURE.md` with templates below, filling in what you know from the user's context.

### Scenario B: Existing Project

The codebase has substantial existing code (src/, lib/, app/, etc.).

**Action**: Scan the codebase first, then generate `CLAUDE.md` and `docs/ARCHITECTURE.md` reflecting the project's actual state.

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

```
src/                    — 源代码
docs/                   — 文档（见 ARCHITECTURE.md）
features/               — Feature Registry（第一个 feature 时创建）
.harness/               — Harness 执行状态（不要修改）
```

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

详见 `docs/ARCHITECTURE.md`（渐进填充，架构很少变动）

## Conventions

- Naming: {convention}
- Error handling: {convention}
- Testing: {coverage requirement}
- 文件限制: 单文件 ≤ 800 行
- 禁止硬编码 secrets

详见: `.claude/skills/harness-pro-execute-task/references/p0-lint-guide.md`

## Harness Engineering

This project uses Harness Engineering workflow:
- Feature definitions live in `docs/features/{feature-id}/index.md`
- Execution plans live in `docs/features/{feature-id}/plan.md`
- Working state lives in `.harness/file-stack/`
- Architecture lives in `docs/ARCHITECTURE.md`
```

## After Bootstrap

Once CLAUDE.md is created:

1. Create directory structure:
   ```
   docs/
   └── ARCHITECTURE.md          ← 见下方占位模板
   ```

2. Create `docs/ARCHITECTURE.md` with placeholder content (see template below)

3. Create `.harness/` directory structure if it doesn't exist:
   ```
   .harness/
   ├── controllability/
   ├── observability/
   └── file-stack/
   ```

4. Do NOT create `docs/features/` yet — created by decompose-requirement when first feature is defined

5. Proceed to normal decompose-requirement flow (Two Paths)

## docs/ARCHITECTURE.md Placeholder Template

```markdown
# Architecture

> Architecture rarely changes. This file is updated when significant architectural patterns are discovered during feature implementation.

## 分层结构

(待填充：第一个 feature 完成后从 context.md 提取)

<!-- 填充后示例：
Types → Config → Repo → Service → Runtime → UI
-->

## 依赖规则

(待填充：基于实际代码依赖关系)

<!-- 填充后示例：
高层可 import 低层，反向禁止。
详细规则见: .claude/skills/.../p0-lint-guide.md
-->

## 入口点

- 应用入口: (待填充)
- API 层: (待填充)

## Feature 概览

| ID | Name | 状态 |
|----|------|------|
| (待填充) | | |

---

更新时机：ARCHITECTURE.md 由 complete-work 自动检测 context.md 的架构发现后更新。
不需要手动维护。
```
