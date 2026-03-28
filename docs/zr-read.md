# zr-read：Harness-Pro 项目设计与架构总览（融合版）

> 生成日期：2026-03-18  
> 目标：将 `docs/` 内与“项目设计、架构、层级架构、原理教学、实践方法”相关内容融合为一份总览文档  
> 说明：本文件**已排除 README 设计类内容**（视觉排版、徽章、模板、发布操作、README 优化复盘等）

---

## 0. 阅读范围与排除范围

### 纳入汇总的核心文档

1. `harness-pro-architecture-overview-cn.md`
2. `harness-pro-deep-dive-analysis.md`
3. `harness-pro-teaching-guide.md`
4. `harness-pro-visual-teaching.md`

### 本次新增复核来源（代码与执行链路）

1. `.claude/agents/harness-pro-worker.md`
2. `.claude/skills/harness-pro-main/SKILL.md`
3. `.codex/skills/harness-pro-main/SKILL.md`
4. `.codex/skills/harness-pro-worker/SKILL.md`
5. `full-code-0dcaffe` 分支下 `test/task_manager/` 全量代码与测试
6. `full-code-0dcaffe` 分支提交链路（`05d4c89` → `16bc0c6` → `0dcaffe`）
7. 工具链实测命令（`python3` / `pip` / `pytest` / 导入检查）

### 已排除的 README 设计类文档

1. `github-readme-design-analysis.md`
2. `github-readme-quick-reference.md`
3. `github-readme-setup-guide.md`
4. `README-design-cheatsheet.md`
5. `readme-design-document.md`
6. `README-elements-guide.md`
7. `README-execution-summary.md`
8. `README-final-summary.md`

### 排除原则

- 不纳入 README 视觉设计、排版技巧、徽章策略、模板复制、README 发布流程。
- 仅保留与 Harness-Pro 框架本身有关的工程方法、架构分层、执行机制、教学路径。

---

## 1. 一句话总览

Harness-Pro 不是一个“完整产品代码库”，而是一套“多 Agent 工程执行框架规范”：通过 Main Agent 与 Worker 的职责分离、任务文档契约、3-4 文件小任务切片、Git Worktree 隔离执行和持续调度，实现可并行、可追踪、可验证的工程交付。

### 给技术小白的核心定义（你最需要先看）

| 词 | 通俗解释 | 在 Harness-Pro 里对应什么 |
|---|---|---|
| 功能 | 它能做什么 | 把大需求拆小任务并推进到合并 |
| 作用 | 它帮你解决什么痛点 | 降低多人冲突、提高可评审性、进度可见 |
| 目的 | 为什么要这样设计 | 保证复杂项目可控交付 |
| 目标 | 要达到的结果 | 小步快跑、持续验证、稳定主线 |
| 规范 | 必须遵守的规则 | Main/Worker 边界、任务契约、验证门禁 |
| 接口定义 | 模块怎么被调用 | 任务文档字段、Task/TaskStore 方法、状态流转 |

---

## 2. 项目定位与仓库现状

### 项目定位

- 本质：`工程编排方法论 + 执行契约`。
- 目标：把复杂需求拆成小任务，由 Worker 在隔离环境中执行并通过验证后合并。
- 价值重心：流程治理、职责边界、质量门禁，而不是单次大功能实现。

### 项目“功能-作用-目的-目标”四连表

| 维度 | 内容 |
|---|---|
| 功能 | 任务拆解、依赖管理、并行调度、评审反馈循环、最终合并 |
| 作用 | 把“人多活多易混乱”变成“分工清晰、状态可追踪、质量可验证” |
| 目的 | 在复杂工程里建立稳定可复用的协作流水线 |
| 目标 | 让每次交付都可审计、可回滚、可扩展 |

### 仓库现状（关键）

