# Step 4: 制定计划 (Medium/Complex)

> 门控: Step 3 必须完成，且 complexity != simple。运行 `./scripts/harness-gate {task} 4` 确认。
> Simple 任务会被 gate 脚本自动跳过 (退出码 2)。

### 写计划前:

读取 `PLANS.md` 全文。它包含行为准则，防止最常见的计划错误: 过度规划、模糊的成功标准、遗漏边界、层级顺序颠倒。跳过这个读取是计划质量差的最大预测因子。

然后读取 `references/execution-plan.md` 获取计划模板。

### 创建计划:

在 `docs/exec-plans/{task-name}.md` 写执行计划，使用模板。计划必须包含:
- Objective (一句话, ≤50 字)
- Invariants (来自 AGENTS.md 和 ARCHITECTURE.md 的规则)
- Scope (DO / DON'T 带具体文件路径)
- Phases 按低层到高层排列
- 每个 phase: Pre condition, Actions, Forbidden list, Post condition
- Rollback plan (具体的 — 分支名、要回滚的文件)

完成后:
```
./scripts/harness-state advance {task} 4 plan_path=docs/exec-plans/{task-name}.md phases=N key_decision="一句话"
```
