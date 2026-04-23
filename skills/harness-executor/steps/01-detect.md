# Step 1: 检测环境

> 门控: 无前置条件。运行 `./scripts/harness-gate {task} 1` 确认。

检查项目根目录是否存在 `AGENTS.md`。

**如果 AGENTS.md 存在:**
标记 Step 1 完成，进入 Step 2。
```
./scripts/harness-state advance {task} 1
```

**如果 AGENTS.md 不存在:**
你不在 harness 管理项目中。两个选项:
1. 如果 `harness-creator` skill 可用 — 调用它引导基础设施，然后回到 Step 1 重新开始。
2. 如果 `harness-creator` 不可用 — 告诉用户: "本项目没有 harness 基础设施 (AGENTS.md 缺失)。我可以继续，但不会有层级规则、验证脚本或架构文档来指导我。" 然后作为普通编码任务继续，**不再**遵循本 skill 的工作流。

为什么重要: AGENTS.md 是项目的"地图"。没有它就是盲目操作——没有层级规则、没有依赖约束、没有验证目标。盲目操作是 AI Agent 在代码库中犯错的第一大原因。