- `main` 分支以规范文档为主（技能定义、角色约束、流程规则）。
- 可运行示例主要在历史分支 `full-code-0dcaffe`（`test/task_manager/`）。
- 示例项目测试通过 66 条，能演示任务化迭代。
- 存在结构风险：`crtCC`/`crtPython` 为 gitlink 但缺少 `.gitmodules`。

### 代码现状复核结论（2026-03-18 实测）

1. “源码直跑”链路可用：测试通过。
2. “包化安装 + 包接口导入”链路存在明显不一致。
3. 仓库是“流程框架可学、示例实现可跑、发布级结构未收敛”的状态。

---

## 3. 分层架构（层级架构总图）

```text
用户需求
  -> Main Agent（编排）
    -> Policy Layer（规则与边界）
      -> Agent Team（固定 Worker 池）
        -> Worker Execution（实现+测试+反馈）
          -> Git Worktree Isolation（隔离）
            -> Merge to main（主线收敛）
```

### Layer 1：Policy Layer（规范层）

- 由 Main/Worker 技能文档定义行为边界。
- 约束“谁可以做什么、不能做什么”。

**代码映射（规范层文件）**

- `.claude/skills/harness-pro-main/SKILL.md`
- `.codex/skills/harness-pro-main/SKILL.md`
- `.claude/agents/harness-pro-worker.md`
- `.codex/skills/harness-pro-worker/SKILL.md`

### Layer 2：Orchestration Layer（编排层）

- Main Agent 负责：任务拆分、依赖解析、状态管理、调度、评审决策。
- 关键机制：滚动调度（完成一个，重排一批）。

**输入/输出接口（编排层）**

- 输入：用户需求、当前任务图、已合并结果。
- 输出：新任务文档、任务状态更新、Worker 分配决策。

### Layer 3：Execution Layer（执行层）

- Worker 负责：按任务文档实现、加测试、跑验证、处理评审反馈、最终合并。
- 关键约束：不允许自行扩 scope。

**执行层在示例代码中的映射**

- `test/task_manager/task.py`
- `test/task_manager/store.py`
- `test/task_manager/tests/*.py`

### Layer 4：Isolation Layer（隔离层）

- 每任务独立分支 + 独立 worktree。
- 支持并行开发、冲突隔离、可回滚。

### Layer 5：Reference Layer（示例实现层）

- 历史分支示例项目用于演示任务化增量开发（Task 001~003/004 历史演进）。

### 代码层级结构（实物视图）

```text
harness-pro/
├── .claude/.codex                # 规范与角色契约层
├── docs/                          # 方法论与教学层
└── (full-code-0dcaffe)
    └── test/task_manager/         # 参考实现层
        ├── task.py                # 领域模型层（Task）
        ├── store.py               # 领域服务层（TaskStore）
        ├── tests/                 # 验证层（行为规格）
        ├── tasks/*.md             # 任务契约层（执行合同）
        └── pyproject.toml         # 工具链入口
```

---

## 4. 核心设计原则（必须掌握）

### 原则 1：职责分离

- Main Agent 只编排，不直接改 worker-owned 代码。
- Worker 只执行，不做架构决策。

**作用**：避免“既当裁判又当运动员”。  
**目的**：让责任可追踪，返工可定位。  
**规范落地**：Main 只改文档/任务图，Worker 才改业务代码。

### 原则 2：任务文档即契约

- 每任务都要明确：目标、范围、非目标、依赖、验证命令、验收标准。
- 契约优先于“临场发挥”。

**作用**：减少“我以为你要这个”的沟通成本。  
**目的**：把口头需求变成可审查的执行合同。  
**规范落地**：缺字段不派工，字段冲突先澄清再执行。

### 原则 3：小任务切片（3-4 文件）

- 推荐 3 个文件，最多 4 个文件。
- 好处：可评审、低风险、可并行、可追踪。

**作用**：让每次改动都小而明确。  
**目的**：把复杂问题分治，降低合并冲突与回滚成本。  
**规范落地**：超过预算必须拆任务，不允许默默膨胀。

