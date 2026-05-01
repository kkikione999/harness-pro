# Step 3: 生成所有文件

## 必须读取

- `references/generator.md` — 生成逻辑和模板
- `references/layer-rules.md` — 层级规则（用于 lint-deps）
- `references/e2e-strategies.md` — E2E 验证策略

根据检测到的语言，读取对应语言模板。

## 生成顺序

1. **AGENTS.md** — ≤100 行，纯索引。必须包含 4 条核心原则
2. **docs/ARCHITECTURE.md** — 层级图、包职责、外部依赖
3. **docs/DEVELOPMENT.md** — 构建/测试/lint 命令
4. **scripts/lint-deps** — 层级依赖检查器，教育性错误信息（WHAT + RULE + WHY + FIX）
5. **scripts/lint-quality** — 文件行数、print/console.log 检查
6. **scripts/validate.py** — build→lint→test→verify 管道
7. **E2E 验证** — 根据 `e2e-strategies.md` 生成两层验证
8. **harness/** — 空目录结构

## improve 模式

如果 `mode=improve`:
- 不覆盖已有文件
- 只更新缺失或过时的部分
- 保留用户自定义内容
