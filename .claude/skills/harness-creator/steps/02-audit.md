# Step 2: 审计评分与层级映射

> 门控: Step 1 完成。运行 `{skill-dir}/scripts/creator-pipeline gate 2` 确认。

## 审计评分

**必须读取** `{skill-dir}/references/audit.md`，按照其中的评分逻辑执行。

四维评分:

| 维度 | 权重 | 检查项 |
|------|------|--------|
| 文档覆盖 | 25% | AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md |
| Lint 覆盖 | 35% | lint-deps, lint-quality |
| 验证管道 | 25% | validate.py, build, test, verify |
| Harness 结构 | 15% | harness/ 目录 |

输出审计报告 (表格形式: 维度 / 得分 / 状态)。

## 层级映射

**必须读取** `{skill-dir}/references/layer-rules.md`，按照"从 import 推断层级"的逻辑执行:

1. 扫描所有源文件的 import 语句，构建依赖图
2. 无内部依赖的包 → L0
3. 只依赖 L0 的 → L1，逐层向上
4. 检测循环依赖（A 导入 B 且 B 导入 A → 同层）

产出 `layer_map`，格式: `{"PackageName": 层级数字}`

## 完成后

```bash
{skill-dir}/scripts/creator-pipeline advance 2 audit_score={0-100}
```

然后单独写入 layer_map (JSON 对象):

```bash
{skill-dir}/scripts/creator-pipeline advance 2 layer_map='{"PkgA":0,"PkgB":1}'
```

注意: advance 对同一 step 调用多次是幂等的，key=value 会合并更新。