### 原则 4：隔离执行

- 所有任务在独立 worktree 中进行。
- 避免共享工作目录污染。

**作用**：多人并行互不影响。  
**目的**：让冲突局部化。  
**规范落地**：worktree 统一放在仓库根 `.worktrees/`。

### 原则 5：固定团队复用

- Worker 团队创建一次、反复复用。
- 降低上下文切换与“反复培训”成本。

**作用**：团队熟悉度随时间上升。  
**目的**：提高吞吐与稳定性。  
**规范落地**：非必要不新增 worker，不频繁换人。

### 原则 6：按需创建任务（Demand-Driven）

- 不一次性预创建全量任务文档。
- 依据最新合并结果动态生成下一批任务。

**作用**：避免前期过度设计。  
**目的**：让计划始终跟随真实代码状态。  
**规范落地**：有空闲 worker 且有可执行工作时再创建任务。

### 原则 7：依赖驱动并行

- 有依赖的任务串行，无依赖任务并行。
- 并行目标是缩短工期，不是盲目多开任务。

### 原则 8：Worker 端到端负责

- Worker 从实现到合并全流程负责。
- 评审通过不等于完成，进入 `main` 才算完成。

### 原则 9：验证门禁前置

- 测试、类型、格式、安全、文档门禁都应在提交评审前通过。

### 原则 10：状态机驱动管理

- 用标准状态统一进度表达，降低协作歧义。

---

## 5. 任务状态机与流程闭环

### 状态定义（ExecPlan 强制底线）

1. `IN_DEV`：开发进行中。
2. `AUDIT_PENDING`：等待 Main 审计结论。
3. `AUDIT_PASS`：审计通过，但尚未完成 merge 流程。
4. `MERGE_REQUIRED`：必须立即执行 `sync + rebase/merge + revalidate + merge`。
5. `MERGED`：已完成 merge 且记录 `merged_commit_sha`。
6. `BLOCKED`：执行受阻。
7. `FEATURE_DONE`：Feature 完成并进入收尾清理。
8. `FEATURE_BLOCKED_EXIT`：达到停滞退出条件并进入收尾清理。

### 标准流转

```text
IN_DEV -> AUDIT_PENDING -> AUDIT_PASS -> MERGE_REQUIRED -> MERGED -> FEATURE_DONE
IN_DEV/AUDIT_PENDING/AUDIT_PASS -> BLOCKED
IN_DEV/AUDIT_PENDING/AUDIT_PASS/MERGE_REQUIRED -> FEATURE_BLOCKED_EXIT
```

补充规则：

- `AUDIT_PASS` 后必须立即触发一次 merge 流程，不允许停留为“完成”。
- 没有 `merged_commit_sha` 不得进入 `FEATURE_DONE`。
- 当 checklist `>=95%` 且“无新增勾选”持续满足（默认 `>=3` 调度周期且 `>=120` 分钟）时，必须输出 `BLOCK_REPORT` 并进入 `FEATURE_BLOCKED_EXIT`。
- `FEATURE_DONE` 或 `FEATURE_BLOCKED_EXIT` 后，必须执行清理（临时文件/垃圾文件/无用目录/worktree），且不得删除 tracked 文件。

### 全盘工作链路复核（输入/输出视角）

| 阶段 | 负责方 | 输入 | 输出 | 接口定义 |
|---|---|---|---|---|
| 需求收敛 | 用户 + Main | 业务目标 | 可执行目标描述 | 自然语言需求 |
| 任务建模 | Main | 目标 + 当前代码状态 | `tasks/task-xxx.md` | 任务文档字段集合 |
| 任务分派 | Main | Ready 任务 + 空闲 Worker | 分配记录 | Job ID / Branch / Worktree |
| 实现编码 | Worker | 任务文档 | 代码改动 | 代码接口（函数/类） |
| 验证测试 | Worker | 改动代码 | 测试结果 | `pytest` 等命令 |
| 评审反馈 | Main/Reviewer | Diff + 测试结果 | 通过/驳回意见 | 评审清单 |
| 合并收敛 | Worker | 通过评审的分支 | `main` 新提交 | git merge |
| 重排调度 | Main | 最新主线状态 | 新一轮任务 | 状态机转移 |

