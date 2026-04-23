# Step 3: 分类复杂度

> 门控: Step 2 必须完成。运行 `./scripts/harness-gate {task} 3` 确认。

问自己: **能用一句话描述任务吗 (不用"和")?**

| 复杂度 | 标准 | 你的角色 |
|--------|------|----------|
| **Simple** | 一个文件、错别字修复、一行改动 | 直接执行 (唯一例外) |
| **Medium** | 多文件改动，但遵循已有模式 | 计划 → 委派 sub-agent |
| **Complex** | 重构、新模块、架构决策 | 计划 → 委派 sub-agent + worktree 隔离 |

**Simple 任务自检** (全部回答 YES 才能算 Simple):
- 只改 1 个文件?
- 改动 < 5 行?
- 无新 import 或依赖?
- 无架构决策?
- 无需测试改动 (除了更新期望值)?

任何一项回答 NO → 至少 **Medium**。

**动态升级** — 执行中发现:
- 改动 > 3 个文件且不在计划中 → 升级到 Complex
- 需要未计划的跨模块 import → 升级到 Complex
- Simple 任务需要 > 2 个文件 → 升级到 Medium

升级时: 停止，更新计划，切换到对应的执行模式。

完成后:
```
./scripts/harness-state advance {task} 3 complexity={simple|medium|complex} reason="一句话判断理由"
```
