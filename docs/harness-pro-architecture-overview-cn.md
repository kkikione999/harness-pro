# harness-pro 架构与实现简述（学习版）

> 复核日期：2026-03-17  
> 复核范围：`main` 分支（当前）、`full-code-0dcaffe` 分支（历史实现）、`.claude/` 与 `.codex/` 技能文档

## 1. 项目定位

`harness-pro` 的核心不是单一业务系统，而是一个“多 Agent 工程执行框架”的规范仓库。  
它定义了如何将复杂工程任务拆分、分派、验证、评审和合并，重点在流程治理与执行边界。

一句话总结：**这是一个“工程编排方法论 + 执行契约”的项目，而不是功能完整的产品代码仓库。**

---

## 2. 当前仓库状态（重要）

### 2.1 `main` 分支现状
- 以规范文档为主：
  - `.codex/skills/harness-pro-main/SKILL.md`
  - `.codex/skills/harness-pro-worker/SKILL.md`
  - `.claude/skills/harness-pro-main/SKILL.md`
  - `.claude/agents/harness-pro-worker.md`
- 根目录 `README.md` 内容极简（仅项目名）。
- `crtCC` 与 `crtPython` 当前是 **gitlink（子模块指针）**，但仓库内缺少 `.gitmodules`，无法直接定位并拉取对应子模块来源。

### 2.2 历史代码实现
- 在 `full-code-0dcaffe` 分支保留了可运行示例：`test/task_manager/`
- 该示例展示了“任务拆解 + 小步实现 + 测试驱动”的落地方式，是理解框架设计意图的关键参考。

---

## 3. 设计概念（核心思想）

### 3.1 角色分离（Main Agent vs Worker）
- Main Agent：只负责编排（规划、拆解、调度、评审、状态管理）。
- Worker：只负责执行（实现、测试、修复、合并）。
- 关键约束：Main Agent 不直接改 worker-owned 业务代码。

### 3.2 任务文档即契约
- 每个 worker 任务都必须有书面任务文档（目标、范围、非目标、依赖、验证命令、验收标准）。
- 执行前先读契约，不允许自行扩 scope。

### 3.3 小任务切片
- 默认每个任务改动约 3-4 个文件，强调可评审性与低风险合并。
- 超出范围要拆任务，而不是让单任务膨胀。

### 3.4 隔离执行（Git Worktree）
- 每个任务独立分支 + 独立 worktree。
- 统一在仓库根 `.worktrees/` 下管理，避免污染主线目录。

### 3.5 滚动调度与持续补位
- 不是“一次性批处理”，而是“完成一个、解锁一批、立即重排”。
- Claude 版本还强调固定 worker team、按需建任务、避免 worker 空闲。

### 3.6 验证与合并责任归属
- Worker 对其任务从开发到最终 merge 负责到底（含冲突处理与验证重跑）。
- 评审通过不等于完成，必须实际进入 `main` 才算完成。

---

## 4. 组成结构与层级架构

### 4.1 架构分层

1. 规范层（Policy Layer）  
`harness-pro-main`、`harness-pro-worker` 技能文档，定义流程与职责边界。

2. 编排层（Orchestration Layer）  
Main Agent 维护任务图（pending/ready/running/under review/merged/...），做依赖解析与调度。

3. 执行层（Execution Layer）  
Worker 在独立 worktree 完成实现、测试、评审反馈与合并。

4. 代码样例层（Reference Implementation Layer）  
`full-code-0dcaffe:test/task_manager` 展示任务化迭代实践（Task 001~003）。

### 4.2 流程逻辑（简图）

```text
用户目标
  -> Main Agent 最小化设计与任务切分
    -> 任务文档（契约）+ 分支 + worktree
      -> Worker 执行（代码 + 测试 + 验证）
        -> 提交评审 / 处理反馈
          -> 合并到 main
            -> Main Agent 更新任务图并继续调度
```

---

## 5. 实现方案与目的（从历史分支看）

`full-code-0dcaffe` 体现了“任务驱动开发”的落地方式：

- Task 001：建立基础模型与测试
- Task 002：补齐存储能力（add/list/get）
- Task 003：补齐完成状态管理（complete/incomplete/toggle）

目的不是追求一次性大而全，而是：
- 把复杂需求拆成可验证的小增量
- 每个增量都带对应测试
- 通过任务链逐步收敛质量和功能

---

## 6. 功能与代码实现复核

### 6.1 已实现功能（最终快照）
- 任务实体 `Task`：标题、描述、完成状态
- 存储实体 `TaskStore`：
  - `add_task`
  - `list_tasks`
  - `get_task`
  - `mark_task_complete`
  - `mark_task_incomplete`
  - `toggle_task_completion`
- 单元测试共 66 条（Task + Store + Completion）

### 6.2 工具链（示例项目）
- Python + `pyproject.toml`（setuptools）
- `pytest` 测试框架
- Git 任务化迭代（任务文档 + 提交）

### 6.3 我执行的验证结果
- 在临时 worktree 环境执行：`pytest` 全量通过（66 passed）。
- `pip install .` 可安装。
- 安装后以包方式导入存在结构问题：
  - `task_manager.task` 不可导入
  - `task_manager.store` 触发 `task_manager.models` 缺失

结论：**示例代码对“直接源码运行/测试”友好，但包化结构与公开 API 一致性不足。**

---

## 7. 演进观察（非常关键）

历史里出现过两代实现思路：

1. 早期实现（如 `66c576d`）  
- 使用 `task_manager/models.py` + `task_manager/store.py`
- 已实现 JSON 持久化（save/load）与对应测试

2. 后期实现（`05d4c89` 到 `0dcaffe`）  
- 回退为 `task.py` + `store.py` 的简化结构
- 保留 Task 001~003 功能
- 先前的持久化与部分包结构被移除或失配

这说明仓库经历过“重构/回滚式迭代”，最终快照更偏向“流程演示”而非“发布级实现”。

---

## 8. 主要问题与风险清单

1. 代码主体与规范主体分离  
`main` 以流程文档为主，真实实现只在历史分支，学习时需要跨分支。

2. 子模块信息不完整  
`crtCC` / `crtPython` 为 gitlink，但缺失 `.gitmodules`，影响工具链完整复现。

3. 任务状态文档滞后  
`TASKS.md` 中部分状态与提交历史并非完全一致（例如 Task 003 状态描述）。

4. 包结构一致性问题  
测试路径和安装路径依赖不同，包 API 与源码模块边界不一致。

---

## 9. 学习路径（推荐顺序）

1. 先读编排规范  
`harness-pro-main` 与 `harness-pro-worker`，理解“职责边界 + 任务契约”。

2. 再看任务链文档  
`test/task_manager/TASKS.md` 与 `tasks/task-00x-*.md`，理解拆解方法。

3. 再看实现与测试  
先 `task.py` / `store.py`，再看 `tests/` 对应验证逻辑。

4. 最后看提交演进  
重点比较 `66c576d` 与 `0dcaffe`，理解为什么会出现架构切换。

---

## 10. 最终结论

`harness-pro` 当前最有价值的部分是：
- 一套明确、可执行、可扩展的多 Agent 工程协作规范
- 一个可运行的小型 Python 任务管理示例，用于演示任务化迭代

如果你要“学习这个方案”，建议把它当作：
- **流程框架模板**（主价值）  
- **示例代码参考**（辅助价值）

而不是直接当作“可发布产品代码库”。