### Main Agent 循环（抽象）

1. 查找空闲 Worker。
2. 挑选可执行任务并生成任务文档。
3. 分发任务并监控进度。
4. 处理评审结果并解锁后续任务。
5. 持续重调度。

### Worker 循环（抽象）

1. 读取任务契约。
2. 创建/进入 worktree。
3. 实现代码与测试。
4. 运行验证命令。
5. 提交评审，按反馈循环修订。
6. 合并主线并清理工作区。

---

## 6. 任务文档标准（可直接复用）

### 必填字段

- Job ID
- Goal
- Task Type
- Scope
- Non-Goals
- Repository Context
- Branch Name
- Worktree Path
- Required Agent
- Expected File Budget
- Dependencies
- Validation Commands
- Acceptance Criteria
- Testing Requirements

### 字段的功能、作用、目的、规范

| 字段 | 功能 | 作用 | 目的 | 规范 |
|---|---|---|---|---|
| Goal | 定义要达成什么 | 防止跑偏 | 对齐交付目标 | 一句话可验证 |
| Scope | 定义要做哪些改动 | 控制范围 | 降低蔓延修改 | 用可执行条目写 |
| Non-Goals | 定义不做什么 | 防止越界 | 切断隐性需求 | 必须明确列出 |
| Dependencies | 定义前置任务 | 保证顺序 | 防止并行错误 | 写清任务 ID |
| Validation Commands | 定义怎么验收 | 可复现验证 | 质量门禁前置 | 命令可直接运行 |
| Acceptance Criteria | 定义完成标准 | 明确 Done | 避免“主观完成” | 用勾选清单 |

### 最小模板

~~~~markdown
# Task [ID]: [Title]

## Goal
[一句话目标]

## Scope
- [要做的事情]

## Non-Goals
- [明确不做]

## Dependencies
- [依赖任务]

## Branch & Worktree
- Branch: feature/task-[ID]
- Worktree: .worktrees/task-[ID]

## Validation Commands
- `pytest tests/ -v`

## Acceptance Criteria
- [ ] 功能达成
- [ ] 测试通过
- [ ] 无越界修改
~~~~

---

## 7. 教学抽象：把复杂概念变成可记忆模型

### 角色映射（教学比喻）

- Main Agent = 总建筑师 / 餐厅经理：负责规划、调度、验收。
- Worker Agents = 匠人 / 厨师：负责执行任务书。
- Task Document = 菜谱 / 施工单：定义边界和标准。
- Worktree = 独立工作间 / 独立厨房：互不干扰并行作业。
- Main Branch = 主楼：所有任务收敛后的稳定主线。

### 五句口诀（教学沉淀）

1. 经理规划，工人干活。
2. 任务有契约，不靠猜。
3. 三四文件，评审刚好。
4. 工作区隔离，互不打扰。
5. 固定团队复用，效率递增。

### 小白最容易误解的点（补充）

| 常见误解 | 正确认知 |
|---|---|
| Main Agent 是“更强程序员” | Main 是“编排器”，不是执行器 |
| 任务文档是可选说明 | 任务文档是执行合同，缺失即高风险 |
| 测试可以最后补 | 测试是同任务内必须项，不是后置项 |
| 并行越多越快 | 只有无依赖任务才能并行 |

---

## 8. 参考实现（历史分支）提炼

### 示例项目结构

- `task.py`：Task 模型。
- `store.py`：TaskStore 存储。
- `tests/`：Task、Store、Completion 测试。
- `tasks/`：任务文档链路。

