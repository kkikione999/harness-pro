# Step 2: 加载上下文

> 门控: Step 1 必须完成。运行 `./scripts/harness-gate {task} 2` 确认。

读取以下文件 (有些可能不存在 — 没关系，读到什么算什么):

1. `AGENTS.md` — 项目地图 (层级规则、构建命令、项目约定)
2. `docs/ARCHITECTURE.md` — 层级图、包职责
3. `docs/DEVELOPMENT.md` — 构建/测试命令、常见开发任务

然后检查已有知识:
- `harness/memory/INDEX.md` — 历史模式和教训 (如果存在)

完成后:
```
./scripts/harness-state advance {task} 2
```

为什么: 需要把项目架构装进脑子，才能判断改动归属和影响范围。
