# Step 2: 审计评分与层级映射

## 审计评分

四维评分:

| 维度 | 权重 | 检查项 |
|------|------|--------|
| 文档覆盖 | 25% | AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md |
| Lint 覆盖 | 35% | lint-deps, lint-quality |
| 验证管道 | 25% | validate.py, build, test, verify |
| Harness 结构 | 15% | harness/ 目录 |

输出审计报告 (表格形式: 维度 / 得分 / 状态)。

## 层级映射

扫描所有源文件的 import 语句，构建依赖图:

1. 无内部依赖的包 → L0
2. 只依赖 L0 的 → L1，逐层向上
3. 检测循环依赖（A 导入 B 且 B 导入 A → 同层）

产出 `layer_map`，格式: `{"PackageName": 层级数字}`