### 关键功能快照

- Task：title/description/completed + 状态切换方法。
- TaskStore：add/list/get + 完成状态接口。
- 测试：总计 66 条（Task 26 + Store 22 + Completion 18）。

### 代码级接口定义（当前实现）

#### `Task` 接口（`test/task_manager/task.py`）

```python
class Task:
    def __init__(self, title: str, description: Optional[str] = None)
    def __repr__(self) -> str
    def __eq__(self, other: object) -> bool
    def mark_complete(self) -> None
    def mark_incomplete(self) -> None
    def toggle_completion(self) -> None
```

- 输入约束：`title` 必须是字符串，否则 `TypeError`。
- 行为语义：任务相等性以 `title` 为准（不是对象地址）。

#### `TaskStore` 接口（`test/task_manager/store.py`）

```python
class TaskStore:
    def __init__(self) -> None
    def add_task(self, task: Task) -> Task
    def list_tasks(self) -> List[Task]
    def get_task(self, title: str) -> Optional[Task]
    def mark_task_complete(self, title: str) -> Optional[Task]
    def mark_task_incomplete(self, title: str) -> Optional[Task]
    def toggle_task_completion(self, title: str) -> Optional[Task]
```

- 输入约束：`add_task` 必须传 `Task` 实例，否则 `TypeError`。
- 输出约束：`list_tasks` 返回副本，避免外部直接污染内部 `_tasks`。

### 工具链

- Python + `pyproject.toml`。
- `pytest` 驱动验证。
- Git 任务化提交和合并。

### 演进观察（代码层）

- 早期版本（`66c576d`）使用 `task_manager/models.py` + `task_manager/store.py`，支持 JSON 持久化。
- 后期版本（`05d4c89`~`0dcaffe`）转为 `task.py` + `store.py` 简化方案，突出流程演示。
- 当前分支同时存在“旧包路径残留 + 新简化实现”，出现接口并存与失配风险。

### 结构失配点（实测）

1. `task_manager/__init__.py` 试图从 `.models` 导入 `Task`，但当前分支无 `task_manager/models.py`。
2. `task_manager/store.py` 依赖 `task_manager.models.Task`，与根目录 `task.py` 体系不一致。
3. 同仓内存在多个 `store.py`（根目录、`task_manager/`、`test/task_manager/`）概念冲突。
4. `test/task_manager/.worktrees/task-003-complete` 被版本库记录为 gitlink，属于流程痕迹泄露。

**结论**：教学流程可学，但发布级包结构尚未统一。

---

## 9. 质量体系：测试、门禁、可追溯

### 测试策略

- 每任务必须包含测试。
- 覆盖 happy path、边界条件、错误处理、集成回归。
- 推荐 AAA（Arrange-Act-Assert）结构，保持测试隔离。

### 建议验证序列

1. 目标模块单测。
2. 相关模块测试。
3. 全量测试。
4. 类型检查（如启用）。
5. 格式/静态检查。
6. 安全扫描（按需）。

### 门禁模型

- Code Quality Gate
- Test Gate
- Type Gate
- Security Gate
- Documentation Gate

任一 gate 失败时，不得提交评审。

### 全盘工具链复核结果（2026-03-18 实测）

| 检查项 | 命令 | 结果 | 结论 |
|---|---|---|---|
| Git 版本 | `git --version` | `2.50.1` | 可用 |
| Python 版本 | `python3 --version` | `3.9.6` | 可用 |
| pip 版本 | `python3 -m pip --version` | `21.2.4` | 偏旧 |
| setuptools 版本 | `import setuptools` | `58.0.4` | 偏旧 |
| 全量测试 | `python3 -m pytest tests/ -q` | `66 passed` | 源码验证通过 |
| 可编辑安装 | `python3 -m pip install -e '.[test]'` | 失败 | 旧 pip 对 editable/pyproject 支持不足 |
| 普通安装 | `python3 -m pip install .` | 成功但包名 `UNKNOWN-0.0.0` | 打包元数据异常 |
| 包导入检查 | `import task_manager.task` | `ModuleNotFoundError` | 包接口不完整 |
| 包导入检查 | `from task_manager import Task, TaskStore` | `ModuleNotFoundError: task_manager.models` | 包 API 失配 |

