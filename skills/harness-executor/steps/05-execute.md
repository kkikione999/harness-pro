# Step 5: 执行

> 门控: Step 4 完成 (Medium/Complex) 或 Step 3 完成 (Simple)。运行 `./scripts/harness-gate {task} 5` 确认。

### Simple 任务:
可以直接编辑文件。这是你写代码的唯一情况。编辑后进入 Step 6 验证。

### Medium/Complex 任务:
委派给 sub-agent。给它:
- 计划中的精确任务描述
- 正在执行的 phase(s)
- 需要读取的文件 (AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md)
- Post condition (需要满足的后置条件)
- 本 phase 的 Forbidden list

模型选择:
- `haiku` — 简单明确、有清晰模式的改动
- `sonnet` — 大多数编码任务、多文件改动
- `opus` — 深度重构、架构决策、微妙的 bug

Sub-agent 返回后，验证它没有越界 (`git diff --name-only` 对照计划的 Forbidden list)。

完成后:
```
./scripts/harness-state advance {task} 5 files_changed="文件列表" drift=PASS|FAIL
```
