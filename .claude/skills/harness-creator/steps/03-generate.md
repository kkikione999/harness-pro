# Step 3: 生成所有文件

> 门控: Step 2 完成 + audit_score + layer_map 已知。运行 `{skill-dir}/scripts/creator-pipeline gate 3` 确认。

## 必须读取

- `{skill-dir}/references/generator.md` — 生成逻辑和模板
- `{skill-dir}/references/layer-rules.md` — 层级规则（用于 lint-deps 的教育性错误信息）
- `{skill-dir}/references/e2e-strategies.md` — E2E 验证策略（两层: Scripted + Live Test）

根据 Step 1 检测到的语言，读取对应模板:
- swift → `{skill-dir}/references/templates/swift.md`
- go → `{skill-dir}/references/templates/go/lint-deps.md`
- typescript → `{skill-dir}/references/templates/typescript/lint-deps.md`
- python → `{skill-dir}/references/templates/python/lint-deps.md`

## 生成优先级

按 `generator.md` 中的顺序，依次生成:

1. **AGENTS.md** — ≤100 行，纯索引（MAP 不是手册）。必须包含 4 条核心原则
2. **docs/ARCHITECTURE.md** — 层级图、包职责、外部依赖
3. **docs/DEVELOPMENT.md** — 构建/测试/lint 命令、常见任务
4. **scripts/lint-deps** — 层级依赖检查器，必须包含教育性错误信息（4 要素: WHAT + RULE + WHY + FIX）
5. **scripts/lint-quality** — 文件行数、print/console.log 检查
6. **scripts/validate.py** — build→lint→test→verify 管道
7. **E2E 验证** — 根据 `e2e-strategies.md` 生成两个层级:
   - **Tier 1 (Scripted)**: 构建/测试/lint 命令，验证管道 (`validate.py`)
   - **Tier 2 (Live Test)**: Agent 实时控制系统（非视觉、基于标识符）
     - Web/CLI/API → 直接可用 → E2E.md 记录具体 MCP 工具调用
     - 原生 App + MCP Bridge 已有 → E2E.md 记录 MCP 工具调用
     - 原生 App，无 MCP Bridge → E2E.md 记录缺口 + `docs/exec-plans/add-live-test-scaffolding.md` 脚手架计划
8. **harness/** — tasks/, trace/, memory/ 目录

## improve 模式的差异

如果 `mode=improve`:
- 不要覆盖已有文件
- 只更新缺失或过时的部分
- 保留用户自定义内容

## 每写完一个文件

```bash
chmod +x scripts/lint-deps scripts/lint-quality  # 如果是脚本
```

## 完成后

```bash
{skill-dir}/scripts/creator-pipeline advance 3 files_written='["AGENTS.md","docs/ARCHITECTURE.md",...]'
```