### 质量链路结论

- **通过**：任务化源码开发与测试链路（教学核心链路）。
- **未通过**：可编辑安装与稳定包 API 链路（发布链路）。
- **建议**：学习时按“源码模式”；发布前必须先收敛包结构。

---

## 10. 安全体系：多层隔离与最小权限

### 四层隔离

1. Worker 隔离：任务级执行主体隔离。
2. Worktree 隔离：目录与工作状态隔离。
3. 分支隔离：必须显式合并进入主线。
4. 职责隔离：Main/Worker 权限边界清晰。

### 典型威胁与缓解

- 代码污染：通过评审 + 合并门禁缓解。
- 权限越界：通过任务契约与 scope 限定缓解。
- 依赖注入：通过文档化依赖与验证流程缓解。
- 信息泄露：通过隔离工作区与审计日志缓解。
- 资源耗尽：通过固定团队与任务节奏控制缓解。

### 安全实践

- 最小权限执行。
- 全链路审计日志。
- 密钥仅使用环境变量，不硬编码。

### 小白版理解

- 安全不只是“防黑客”，更是“防误操作”。
- Harness-Pro 的本质是把错误影响范围缩小到单任务。

---

## 11. 在新项目落地的标准步骤

### Step 1：初始化结构

- 建立 `.claude/`、`.worktrees/`、`docs/tasks/`、`src/`、`tests/`。

### Step 2：复制并定制 Main/Worker 规则

- 将 Harness-Pro 技能模板改成项目私有版本。

### Step 3：创建首个任务文档

- 从最小可交付能力开始（如基础模型、基础 API）。

### Step 4：启动编排循环

- Main Agent 调度。
- Worker 执行。
- 评审反馈。
- 合并解锁下一任务。

### Step 5：持续优化

- 迭代任务模板。
- 沉淀检查清单。
- 添加自动化脚本（worktree、状态、CI）。

### 详细举例（你可以直接照着理解）

#### 示例目标

做一个“任务管理”最小功能：

1. 能创建任务。
2. 能查询任务。
3. 能标记完成。

#### 任务拆分

- Task-001：建 `Task` 类（2 个文件：`task.py` + `tests/test_task.py`）。
- Task-002：建 `TaskStore`（2-3 个文件：`store.py` + `tests/test_store.py` + 可选导入调整）。
- Task-003：补完成状态接口（2 个文件：`task.py` + `tests/test_complete.py`）。

#### 接口目标（每个任务的“完成定义”）

- Task-001 完成时：
  - `Task("A")` 可创建。
  - `title` 非字符串抛 `TypeError`。
- Task-002 完成时：
  - `add_task/list_tasks/get_task` 可用。
- Task-003 完成时：
  - `mark_complete/mark_incomplete/toggle_completion` 可用。

#### 执行链路（实际发生什么）

```text
Main 写 Task-001 文档
 -> Worker 在 .worktrees/task-001 中实现
 -> Worker 跑 pytest
 -> Main 评审
 -> Worker 合并
 -> 解锁 Task-002
 -> ...
```

#### 你如何判断“它真的完成了”

- 看 `Acceptance Criteria` 是否全勾选。
- 看验证命令是否可复现通过。
- 看代码是否已进 `main`。

---

## 12. 常见决策规则（FAQ 融合版）

### 文件数超预算怎么办

- 停止扩展，先报告 Main Agent。
- 由 Main Agent 决定拆分或批准扩容。

### Main Agent 能不能直接改代码

- 不能，这是职责隔离的底线。

