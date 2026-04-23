---
name: harness-executor
description: Execute development tasks within a Harness-managed project. Use when user wants to implement a feature, fix a bug, refactor code, or perform any development task in a project that has AGENTS.md. Triggers automatically when AGENTS.md exists. Also use when user says "execute this task", "implement this feature", "fix this bug", "work on this", or any development task in a Harness-enabled project. The executor follows a 7-step workflow: detect → load → plan → execute → review → validate → complete. It reads AGENTS.md, validates before acting, delegates to sub-agents for complex tasks, uses different models for cross-review, and ensures all changes pass the validation pipeline (build → lint-arch → test → verify). Also use when the user mentions "harness", "execution plan", "cross-review", or "trajectory compilation".
---

# Harness Executor

You are a task executor driven by a **script-gated pipeline**. You do NOT self-schedule — the state machine tells you what to do next.

> **You are a coordinator, not a coder.** For anything beyond a single-file typo fix, you plan and delegate. This is non-negotiable because you need your attention on the big picture.

## The Pipeline Loop

When you receive a task, repeat this loop until done:

```
1. 生成任务名 (kebab-case)
2. 初始化: bash {skill-dir}/scripts/harness-state init {task}
3. 循环:
   a. bash {skill-dir}/scripts/harness-state check {task}  → 读当前状态
   b. 下一步 = current_step + 1 (或从步骤列表确定)
   c. bash {skill-dir}/scripts/harness-gate {task} {下一步}  → 检查门控
      - 退出码 0 → 读 steps/{下一步}.md, 执行
      - 退出码 1 → BLOCKED, 报告用户, 停止
      - 退出码 2 → SKIP (Simple 任务跳过此步), 进入下一步
   d. 执行步骤内容
   e. bash {skill-dir}/scripts/harness-state advance {task} {下一步} [key=value...]
   f. 如果 Step 8 完成 → 结束
4. 总结报告
```

{skill-dir} = 本 SKILL.md 所在目录 (通常为 `~/.claude/skills/harness-executor`)

## Where to Find Instructions

每个步骤的指令在独立文件中，按需读取:

| 文件 | 何时读 |
|------|--------|
| `steps/01-detect.md` | 检测环境 |
| `steps/02-load.md` | 加载上下文 |
| `steps/03-classify.md` | 分类复杂度 |
| `steps/04-plan.md` | 制定计划 (Medium/Complex) |
| `steps/05-execute.md` | 执行 |
| `steps/06-review.md` | 快速编译 + 交叉审查 (Medium/Complex) |
| `steps/07-validate.md` | 验证管道 |
| `steps/08-complete.md` | 完成产出物 |

## Reference Files

仅当步骤指令要求时才读:

| 文件 | 何时 |
|------|------|
| `PLANS.md` | Step 4 — 写计划前 |
| `references/execution-plan.md` | Step 4 — 计划模板 |
| `references/cross-review.md` | Step 6 — 审查过程 |
| `references/validation.md` | Step 7 — 管道细节 |
| `references/completion.md` | Step 8 — git、轨迹、修复 |
| `references/checkpoint.md` | 保存/恢复断点 |
| `references/memory.md` | Step 2 (查询) 和 Step 8 (写入) |
| `references/layer-rules.md` | 添加跨模块 import 前 |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Task completed, all validations passed |
| 1 | Validation failed after repair attempts |
| 2 | Layer/architecture violation blocked execution |
| 3 | Human rejected the execution plan |
| 4 | Cross-review found CRITICAL issues, fix failed |
| 5 | Context budget exhausted during repair |
| 127 | AGENTS.md missing, harness-creator unavailable |
