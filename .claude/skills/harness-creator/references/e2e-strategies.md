# E2E Verification Strategies

## Two Verification Tiers

| Tier | Name | How | Purpose |
|------|------|-----|---------|
| 1 | **Scripted** | Pre-written scripts, batch execution | CI, pre-commit, regression |
| 2 | **Live Test** | Agent interacts with running system in real-time | Development, feature verification |

Scripted catches regressions. Live Test lets Agent verify interactively.

## Tier 1: Scripted Verification

Pre-written verification that runs without Agent intervention.

`docs/E2E.md` includes:
- Build/test/lint commands
- What each command verifies
- How to run the full validation pipeline (`validate.py`)

## Tier 2: Live Test

Agent controls the running system in real-time through programmatic interfaces.
**No screenshots, no visual element location** — purely identifier-based or command-based interaction.

### Core Constraints

**禁止截图定位** — Agent 用标识符，不是截图。

**禁止坐标点击作为主方案** — 坐标依赖窗口大小和分辨率，标识符是代码级约定。

```
✗ 错误：截一张图 → 用视觉模型找到按钮位置 → 按坐标点击
✗ 错误：idb ui tap --x 500 --y 800
✓ 正确：通过标识符 → 直接操作元素
✓ 正确：idb ui tap --accessibility-id "submit-btn"
```

### docs/E2E.md Template

```markdown
# E2E Verification Guide

## Tier 1: Scripted Verification

### Commands
- `{build command}` — Build check
- `{test command}` — Run tests
- `./scripts/lint-deps` — Layer dependency check
- `./scripts/lint-quality` — Code quality check
- `python3 scripts/validate.py` — Full pipeline

### What's Covered
{List what each scripted step verifies}

## Tier 2: Live Test

### How to Observe
{Concrete method: `mcp__chrome-devtools__take_snapshot`, `curl`, etc.}

### How to Control
{Concrete method: `mcp__chrome-devtools__click`, `curl -X POST`, etc.}

### Core User Paths
1. {Path name}
   - Control: {step-by-step with concrete tool calls and identifiers}
   - Observe: {expected outcome + concrete check}
```