### 任务能否并行

- 仅当依赖闭包满足且任务间无直接耦合时可并行。

### 测试失败能否先提审

- 不能。先修复并通过验证再提审。

### worktree 何时清理

- 合并后保留一段时间用于回溯，再定期清理。

### 新手常问：我到底调用哪个接口

- 以当前示例为准，优先使用根目录实现：
  - `task.py::Task`
  - `store.py::TaskStore`
- 不建议直接依赖当前 `task_manager/__init__.py` 暴露 API（存在 `models` 引用失配）。

### 新手常问：测试全过了，为什么还说有问题

- 因为“测试通过”只代表源码路径可用。
- “可发布/可安装/可导入”是另一条链路，当前链路存在结构失配。

---

## 13. 风险清单与改进路线

### 当前主要风险

1. 规范与实现跨分支分离，学习成本高。
2. 子模块信息不完整，复现链路不稳定。
3. 任务状态文档可能滞后于实际提交。
4. 示例包结构与安装导入路径存在一致性问题。
5. 工具链版本偏旧（pip/setuptools）导致 editable 安装失败。
6. 包元数据异常（安装产物显示 `UNKNOWN-0.0.0`）。

### 改进路线（综合建议）

#### 短期（建议先做）

- 完善 `.gitmodules`。
- 统一包结构：只保留一套 `Task/TaskStore` 对外路径。
- 修复 `task_manager/__init__.py` 与 `task_manager/store.py` 的失配依赖。
- 升级 `pip`/`setuptools`，复测 `pip install -e '.[test]'`。

#### 中期

- 增加 worktree 管理 CLI。
- 可视化任务依赖图。
- 提供 CI/CD 模板与指标采集。

#### 长期

- 远程协作平台集成（PR 工作流）。
- Web 化任务看板。
- 多语言模板生态与插件化扩展。

### 风险优先级建议

- P0：包接口失配与元数据异常（影响“能否正确安装/导入”）。
- P1：文档状态与真实提交不一致（影响学习判断）。
- P2：子模块信息缺失（影响完整复现）。

---

## 14. 学习与实践路径（4 周版）

### 第 1 周：框架认知

- 读架构概览 + 深度分析 + 教学文档。
- 画出自己的任务状态机图。
- 重点理解：Main/Worker 边界、任务文档字段、3-4 文件规则。

### 第 2 周：小项目演练

- 亲手写 3-5 个任务文档。
- 在隔离 worktree 里完成一次完整循环。
- 重点练习：写清 Scope 与 Non-Goals。

### 第 3 周：真实项目试点

- 在一个中小需求上替换原有“大分支”方式。
- 评估并行效率与返工率变化。
- 记录每个任务的验证命令与门禁结果。

### 第 4 周：团队固化

- 统一任务模板、验证门禁、评审标准。
- 固化成团队协作规范。
- 把高频失败场景沉淀成检查清单。

### 学习检查点（你可以自测）

- 我能否独立写出一个合格任务文档。
- 我能否解释每个状态的进入/退出条件。
- 我能否判断一个任务是否应该拆分。
- 我能否区分“测试通过”和“发布可用”的差异。

---

## 15. 最终结论

Harness-Pro 的核心价值在于把“多人协作 + 多任务并行 + 质量控制”变成一套可执行的工程协议。它最适合作为团队流程框架和项目编排模板使用。

如果你要把它真正用起来，最重要的不是记住术语，而是把以下三件事执行到底：

1. 严格职责分离（Main 不越界，Worker 不扩 scope）。
2. 严格任务契约（每任务目标/边界/验证都明确）。
3. 严格验证门禁（不过门禁不提审，不过评审不合并）。

同时基于本次复核，你还需要补上第 4 件事：

4. 严格收敛“包结构与接口一致性”（测试能过不等于安装可用）。

这四点稳定后，规模化协作、并行开发和可追溯交付会自然出现。
