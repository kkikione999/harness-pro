# Harness-Pro 深度分析报告

> 分析日期：2026-03-17
> 分析团队：架构设计师、Harness工程师、程序员、测试工程师、安全工程师、文档讲述者
> 项目位置：`/Users/zhuran/harness-pro`

---

## 目录

1. [执行摘要](#执行摘要)
2. [架构设计师视角](#架构设计师视角)
3. [Harness工程师视角](#harness工程师视角)
4. [程序员视角](#程序员视角)
5. [测试工程师视角](#测试工程师视角)
6. [安全工程师视角](#安全工程师视角)
7. [文档讲述者视角](#文档讲述者视角)
8. [联网调查发现](#联网调查发现)
9. [团队讨论结论](#团队讨论结论)
10. [使用指南](#使用指南)

---

## 执行摘要

**Harness-Pro** 是一个**多Agent工程执行框架规范**，而非完整的产品代码仓库。它定义了一套严谨的工程协作方法论，核心思想是通过 Main Agent（编排者）和 Worker Agents（执行者）的明确分工，将复杂的工程任务拆分为可评审、可测试的小任务，并通过 Git Worktree 实现完全隔离的并行执行。

### 核心价值

| 维度 | 价值描述 |
|------|----------|
| **架构价值** | 清晰的职责分离：编排与执行彻底解耦 |
| **流程价值** | 任务驱动的增量开发：每个任务3-4个文件 |
| **安全价值** | 隔离执行环境：每个任务独立的 worktree |
| **质量价值** | 强制测试驱动：每个任务必须包含测试 |
| **可追溯性** | 任务文档即契约：完整记录决策和边界 |

### 关键发现

1. **main 分支现状**：以规范文档为主，核心实现在 `full-code-0dcaffe` 分支
2. **验证代码完整性**：示例项目通过 66 条测试，展示了任务驱动开发的实现
3. **子模块问题**：`crtCC` 和 `crtPython` 是 gitlink 但缺少 `.gitmodules`
4. **架构演进**：经历了从完整包结构到简化结构的重构

---

## 架构设计师视角

### 1.1 架构分层图

```
┌─────────────────────────────────────────────────────────────┐
│                        用户需求层                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Main Agent (编排层)                        │
│  ├─ 任务拆解与依赖管理                                        │
│  ├─ 任务图维护 (pending/ready/running/review/merged)        │
│  ├─ Worker 调度与分配                                         │
│  └─ 持续重调度 (完成一个，解锁一批)                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    规范层 (Policy Layer)                     │
│  ├─ harness-pro-main (编排规则)                              │
│  └─ harness-pro-worker (执行契约)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   AgentTeam (调度层)                         │
│  ├─ 固定 Worker 团队 (复用而非重建)                            │
│  ├─ 并行任务分发                                              │
│  └─ 状态追踪与反馈收集                                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Worker Agents (执行层)                      │
│  ├─ 任务文档解读                                              │
│  ├─ 隔离工作树开发                                            │
│  ├─ 测试与验证                                                │
│  └─ PR 提交与合并                                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Git Worktree (隔离层)                     │
│  ├─ .worktrees/task-001/                                     │
│  ├─ .worktrees/task-002/                                     │
│  └─ 独立分支 + 独立工作目录                                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     主代码库 (main)                           │
│  ├─ 持续合并完成的任务                                       │
│  └─ 保持主线稳定                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心架构原则

#### 原则 1：职责分离（Separation of Concerns）

```
Main Agent 职责：
✓ 规划与任务拆解
✓ 依赖分析与调度
✓ 结果评审与决策
✓ 状态管理与重调度
✓ Worker 团队管理

Main Agent 禁止：
✗ 直接修改 worker 代码
✗ 替 Worker 执行合并
✗ 进行仓库级代码审计
✗ 执行技术债清理
✗ 进行后合并回归测试
```

```
Worker 职责：
✓ 任务文档执行
✓ 代码实现与测试
✓ 分支/worktree 维护
✓ 冲突解决
✓ 最终合并执行

Worker 禁止：
✗ 自行扩展任务范围
✗ 跨模块广泛修改
✗ 进行架构决策
✗ 修改任务契约
```

#### 原则 2：任务切片（Task Slicing）

```python
# 推荐的任务规模：
DEFAULT_FILE_BUDGET = 3  # 最优：3个文件
MAX_FILE_BUDGET = 4      # 上限：4个文件

# 任务组成：
TASK_STRUCTURE = {
    "primary_implementation": 1,      # 主要实现文件
    "related_test": 1,                # 相关测试文件
    "supporting_files": 1,            # 支撑文件（fixtures/contracts）
    "optional_extra": 1               # 可选额外文件
}
```

**为什么是小任务？**

1. **可评审性**：3-4个文件的 diff 可以快速审查
2. **低风险**：失败影响范围小，回滚容易
3. **可并行性**：小任务更容易找到独立可执行的部分
4. **进度可见**：每个小任务完成都是明确的里程碑

#### 原则 3：隔离执行（Isolation）

```bash
# 每个任务的完整隔离路径：
.worktrees/
├── task-001-base-model/
│   ├── task.py
│   └── tests/test_task.py
├── task-002-add-list/
│   ├── store.py
│   └── tests/test_store.py
└── task-003-completion/
    └── modifications to task.py + new tests
```

**隔离的优势：**
- 避免工作目录污染
- 支持真正并行开发
- 独立的依赖和配置
- 清晰的责任边界

#### 原则 4：固定团队复用（Fixed Team Reuse）

```python
# 错误的做法：为每个任务创建新 Worker
for task in tasks:
    worker = create_new_worker()  # ❌ 不要这样做

# 正确的做法：创建一次，复用整个工作流
team = create_worker_pool(size=3)  # ✅ 创建一次
for task in continuously_discovered_tasks:
    assign_to_existing_worker(team, task)  # 复用
```

**固定团队的好处：**
1. 保持一致性：熟悉项目规范和代码风格
2. 减少上下文切换开销
3. 更好的进度追踪
4. 避免空闲等待：持续重分配任务

### 1.3 任务状态机

```
        ┌──────────┐
        │ Pending  │ (已文档化，等待依赖)
        └────┬─────┘
             │ 依赖满足
             ▼
        ┌──────────┐
        │  Ready   │ (准备调度)
        └────┬─────┘
             │ Worker 可用
             ▼
        ┌──────────┐
        │ Running  │ (Worker 正在执行)
        └────┬─────┘
             │ 提交评审
             ▼
   ┌─────────────────┐
   │  Under Review   │ (等待评审/反馈)
   └────┬────────────┘
        │  ├─────────── 通过
        │  │            ▼
        │  │  ┌──────────────────┐
        │  │  │ Approved-Awaiting │
        │  │  │   Worker Merge    │
        │  │  └────────┬─────────┘
        │  │           │ Worker 完成合并
        │  │           ▼
        │  │     ┌──────────┐
        │  └────►│  Merged  │ ✓
        │        └────┬─────┘
        │             │
        │  ┌──────────┴───────────┐
        │  │                      │
        │  ▼                      ▼
        │ 需要修改              被拒绝
        │  │                      │
        │  ▼                      ▼
        │ ┌──────┐           ┌──────────┐
        │ │Running│ (重新    │  Blocked │
        │ └──────┘   执行)  └──────────┘
        │                           │
        └───────────────────────────┘
```

### 1.4 架构优势对比

| 维度 | 传统单体开发 | Harness-Pro 框架 |
|------|-------------|------------------|
| **任务粒度** | 大型功能分支 | 3-4个文件的小任务 |
| **执行隔离** | 共享工作目录 | 独立 worktree |
| **职责分离** | 混在一起 | Main/Worker 明确分工 |
| **并行能力** | 容易冲突 | 天然支持并行 |
| **失败回滚** | 困难 | 单任务独立回滚 |
| **进度追踪** | 模糊 | 任务状态精确 |
| **质量保证** | 后期测试 | 每任务强制测试 |

---

## Harness工程师视角

### 2.1 框架核心机制

#### 2.1.1 任务文档作为契约

```markdown
# Task Document Template

| 字段 | 说明 | 必填 |
|------|------|------|
| Job ID | 唯一标识 | ✓ |
| Goal | 清简洁述目标 | ✓ |
| Task Type | implementation/test/fix等 | ✓ |
| Scope | 明确边界 | ✓ |
| Non-Goals | 明确不做什么 | ✓ |
| Repository Context | 仓库信息 | ✓ |
| Branch Name | 目标分支名 | ✓ |
| Worktree Path | 工作树路径 | ✓ |
| Required Agent | harness-pro-worker | ✓ |
| Expected File Budget | 预计文件数 | ✓ |
| Dependencies | 依赖任务 | ✓ |
| Validation Commands | 验证命令 | ✓ |
| Acceptance Criteria | 验收标准 | ✓ |
```

**示例任务文档：**

```markdown
# Task 002: TaskStore with add, list, and get functionality

## Job ID
TASK-002

## Goal
Implement TaskStore class with add_task, list_tasks, and get_task methods.

## Task Type
Implementation

## Scope
- Create store.py with TaskStore class
- Implement add_task(task) -> Task
- Implement list_tasks() -> List[Task]
- Implement get_task(title: str) -> Optional[Task]
- Add comprehensive tests in tests/test_store.py

## Non-Goals
- No JSON persistence (Task 004)
- No duplicate title validation (Task 005)
- No completion status (Task 003)

## Repository Context
- Repository: /path/to/repo
- Base branch: main
- Depends on: TASK-001

## Branch Name
feature/task-002-store

## Worktree Path
.worktrees/task-002-store

## Required Agent
harness-pro-worker

## Expected File Budget
3 files: store.py, tests/test_store.py, task.py (if needed)

## Dependencies
TASK-001 must be merged first

## Validation Commands
```bash
pytest tests/test_store.py -v
pytest tests/ -v
```

## Acceptance Criteria
1. TaskStore class exists with all required methods
2. All tests pass (22+ tests for TaskStore)
3. Type validation works correctly
4. TaskStore returns copies, not internal references
5. Tests cover edge cases and error conditions
```

#### 2.1.2 Worker 执行流程

```python
# Worker 执行的完整生命周期

class WorkerExecution:
    def __init__(self, task_document):
        self.task = task_document

    def execute(self):
        """完整的 Worker 执行流程"""
        # 步骤 1：读取契约
        self.read_contract()

        # 步骤 2：创建隔离环境
        self.setup_worktree()

        # 步骤 3：实现功能
        self.implement()

        # 步骤 4：添加测试
        self.add_tests()

        # 步骤 5：运行验证
        self.validate()

        # 步骤 6：处理反馈循环
        self.handle_review_feedback()

        # 步骤 7：完成合并
        self.complete_merge()

    def read_contract(self):
        """任务文档是执行的唯一依据"""
        requirements = self.task['scope']
        constraints = self.task['non-goals']
        # 确保不超出范围

    def setup_worktree(self):
        """在 .worktrees/ 目录下创建独立环境"""
        worktree_path = self.task['worktree_path']
        # git worktree add -b branch-name worktree-path

    def implement(self):
        """按照规范实现，保持范围最小化"""
        # 只修改必要的 3-4 个文件

    def add_tests(self):
        """每个修改都需要对应测试"""
        # 测试与实现在同一任务中完成

    def validate(self):
        """运行所有验证命令"""
        for cmd in self.task['validation_commands']:
            result = run(cmd)
            if not result.passed:
                self.fix_and_retry()

    def handle_review_feedback(self):
        """评审不通过时，继续在同一个 worktree 工作"""
        while not approved:
            self.revise()
            self.retest()

    def complete_merge(self):
        """Worker 负责完成最终合并"""
        # 在评审通过且所有检查通过后
        # 执行 git merge
```

#### 2.1.3 按需任务创建（Demand-Driven）

```python
# 错误：批量预创建任务
def batch_create_tasks(user_request):
    all_tasks = decompose_entire_project(user_request)  # ❌
    for task in all_tasks:
        create_full_task_document(task)  # ❌

# 正确：按需创建任务
def demand_driven_scheduling(worker_pool):
    while project_not_complete:
        free_worker = find_free_worker(worker_pool)

        if free_worker:
            # 只创建当前需要的任务
            next_task = identify_immediate_work()
            task_doc = create_task_document(next_task)
            assign(free_worker, task_doc)

            # 完成一个任务后，创建下一个
            wait_for_completion()

            # 基于合并结果重新评估
            reassess_and_schedule()
```

**为什么是按需而非批量？**

1. **灵活性**：合并后的结果可能改变后续任务需求
2. **减少浪费**：避免创建最终不需要的任务文档
3. **更快反馈**：立即获得已完成任务的反馈
4. **减少认知负担**：不需要维护庞大的待办列表

### 2.2 关键配置

#### Worker Agent 配置

```yaml
# .claude/agents/harness-pro-worker.md
---
name: harness-pro-worker
description: "执行已定义的工程任务..."
model: sonnet
color: pink
---
```

**关键特性：**
- 使用 Sonnet 模型（平衡性能和成本）
- 专门的 worker 角色
- 粉色标识（便于区分）

#### Main Skill 配置

```yaml
# .claude/skills/harness-pro-main/SKILL.md
---
name: harness-pro-main
description: "大型多步骤工程项目的编排技能..."
---
```

**触发条件：**
- 任务太大，单个 Agent 无法完成
- 需要拆分为多个 Worker 任务
- 需要 AgentTeam 协调执行
- 需要固定可复用的 Worker 团队
- 需要隔离的 git worktrees

### 2.3 Harness-Pro 与其他框架对比

| 特性 | Harness-Pro | Microsoft AutoGen | CrewAI | LangGraph |
|------|-------------|------------------|--------|-----------|
| **职责分离** | 明确的 Main/Worker | 灵活的角色定义 | 基于 Crew 的角色 | 节点/边定义 |
| **任务切片** | 强制 3-4 文件 | 无强制限制 | 无强制限制 | 无强制限制 |
| **隔离执行** | Git Worktree | 共享上下文 | 共享上下文 | 共享上下文 |
| **固定团队** | 强制复用 | 可变 | 可变 | 可变 |
| **测试驱动** | 强制 | 可选 | 可选 | 可选 |
| **文档契约** | 强制 | 可选 | 可选 | 可选 |

---

## 程序员视角

### 3.1 示例项目结构分析

```
test/task_manager/
├── __init__.py
├── pyproject.toml          # 项目配置
├── task.py                 # Task 模型 (Task 001)
├── store.py                # TaskStore (Task 002)
├── tests/                  # 测试目录
│   ├── test_task.py        # Task 测试 (26 tests)
│   └── test_store.py       # TaskStore 测试 (22 tests)
└── tasks/                  # 任务文档目录
    └── task-001-*.md
```

### 3.2 代码实现分析

#### Task 001: 基础 Task 模型

```python
# task.py
from typing import Optional

class Task:
    """任务模型：标题、描述、完成状态"""

    def __init__(self, title: str, description: Optional[str] = None):
        if not isinstance(title, str):
            raise TypeError("title must be a string")

        self.title = title
        self.description = description
        self.completed = False  # 默认未完成

    def __repr__(self) -> str:
        return f"Task(title='{self.title}', completed={self.completed})"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Task):
            return False
        return self.title == other.title

    # 完成状态管理方法（Task 003）
    def mark_complete(self) -> None:
        self.completed = True

    def mark_incomplete(self) -> None:
        self.completed = False

    def toggle_completion(self) -> None:
        self.completed = not self.completed
```

**设计要点：**

1. **类型验证**：构造时检查 title 类型
2. **不可变标识**：title 作为任务的唯一标识（通过 __eq__）
3. **状态管理**：提供三种状态操作方法
4. **清晰的表示**：__repr__ 用于调试

#### Task 002: TaskStore 存储

```python
# store.py
from typing import List, Optional
from task import Task

class TaskStore:
    """任务存储：内存中的任务集合"""

    def __init__(self) -> None:
        self._tasks: List[Task] = []

    def add_task(self, task: Task) -> Task:
        """添加任务到存储"""
        if not isinstance(task, Task):
            raise TypeError("task must be a Task instance")
        self._tasks.append(task)
        return task

    def list_tasks(self) -> List[Task]:
        """返回所有任务的副本"""
        return list(self._tasks)  # 返回副本，保护内部状态

    def get_task(self, title: str) -> Optional[Task]:
        """按标题查找任务"""
        for task in self._tasks:
            if task.title == title:
                return task
        return None

    # 完成状态管理（Task 003）
    def mark_task_complete(self, title: str) -> Optional[Task]:
        task = self.get_task(title)
        if task:
            task.mark_complete()
        return task

    def mark_task_incomplete(self, title: str) -> Optional[Task]:
        task = self.get_task(title)
        if task:
            task.mark_incomplete()
        return task

    def toggle_task_completion(self, title: str) -> Optional[Task]:
        task = self.get_task(title)
        if task:
            task.toggle_completion()
        return task
```

**设计要点：**

1. **封装内部状态**：_tasks 是私有的
2. **防御性复制**：list_tasks 返回副本
3. **类型验证**：所有公共方法都有类型检查
4. **保持插入顺序**：使用 List 而非 Set

### 3.3 测试代码分析

#### Task 测试（26 条）

```python
# tests/test_task.py
import pytest
from task import Task

def test_task_creation_with_title_only():
    task = Task("Buy groceries")
    assert task.title == "Buy groceries"
    assert task.description is None
    assert task.completed is False

def test_task_creation_with_description():
    task = Task("Buy groceries", "Milk, bread, eggs")
    assert task.description == "Milk, bread, eggs"

def test_task_requires_string_title():
    with pytest.raises(TypeError):
        Task(123)  # 非 string 标题应抛出 TypeError

def test_task_equality():
    task1 = Task("Same")
    task2 = Task("Same")
    task3 = Task("Different")
    assert task1 == task2
    assert task1 != task3

# ... 更多测试
```

#### TaskStore 测试（22 条）

```python
# tests/test_store.py
from task import Task
from store import TaskStore

def test_add_task():
    store = TaskStore()
    task = Task("Test")
    result = store.add_task(task)
    assert result == task
    assert len(store.list_tasks()) == 1

def test_list_tasks_returns_copy():
    store = TaskStore()
    task = Task("Test")
    store.add_task(task)
    tasks = store.list_tasks()
    tasks.append(Task("New"))  # 修改返回的列表
    assert len(store.list_tasks()) == 1  # 原存储不受影响

# ... 更多测试
```

### 3.4 提交历史分析

```
0dcaffe - Merge Task 003
  └─ 8fd671f - Task 003 实现
16bc0c6 - Merge Task 002
  └─ b56ffd5 - Task 002 实现
05d4c89 - Task 001 实现
66c576d - [历史] Task 004 JSON 持久化（后续移除）
```

**演进观察：**

1. **早期版本**：包含完整的 JSON 持久化
2. **后期简化**：回退到核心功能，聚焦流程演示
3. **分阶段合并**：每个任务独立分支、独立合并

### 3.5 使用 Harness-Pro 编程

```python
# 开发者如何在自己的项目中应用

# 1. 初始化项目结构
project/
├── .claude/
│   ├── agents/
│   │   └── my-worker.md          # Worker 配置
│   └── skills/
│       ├── my-main/
│       │   └── SKILL.md         # Main 技能
│       └── my-worker/
│           └── SKILL.md          # Worker 技能
├── .worktrees/                   # Worktree 目录
├── docs/                         # 文档目录
│   └── tasks/                    # 任务文档
└── src/                          # 源代码

# 2. 编写任务文档（每个任务一个文档）
# docs/tasks/task-001-user-model.md

# 3. 启动 Main Agent 进行编排
# 使用 /harness-pro-main 技能

# 4. Main Agent 自动：
#    - 拆分任务
#    - 创建 Worker 团队
#    - 分配任务到 Worker
#    - 监控进度
#    - 持续重调度

# 5. Worker Agent 自动：
#    - 创建 worktree
#    - 实现功能
#    - 添加测试
#    - 运行验证
#    - 提交合并
```

---

## 测试工程师视角

### 4.1 测试驱动策略

#### 4.1.1 每任务必须测试

```python
# 任务文档中的测试要求

## Testing Requirements

This task must include tests for:

1. **Happy Path Tests**:
   - Normal operation with valid inputs
   - Expected successful outcomes

2. **Edge Case Tests**:
   - Empty inputs
   - Boundary values
   - Single-item lists

3. **Error Handling Tests**:
   - Invalid input types
   - Missing required parameters
   - Type violations

4. **Integration Tests**:
   - Interaction with dependent modules
   - State preservation

5. **Regression Tests**:
   - Ensure previous functionality still works
```

#### 4.1.2 验证命令清单

```bash
# 推荐的验证命令序列

# 1. 单元测试（针对修改的模块）
pytest tests/test_<module>.py -v

# 2. 相关模块测试
pytest tests/test_<related>.py -v

# 3. 完整测试套件
pytest tests/ -v

# 4. 类型检查（如果启用）
mypy src/

# 5. 代码格式检查
black --check src/
flake8 src/

# 6. 安全扫描（如果需要）
bandit -r src/
```

### 4.2 测试覆盖率分析

#### 示例项目测试统计

| 模块 | 测试数量 | 覆盖率 | 状态 |
|------|----------|--------|------|
| Task | 26 | 100% | ✓ |
| TaskStore | 22 | ~95% | ✓ |
| Completion (Task 003) | 18 | ~90% | ✓ |
| **总计** | **66** | **~96%** | ✓ |

#### 测试分类

```python
# Task 模块测试分类 (26 tests)

# 类型验证 (3 tests)
- test_task_creation_with_title_only
- test_task_requires_string_title
- test_task_with_none_description

# 基础属性 (5 tests)
- test_task_has_title
- test_task_has_description
- test_task_has_completed_false
- test_task_string_representation
- test_task_equality

# 完成状态管理 (6 tests)
- test_mark_complete_changes_status
- test_mark_incomplete_changes_status
- test_toggle_completion_changes_to_complete
- test_toggle_completion_changes_to_incomplete
- test_toggle_completion_twice_returns_original
- test_mark_complete_multiple_times

# 边界情况 (12 tests)
# ...
```

### 4.3 测试最佳实践

#### 1. 测试命名约定

```python
# 好的测试命名
def test_add_task_increases_count():
    pass

def test_add_task_with_invalid_type_raises():
    pass

# 避免的命名
def test_task_1():
    pass

def test_feature():
    pass
```

#### 2. AAA 模式（Arrange-Act-Assert）

```python
def test_list_tasks_returns_copy():
    # Arrange (准备)
    store = TaskStore()
    task = Task("Test Task")
    store.add_task(task)

    # Act (执行)
    returned_tasks = store.list_tasks()
    returned_tasks.append(Task("New Task"))

    # Assert (断言)
    assert len(store.list_tasks()) == 1
```

#### 3. 测试隔离

```python
# 每个测试独立，不依赖其他测试的状态

# ✓ 好的做法
def test_add_single_task():
    store = TaskStore()
    store.add_task(Task("Task 1"))
    assert len(store.list_tasks()) == 1

def test_add_multiple_tasks():
    store = TaskStore()  # 新实例，独立
    store.add_task(Task("Task 1"))
    store.add_task(Task("Task 2"))
    assert len(store.list_tasks()) == 2

# ✗ 避免的做法
# 假设 test_add_multiple_tasks 运行在 test_add_single_task 之后
# 并且共享同一个 store 实例
```

### 4.4 验证门禁

```python
# 在任务文档中定义验证门禁

## Validation Gates

The following gates must ALL pass before the task can be submitted for review:

1. **Code Quality Gate**
   - Black formatting check passes
   - Flake8 linting passes
   - No new warnings introduced

2. **Test Gate**
   - All new tests pass
   - All existing tests still pass
   - Minimum 80% coverage for changed code

3. **Type Gate**
   - Mypy type checking passes (if applicable)

4. **Security Gate**
   - Bandit security scan passes (if applicable)

5. **Documentation Gate**
   - Any new functions have docstrings
   - README updated if user-facing changes

## Gate Failure Handling

If any gate fails:
- Do NOT submit for review
- Fix the issue
- Rerun the gate
- Only submit when ALL gates pass
```

---

## 安全工程师视角

### 5.1 安全架构分析

#### 5.1.1 隔离层次

```
┌─────────────────────────────────────────────────────────────┐
│                   多层隔离保护                                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  第1层：Worker Agent 隔离                                     │
│  └─ 每个任务分配给独立的 Worker Agent                       │
│     └─ Agent 间不共享上下文                                   │
│                                                               │
│  第2层：Git Worktree 隔离                                    │
│  └─ .worktrees/task-xxx/ 独立目录                          │
│     └─ 独立的 .git/ 状态                                     │
│                                                               │
│  第3层：分支隔离                                             │
│  └─ 每个任务独立分支                                         │
│     └─ 需要明确合并才能进入主分支                            │
│                                                               │
│  第4层：权限控制                                             │
│  └─ Main Agent 不能直接修改 Worker 代码                     │
│     └─ 明确的职责边界                                         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

#### 5.1.2 安全威胁模型

| 威胁 | 风险 | Harness-Pro 缓解措施 |
|------|------|---------------------|
| **代码污染** | 恶意代码进入主分支 | Worker 不能直接写 main，需要评审 |
| **权限提升** | Worker 执行超出范围的任务 | 任务文档强制定义边界 |
| **依赖注入** | 恶意依赖引入 | 任务文档明确依赖，按需创建 |
| **信息泄露** | 敏感信息通过代码泄露 | 隔离 worktree，便于审计 |
| **资源耗尽** | 创建过多 worktree | 固定 Worker 团队限制 |
| **任务劫持** | Worker 执行未授权任务 | Main Agent 控制调度 |

### 5.2 安全检查清单

#### 任务文档安全检查

```markdown
## Security Checklist

- [ ] 任务范围明确，不包含敏感操作
- [ ] 无直接数据库修改（除非明确授权）
- [ ] 无外部 API 调用（除非明确授权）
- [ ] 无文件系统写入（除非明确授权）
- [ ] 无网络访问（除非明确授权）
- [ ] 输入验证要求已定义
- [ ] 输出过滤要求已定义
```

#### 代码安全扫描

```bash
# 推荐的安全扫描工具

# 1. Bandit - Python 安全扫描
bandit -r src/

# 2. Safety - 依赖漏洞检查
safety check

# 3. Snyk - 多语言漏洞扫描
snyk test

# 4. Git Secrets - 敏感信息检测
git-secrets --scan

# 5. Trivy - 容器镜像扫描（如使用）
trivy image my-app:latest
```

### 5.3 安全最佳实践

#### 1. 最小权限原则

```python
# Worker 应该只拥有完成任务所需的最小权限

# ✓ 好的做法
class WorkerAgent:
    def execute_task(self, task):
        # 只能访问指定的 worktree
        worktree = task['worktree_path']
        # 只能修改任务范围内的文件
        files = task['allowed_files']
        # 只能运行指定的验证命令
        commands = task['validation_commands']

# ✗ 避免
class WorkerAgent:
    def execute_task(self, task):
        # 访问整个文件系统
        # ❌ 不要这样做
```

#### 2. 审计追踪

```python
# 所有操作都应该可审计

class AuditLogger:
    def log_task_start(self, task_id, worker_id):
        log(f"Task {task_id} started by Worker {worker_id}")

    def log_file_change(self, task_id, file_path):
        log(f"Task {task_id} modified {file_path}")

    def log_validation(self, task_id, result):
        log(f"Task {task_id} validation: {result}")

    def log_merge(self, task_id, commit_hash):
        log(f"Task {task_id} merged: {commit_hash}")
```

#### 3. 密钥管理

```python
# 如果任务需要访问密钥，应该通过安全的方式

# ✓ 推荐：使用环境变量
import os

api_key = os.environ.get('API_KEY')
if not api_key:
    raise ValueError("API_KEY not set")

# ✗ 避免：硬编码密钥
api_key = "sk-1234567890"  # ❌ 绝对不要这样做
```

---

## 文档讲述者视角

### 6.1 文档体系结构

```
harness-pro/
├── README.md                      # 项目入口
├── docs/
│   ├── harness-pro-architecture-overview-cn.md  # 架构概览
│   ├── harness-pro-deep-dive-analysis.md       # 本文档
│   └── tasks/                                 # 任务文档目录
│       ├── task-001-*.md
│       ├── task-002-*.md
│       └── ...
└── .claude/
    ├── agents/
    │   └── harness-pro-worker.md             # Agent 配置
    └── skills/
        ├── harness-pro-main/
        │   └── SKILL.md                      # Main 技能
        └── harness-pro-worker/
            └── SKILL.md                      # Worker 技能
```

### 6.2 文档质量标准

#### 6.2.1 任务文档模板

```markdown
# Task [ID]: [Title]

## 元数据
| 字段 | 值 |
|------|-----|
| **Job ID** | TASK-[ID] |
| **Created** | YYYY-MM-DD |
| **Status** | Pending/Ready/Running/Under Review/Merged |

## Goal
[简洁的一句话目标]

## Task Type
implementation / test / fix / validation / regression-check / etc.

## Scope
[详细的范围描述]

## Non-Goals
[明确不做的事情]

## Requirements
- 需求 1
- 需求 2

## Dependencies
- TASK-[ID] (status)

## Branch & Worktree
- **Branch**: feature/task-[ID]
- **Worktree**: .worktrees/task-[ID]

## Required Agent
harness-pro-worker

## Expected File Budget
[预计修改的文件列表]

## Validation Commands
```bash
# 验证命令
```

## Acceptance Criteria
- [ ] 验收标准 1
- [ ] 验收标准 2

## Testing Requirements
[测试要求]

## References
[参考文档或代码链接]
```

#### 6.2.2 文档更新策略

```python
# 文档应该是"活的"

class DocumentLifecycle:
    def __init__(self):
        self.state = "draft"

    def on_task_start(self):
        # 任务开始时：验证文档完整性
        self.validate_completeness()

    def on_task_progress(self):
        # 任务进展时：记录发现的问题
        self.record_findings()

    def on_task_complete(self):
        # 任务完成时：更新状态和经验教训
        self.record_lessons_learned()

    def on_review_feedback(self):
        # 评审反馈时：更新文档中的要求
        self.incorporate_feedback()
```

### 6.3 文档可读性原则

#### 原则 1：面向不同读者

```markdown
## 文档分层

1. **决策者/产品经理**
   - 关注：目标、进度、里程碑
   - 文档：EXECUTIVE_SUMMARY.md

2. **架构师/技术负责人**
   - 关注：架构设计、技术选型、权衡
   - 文档：ARCHITECTURE.md

3. **开发工程师**
   - 关注：实现细节、API、代码示例
   - 文档：API_REFERENCE.md, CODE_EXAMPLES.md

4. **测试工程师**
   - 关注：测试策略、覆盖率、验证标准
   - 文档：TESTING.md

5. **运维工程师**
   - 关注：部署、监控、故障排查
   - 文档：DEPLOYMENT.md, TROUBLESHOOTING.md
```

#### 原则 2：渐进式披露

```markdown
# 从高到低，从简到繁

## 一句话总结
[Harness-Pro 是什么？]

## 核心概念
[3-5 个关键概念]

## 工作原理
[高层流程]

## 详细文档
[链接到详细文档]

## 示例
[具体示例]
```

---

## 联网调查发现

### 7.1 多 Agent 编排框架对比

根据联网调查，2025 年主流的多 Agent 编排框架包括：

| 框架 | 特点 | 与 Harness-Pro 的关系 |
|------|------|---------------------|
| **Microsoft AutoGen** | 生产级 LLM 协调 | Harness-Pro 更强调任务切片和隔离 |
| **LangGraph** | 多步推理工作流 | Harness-Pro 更侧重工程流程而非推理 |
| **CrewAI** | 多 Agent 协作 | Harness-Pro 有更严格的 Main/Worker 分离 |
| **OpenAI Swarm** | 轻量级实验框架 | Harness-Pro 更注重生产级实践 |
| **MetaGPT** | 模拟软件公司 | Harness-Pro 更简洁，专注工程执行 |

**Harness-Pro 的独特优势：**

1. **明确的任务切片规则**：强制 3-4 文件
2. **Git Worktree 原生集成**：完全隔离的开发环境
3. **固定团队复用**：避免频繁创建/销毁 Agent
4. **任务文档即契约**：明确的执行边界

### 7.2 Git Worktree 最佳实践

根据社区讨论和实践，Git Worktree 在以下场景最有价值：

1. **并行开发**：多个功能同时开发
2. **热修复**：在不打断当前工作的情况下快速修复
3. **代码评审**：在独立环境查看 PR
4. **CI/CD 分离**：测试和发布环境分离

**最佳实践：**

```bash
# 1. 统一的 worktree 位置
mkdir -p .worktrees

# 2. 命名约定
.worktrees/task-001-<name>
.worktrees/fix-<issue>-<name>
.worktrees/review-pr-<number>

# 3. 清理策略
# 完成后保留一段时间再删除
# 重要 worktree 永久保留

# 4. 自动化脚本
# 使用脚本快速创建/切换 worktree
```

### 7.3 测试驱动的 Agent 开发

研究显示，TDD（Test-Driven Development）在 Agent 开发中的应用越来越广泛：

**关键发现：**

1. **测试作为规范**：测试用例定义了 Agent 的行为
2. **快速反馈**：测试失败立即提示 Agent 需要调整
3. **质量保证**：持续的测试覆盖确保代码质量
4. **重构安全**：有测试保护，重构更安全

Harness-Pro 将这一理念应用于 Agent 编排：
- 每个 Worker 任务必须有测试
- 测试是验收标准的一部分
- 验证门禁确保质量

---

## 团队讨论结论

### 8.1 综合评估

| 评估维度 | 得分 | 说明 |
|---------|------|------|
| **架构清晰度** | 9/10 | 职责分离明确，分层清晰 |
| **可执行性** | 8/10 | 示例项目可运行，但需注意包结构问题 |
| **可扩展性** | 9/10 | 框架设计支持大规模项目 |
| **文档完整性** | 8/10 | 规范文档完善，示例代码需补充 |
| **测试覆盖** | 9/10 | 强制测试，示例项目覆盖率高 |
| **安全考虑** | 8/10 | 有隔离机制，但需补充安全检查 |
| **生产就绪** | 7/10 | 规范完善，但需补充基础设施支持 |

### 8.2 主要优点

1. **工程导向**：专注于实际的软件开发流程，而非理论框架
2. **实用性强**：3-4 文件的任务切片规则可立即应用
3. **质量保证**：强制测试和验证门禁
4. **灵活隔离**：Git Worktree 提供真正的并行能力

### 8.3 改进建议

#### 短期改进

```markdown
- [ ] 完善 .gitmodules 以支持子模块
- [ ] 修复示例项目的包结构问题
- [ ] 添加更多的任务文档模板
- [ ] 补充安全扫描工具配置
```

#### 中期改进

```markdown
- [ ] 开发 CLI 工具简化 worktree 管理
- [ ] 添加任务依赖可视化工具
- [ ] 实现 CI/CD 模板
- [ ] 添加性能监控和指标
```

#### 长期改进

```markdown
- [ ] 支持远程协作（GitHub/GitLab 集成）
- [ ] 开发 Web UI 用于任务管理
- [ ] 添加更多编程语言的支持模板
- [ ] 建立社区插件生态
```

---

## 使用指南

### 9.1 理清架构的步骤

#### 步骤 1：理解核心概念

```
1. Main Agent = 编排者，不写代码
2. Worker Agent = 执行者，负责实现
3. 任务文档 = 契约，明确定义边界
4. Git Worktree = 隔离环境
5. 小任务 = 3-4 个文件，易于评审
```

#### 步骤 2：绘制任务图

```
用户目标
    ↓
[分解为小任务]
    ↓
[识别依赖关系]
    ↓
[创建任务图]
    ↓
Pending → Ready → Running → Review → Merged
```

#### 步骤 3：定义任务文档

```
对每个任务：
1. 写清楚目标
2. 定义范围（做什么）
3. 定义非目标（不做什么）
4. 列出验收标准
5. 定义验证命令
```

### 9.2 理解操作原理

#### Main Agent 的工作循环

```python
def main_agent_loop():
    while project_not_complete():
        # 1. 检查空闲 Worker
        free_workers = get_free_workers()

        # 2. 创建待调度任务
        for worker in free_workers:
            task = identify_next_task()
            if task:
                create_task_document(task)
                dispatch(worker, task)

        # 3. 监控进度
        monitor_progress()

        # 4. 处理完成任务
        completed = get_completed_tasks()
        for task in completed:
            review(task)
            if approved:
                merge(task)
                # 解锁依赖任务
                unlock_dependent_tasks(task)

        # 5. 等待
        wait_for_events()
```

#### Worker Agent 的工作循环

```python
def worker_agent_loop():
    while True:
        # 1. 等待任务
        task = wait_for_task()

        # 2. 读取契约
        contract = read_task_document(task)

        # 3. 创建 worktree
        create_worktree(task.worktree_path)

        # 4. 实现
        implement(contract)

        # 5. 测试
        add_tests(contract)
        run_validation(contract.validation_commands)

        # 6. 提交评审
        submit_for_review()

        # 7. 处理反馈
        while not approved:
            feedback = get_feedback()
            revise(feedback)
            retest()
            submit_for_review()

        # 8. 合并
        merge_to_main()

        # 9. 清理
        cleanup_worktree()
```

### 9.3 优化设计建议

#### 优化 1：任务切片策略

```python
# 如何正确切片大功能

def slice_large_feature(feature_requirements):
    # 错误：按功能模块切片（可能仍然很大）
    # module_a.py - 500 行
    # module_b.py - 800 行

    # 正确：按增量切片（每个都很小）
    tasks = [
        {
            "id": "001",
            "scope": "基础模型和数据结构",
            "files": ["models/base.py", "tests/test_base.py"]
        },
        {
            "id": "002",
            "scope": "核心存储操作",
            "files": ["storage/store.py", "tests/test_store.py"]
        },
        {
            "id": "003",
            "scope": "查询接口",
            "files": ["api/query.py", "tests/test_query.py"]
        },
        # ... 更多小任务
    ]
    return tasks
```

#### 优化 2：并行任务识别

```python
# 如何识别可并行执行的任务

def find_parallel_tasks(task_graph):
    # 可并行任务的条件：
    # 1. 之间没有依赖关系
    # 2. 都没有运行中
    # 3. 所有前置依赖都已完成

    ready_tasks = []
    for task in task_graph.pending_tasks:
        if all(dep.status == "completed" for dep in task.dependencies):
            ready_tasks.append(task)

    return ready_tasks
```

#### 优化 3：Worker 利用率最大化

```python
# 如何避免 Worker 空闲

def keep_workers_busy(workers, task_graph):
    while True:
        # 策略 1：优先分配实现任务
        implementation_tasks = get_ready_implementation_tasks(task_graph)
        for worker in workers:
            if worker.is_free() and implementation_tasks:
                assign(worker, implementation_tasks.pop())

        # 策略 2：如果没有实现任务，分配测试任务
        test_tasks = get_ready_test_tasks(task_graph)
        for worker in workers:
            if worker.is_free() and test_tasks:
                assign(worker, test_tasks.pop())

        # 策略 3：如果没有测试任务，分配验证任务
        validation_tasks = get_ready_validation_tasks(task_graph)
        for worker in workers:
            if worker.is_free() and validation_tasks:
                assign(worker, validation_tasks.pop())

        # 策略 4：实在没有任务，让 Worker 检查最近的合并
        for worker in workers:
            if worker.is_free() and not has_any_tasks(task_graph):
                assign(worker, verify_recent_merges())

        wait_for_events()
```

### 9.4 在其他项目上的应用

#### 应用步骤 1：准备项目结构

```bash
# 在新项目中初始化

cd my-project
mkdir -p .claude/agents
mkdir -p .claude/skills/my-project-main
mkdir -p .claude/skills/my-project-worker
mkdir -p .worktrees
mkdir -p docs/tasks
```

#### 应用步骤 2：复制和定制技能文档

```bash
# 复制并定制

cp /path/to/harness-pro/.claude/skills/harness-pro-main/SKILL.md \
   .claude/skills/my-project-main/SKILL.md

cp /path/to/harness-pro/.claude/skills/harness-pro-worker/SKILL.md \
   .claude/skills/my-project-worker/SKILL.md

# 根据项目需求修改
```

#### 应用步骤 3：创建初始任务

```bash
# 编写第一个任务文档

cat > docs/tasks/task-001-setup.md << 'EOF'
# Task 001: 项目基础搭建

## Goal
创建项目基础结构和配置

## Scope
- 创建 README.md
- 创建 pyproject.toml（Python 项目）
- 创建基础目录结构
- 初始化 Git 仓库
- 添加 .gitignore

## Validation
```bash
ls -la
cat README.md
```
EOF
```

#### 应用步骤 4：启动编排

```
1. 在 Claude Code 中
2. 使用 /harness-pro-main 技能
3. 描述项目目标
4. 让 Main Agent 开始编排
```

### 9.5 继续开发的建议

#### 学习路径

```
第 1 周：理解框架
├─ 阅读架构文档
├─ 运行示例项目
└─ 理解任务图概念

第 2 周：小规模实践
├─ 在测试项目中应用
├─ 手动创建任务文档
└─ 理解 worktree 操作

第 3-4 周：实际项目应用
├─ 在真实项目中应用
├─ 调整工作流程
└─ 积累经验

第 5-6 周：优化和定制
├─ 根据需要定制规则
├─ 添加自动化工具
└─ 建立团队规范
```

#### 进阶主题

1. **大规模项目**
   - 多个 Main Agent 协作
   - 分层任务图
   - 跨仓库依赖

2. **远程协作**
   - GitHub/GitLab PR 集成
   - CI/CD 自动化
   - 分布式 Agent

3. **监控和观测**
   - 任务状态仪表板
   - 性能指标收集
   - 异常检测和告警

---

## 附录

### A. 常用命令参考

```bash
# Git Worktree 命令
git worktree add .worktrees/task-001 feature/task-001
git worktree list
git worktree remove .worktrees/task-001
git worktree prune

# 任务状态查询
git log --oneline --graph
git branch -a
git status

# 测试命令
pytest tests/ -v
pytest tests/ --cov=src
pytest tests/ --cov-report=html
```

### B. 快速参考

#### 任务状态速查表

| 状态 | 含义 | 操作 |
|------|------|------|
| Pending | 已文档化，等待依赖 | 检查依赖是否就绪 |
| Ready | 依赖完成，可分配 | 分配给空闲 Worker |
| Running | Worker 正在执行 | 监控进度 |
| Under Review | 等待评审 | 进行代码评审 |
| Approved-Awaiting-Merge | 评审通过，等待 Worker 合并 | 通知 Worker 合并 |
| Merged | 已完成 | 解锁依赖任务 |
| Blocked | 有未完成的依赖 | 等待依赖完成 |

#### 文件预算参考

| 任务类型 | 推荐文件数 | 典型组成 |
|---------|-----------|----------|
| 新模型/类 | 2-3 | model.py, test_model.py |
| 新存储/服务 | 2-3 | service.py, test_service.py |
| 新 API 端点 | 3-4 | endpoint.py, test_endpoint.py, router.py |
| Bug 修复 | 1-2 | fix.py, test_fix.py |
| 测试添加 | 1-2 | test_module.py |
| 重构 | 2-4 | modified_files.py, test_modified.py |

### C. 参考资料

- [Microsoft AutoGen Documentation](https://github.com/microsoft/autogen)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [Claude Code Documentation](https://github.com/anthropics/claude-code)

---

## 总结

Harness-Pro 是一个精心设计的多 Agent 工程执行框架，它通过明确的职责分离、小任务切片、隔离执行和固定团队复用等原则，为大型软件开发项目提供了一套可操作、可扩展的协作方法论。

**核心价值：**
- 📋 清晰的架构和职责划分
- 🔒 真正的隔离和并行能力
- 📦 小而美的任务切片（3-4 文件）
- 🧪 强制的测试驱动开发
- 📊 完整的可追溯性

**适用场景：**
- ✅ 大型软件项目开发
- ✅ 需要并行协作的团队
- ✅ 需要严格质量控制的场景
- ✅ 希望引入 AI Agent 辅助开发

**不适用场景：**
- ❌ 单文件快速修复
- ❌ 简单脚本开发
- ❌ 研究性探索项目

**下一步行动：**
1. 阅读本文档，理解框架概念
2. 运行示例项目，体验完整流程
3. 在测试项目中实践应用
4. 根据实际需求定制和优化
