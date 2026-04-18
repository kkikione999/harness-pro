# Architect分析

## 1. Creator能力映射

| Creator子能力 | 对应现有Skill | 差距 |
|---|---|---|
| 分析代码库 | `create-plan` (Step 1-3三步代码阅读) | 已覆盖 |
| 生成基础设施(文档) | `decompose-requirement` (feature定义), `create-plan` (plan.md), `complete-work` (文档维护) | 已覆盖 |
| 生成lint/验证脚本 | `execute-task` 内置P0 checks, `complete-work` 验证流程 | 已覆盖 |
| 审计评分(0-100) | **不存在** | 缺失 |

**Creator拆解结论**：Creator的大部分能力已被现有skill覆盖。唯一缺失是"审计评分"能力，但这是锦上添花，不需要新增skill。

---

## 2. Executor能力映射

| Executor子能力 | 对应现有Skill | 差距 |
|---|---|---|
| 检测环境 | 无 | 新项目初始化时由`decompose-requirement`的Skeleton Check处理；增量开发时跳过 |
| 加载上下文 | `create-plan` (写context.md) + `execute-task` (读context.md) | 已覆盖 |
| 制定计划 | `create-plan` (plan.md) | 已覆盖 |
| 人类批准 | `decompose-requirement` 一次确认 | **哲学差异**，见第3节 |
| 执行(TDD) | `execute-task` + `test-driven-development` | 已覆盖 |
| 里程碑验证 | `execute-task` milestone review | 已覆盖 |
| 完成 | `complete-work` | 已覆盖 |

**Executor拆解结论**：Executor的每个执行子能力都已在 `execute-task` 中实现。差距在于"人类批准节点"的位置和频率。

---

## 3. 关键差异分析

### 哲学差异

| | 阿里云 | 我们 |
|---|---|---|
| 人类参与 | 每个任务都要批准执行计划 | 仅在decompose时确认一次 |
| 信任模型 | 人审机执，AI执行可控 | 人定意图，AI自主执行 |

这是**哲学差异**，不是实现差异。我们选择了"单次交接+AI自主"的模式，阿里云选择了"持续人工监督"。

### 实现差异

| | 阿里云 | 我们 |
|---|---|---|
| 审计评分 | 有(0-100) | 无 |
| 环境检测 | Executor前置步骤 | 缺失 |
| 计划批准节点 | 每个任务执行前 | 仅在decompose后一次 |

---

## 4. 建议的Skill改造方案

### 4.1 不新增Skill，最小改造

| 文件 | 改动 |
|---|---|
| `execute-task/SKILL.md` | 在Step 1前增加"环境检测"段落（检查CLAUDE.md、依赖完整性） |
| `complete-work/SKILL.md` | 增加简单的自评分机制（基于P0通过率），不一定要0-100 |
| `decompose-requirement/SKILL.md` | 无需改动 |

### 4.2 新增Skill方案（如要完整对齐）

新增 `harness-pro-setup-environment`：
- 职责：检测项目环境、初始化基础设施（lint配置、Golden Principles）
- 触发时机：新项目第一次执行前
- 产物：`.harness/golden-principles/` 完整配置

**但这是过度工程**。现有 `decompose-requirement` 的Skeleton Check已经覆盖新项目初始化。

---

## 5. 最简单落地路径

### 方案A：不做任何事（推荐）

现状已经够用：
- Creator的"搭建设施"被decompose + create-plan + complete-work覆盖
- Executor的"环境检测"被decompose的Skeleton Check覆盖
- 缺失的"审计评分"是锦上添花，不影响核心流程

### 方案B：补齐环境检测（1小时工作量）

在 `execute-task/SKILL.md` 的Step 1前增加：

```markdown
### Step 0: Environment Check

Before reading plans:
- Verify CLAUDE.md exists (if not → invoke decompose-requirement skeleton bootstrap)
- Verify `.harness/golden-principles/` exists (if not → log warning, continue)
- Check project dependencies are installed (run a lightweight ping: `npm test` / `go build` / etc.)
- If environment broken → stop and report to user
```

### 方案C：加审计评分（可选，low priority）

在 `complete-work/SKILL.md` 的Step 1增加：

```markdown
### Self-Score (Optional)

Based on P0 check results and test pass rate, produce a informal score:
- All green + 80%+ coverage → "Solid"
- All green + <80% coverage → "Works, needs tests"
- P0 violations fixed → "Pass after fixes"
- P0 violations unfixed → "Blocked"

This is for human reference, not a gate.
```

---

## 结论

**不需要新增Skill。**

阿里云Creator/Executor模型与我们的6-skill模型能力完全重叠：

- Creator搭设施 → 已被decompose + create-plan + complete-work覆盖
- Executor执行 → 已被execute-task覆盖
- 唯一差异是"人类批准频率"和"审计评分"，都是锦上添花

最小改造：只在 `execute-task/SKILL.md` 增加Step 0环境检测。
