# CLAUDE.md

本文档为 Claude Code (claude.ai/code) 在本仓库中的工作提供指导。

## 项目概述

本仓库是 **Harness Engineering** 的核心文档和参考实现库。

**Harness Engineering** 是一套让 AI Agent 能够自主、可控、高质量完成软件需求的方法论。其核心原则是：

> **Agent = Model + Harness**。Harness 提供模型以外的一切：上下文管理、质量控制、反馈循环、执行环境。

**终极目标**：人提出需求，AI 端到端完成全部流程，无需人工干预。

## 核心概念

### 两大控制机制

| 机制 | 方向 | 作用 |
|------|------|------|
| **前馈 (Feedforward)** | 行动前 | 预见问题，引导行为 |
| **反馈 (Feedback)** | 行动后 | 检测漂移，自我纠正 |

### 三层质量保障

| 层级 | 保障内容 | 验证方式 |
|------|----------|----------|
| **Golden Principles** | 代码不变量（架构、模式） | Linter + 结构测试（P0 阻塞合并） |
| **Evals** | Agent 行为正确性 | 回归测试 + 能力基准 |
| **GC Engine** | 技术债务 + 漂移 | 每周自动开重构 PR |

## 完整工作流

```
用户提出需求
    ↓
[harness-pro-decompose-requirement] ← 唯一入口，简单修改走 fast path
    ↓ 用户确认一次（scope + spec + 验收标准）
[harness-pro-create-plan]           ← 纯机械化，读 spec → 探索代码 → 拆任务
    ↓
[harness-pro-execute-task] ← [harness-pro-test-driven-development] RED→GREEN→REFACTOR
    │           ← [harness-pro-systematic-debugging] 遇阻时
    │                       ↑
    │                  milestone review（独立 subagent）
    ↓
[harness-pro-complete-work]         ← 新鲜验证 + 文档维护检查 + 集成
    ↓
Done
```

**关键**：用户只参与 decompose-requirement 的确认（单次交接）。后续全 AI 自主执行。非重大问题不传递。

### Fast Path

简单修改不走全流程。AI自行判断升降级：
- 简单修改 → 直接 TDD + complete-work
- 发现复杂度超预期 → 升级到 decompose-requirement

### DAG 多 Feature 执行

当需求拆解为多个 atomic feature 时：
- DAG 在拆解阶段画好，不在执行中动态调整
- 无依赖的 feature 并行执行
- 有依赖的等前置完成
- 失败则依赖链暂停，回传用户

## Skill 架构（6个）

| Skill | 职责 | 产出 | 替代 |
|-------|------|------|------|
| **harness-pro-decompose-requirement** | 需求拆解 + spec + DAG | `features/{id}/index.md` | brainstorming, using-superpowers |
| **harness-pro-create-plan** | 生成实施路径 | `features/{id}/plan.md` | writing-plans, plan-feature |
| **harness-pro-execute-task** | TDD执行 + DAG编排 + milestone review | 代码 + 测试 | subagent-driven-dev, execute-plan, executing-plans |
| **harness-pro-complete-work** | 验证 + 文档维护 + 集成 | 合并/PR/清理 | finishing-branch, verification-before-completion |
| **harness-pro-test-driven-development** | RED→GREEN→REFACTOR | 测试代码（由 execute-task 调用） | 不变 |
| **harness-pro-systematic-debugging** | 根因调查→修复 | 根因分析+修复（由 execute-task 调用） | 不变 |

### 质量体系

| 层 | 机制 | 覆盖范围 |
|---|---|---|
| **微观** | TDD（RED→GREEN→REFACTOR） | 每行代码正确性 |
| **宏观** | Milestone Review（独立 subagent） | spec合规、架构、测试完整性 |
| **机械** | P0 Linter | 依赖方向、命名、文件大小 |
| **持续** | GC Engine | 周期扫描技术债+漂移 |

## Feature 设计

### Feature 是 atomic 的开发单元

Feature 是面向开发的最小单元。atomic 的含义：

- **边界清晰**：不产生隐式的跨边界副作用
- **可独立验证**：可以独立实现、独立验收
- **不污染其他 feature**：状态和变更不会影响其他 feature

多个 atomic feature 通过 DAG 组合成复杂功能。

### Feature 的职责

- **快速认知**：AI 通过 feature 快速了解整个产品的设计理念
- **定位锚点**：通过 feature 找到对应的 plan 和 code_scope
- **边界约束**：每个 feature 定义自己的 scope、依赖关系

### Feature 结构

每个 feature 包含：

```
{feature-name}/
├── index.md           # Feature 定义：边界、职责、依赖
└── code_scope.md     # 代码入口区域 + 命名模式（轻量指向性）
```

**code_scope 是轻量的、指向性的**，不是完整地图。

- `app/lib/features/{feature}/` — 入口区域
- `**/*_{feature}*.dart` — 命名模式

AI 由此进入，自己探索、自己理解、自己把理解写入工作文件夹。

### Feature 对应关系

- **1 feature : N plan**（不同阶段的实现计划）
- 但任意时刻，**最多 1 个 active plan**

## Plan 和 ExecPlan

### 三环节边界

| 环节 | 输入 | 输出 | 职责 |
|------|------|------|------|
| **需求拆解** | 用户需求 | atomic feature | 确定边界、验收标准、依赖关系 |
| **Plan** | atomic feature | plan.md | 确定改哪些文件、按什么顺序、如何验证 |
| **Exec** | plan.md | 实现代码 | 按计划执行，补充实施细节 |

### Plan agent 与 Worker agent

- **Plan agent**：负责写 plan.md，读代码结构 + 关键逻辑签名，产出到**文件+函数/类级别**，**不到行级**
- **Worker agent**：负责执行 plan，补充实施细节；遇到计划偏离可就地调整，但影响整体路径时必须回传 Plan agent

### 设计原则

- 如果 feature 足够 atomic：Plan == ExecPlan，一个文档搞定
- 如果 feature 较大：Plan 定义里程碑，ExecPlan 负责调度执行

### Plan（当量小时等于 ExecPlan）

```
{feature}/plan.md：

## Context
前置条件和上下文

## Milestones
每个 milestone：
  - scope
  - acceptance criteria
  - stop-and-fix 条件

## Validation
验证命令

## Progress（活文档）
实时更新的进度状态

## Decision Log（活文档）
记录所有决策及原因

## Surprises & Discoveries（活文档）
实施中的意外发现
```

### 反馈回路

```
Worker 遇到问题
    ↓
尝试自己解决
    ↓
如果影响 milestone 整体路径 → 回传 Plan agent 更新 plan.md
    ↓
Worker 继续执行
```

## 需求拆解 Skill

**把用户需求转换为 atomic feature** 的 skill。

### 两条路径

- **Fast path**：需求明显命中已有 feature → 直接定位该 feature，评估是修改还是子任务
- **Full path**：需求涉及新能力、跨 feature 或边界不清晰 → 走完整拆解流程

### 用户澄清循环（核心：让 AI 暴露理解）

1. AI 先自主推断用户的真实意图、隐含假设和边界
2. **将推断结果明确展示给用户**（包括 AI 对现有产品和 feature 的理解）
3. 用户确认或纠正，来回对话直到意图清晰

**关键**：AI 要主动暴露自己对需求的理解，包括对现有 feature 的关联判断。如果理解有偏差，用户能立即纠正。

### 验收标准

- AI 基于对 feature 的理解，**主动提出验收标准**
- 用户确认、修改或拒绝
- 如果用户的验收标准不完善或不正确，AI 应大胆质疑并指正

### Atomic Feature 产物格式

```yaml
id: string                    # 唯一标识
name: string                  # 可读名称
one-liner: string             # 一句话定义
problem: string               # 解决什么问题
acceptance_criteria: [string] # 可验证的验收标准
dependencies: [feature_id]    # 前置 feature
code_scope_hint: string       # 轻量指向（入口+命名模式）
out_of_bound: [string]        # 明确不做的事
```

### 核心原则

1. 每个 feature 承诺一个用户可验证的行为
2. 如果无法承诺"如何验证"，说明边界不清晰
3. **边界确认** 和 **验收标准** 必须明确
4. Feature 之间通过 DAG 组合，而非一个大 feature 承担所有

### 终止条件

用户澄清循环的终止权在用户，但 AI 必须通过 checklist 自检并指出缺失：

**必要项（缺一不可）：**
1. 边界清晰 — `out_of_bound` 已定义
2. 验收标准明确 — 至少有一条可验证的 `acceptance_criteria`
3. Feature 可独立实现 — 不依赖未明确的跨 feature 协调
4. AI 已暴露理解 — 用户已确认或纠正过 AI 的理解

AI 在 checklist 未通过时，必须明确告知用户还缺什么，而不是假装完成。

## 目录结构

```
项目根目录/
├── AGENTS.md                         # Agent 工作指导（角色、规则、约束）
├── ARCHITECTURE.md                   # 顶层架构和分层映射
│
├── features/                         # Feature Registry（持久化，source of truth）
│   └── {feature-id}/
│       ├── index.md                  # scope + spec + 验收标准 + 技术方向
│       └── plan.md                   # 实施路径（文件定位 + 任务拆分 + milestones）
│
├── docs/
│   ├── design-docs/                  # 设计文档
│   ├── exec-plans/                   # 执行计划（一等工件）
│   │   ├── active/                   # 活跃执行计划
│   │   ├── completed/                # 已完成执行计划
│   │   └── tech-debt-tracker.md      # 技术债务追踪
│   ├── product-specs/                # 产品规格
│   └── references/                   # 参考资料
│
├── .harness/                         # 执行时工作文件夹（非持久化）
│   ├── controllability/              # 服务生命周期管理
│   │   ├── Makefile                  # 标准命令：run, stop, test, verify
│   │   ├── start.sh                  # 服务启动（带 correlation ID）
│   │   ├── stop.sh                   # 服务停止
│   │   └── verify.sh                 # 健康检查（PID + HTTP endpoint）
│   ├── observability/                # 运行时可观测性
│   │   ├── log.sh                    # 日志检索
│   │   ├── health.sh                 # 健康诊断
│   │   └── trace.sh                  # 分布式追踪分析
│   ├── file-stack/                   # 活文档（执行时状态）
│   │   ├── prompt.md                 # 当前任务原始需求
│   │   ├── plan.md                   # 当前活跃计划（进度勾选）
│   │   └── documentation.md          # 实时状态、决策记录、意外发现
│   └── traces/                       # 执行轨迹
│
└── src/                              # 源代码
```

## 工作文件夹

`.harness/` 是工作文件夹，存储 AI 执行过程中的状态：

- **执行进度**：当前 milestone、已完成步骤
- **错误记录**：尝试过的方向和失败原因
- **工具调用结果**：代码分析、搜索结果
- **链路理解**：对代码结构的逐步理解

**动态回填**：feature 做完可回填更详细的 code_scope；未完成时 AI 自己探索，信任其判断。

## Lint 设计

### 各环节介入

| 环节 | 作用 | 类型 |
|------|------|------|
| **需求拆解** | 检查 feature 产物格式完整性 | 轻量格式 lint |
| **Plan 生成** | 检查 plan.md 必要字段 | 结构 lint |
| **代码执行** | 检查代码是否符合 Golden Principles | 代码 lint |
| **提交前** | P0 规则阻塞合并 | 硬门禁 |
| **定期 GC** | 扫描漂移并自动修复 | 持续传感器 |

### 规则分层

- **P0（阻塞合并，3-5 条）**：真正 load-bearing 的规则
  - 依赖方向、API 统一格式、硬编码 secret、显式错误处理
- **P1（GC 周期修复）**：命名规范、文件长度、复杂度
- **P2（建议级别）**：风格偏好，不强制

### 运行时机

- **Milestone 边界**：Worker agent 完成一个 milestone 后强制跑 lint
- **Plan 阶段**：Plan agent 扫描涉及 code_scope 的当前合规状态（前馈）
- **提交前**：完整 lint suite

### Lint 消息格式

Lint 消息必须包含**修复建议**（正向 prompt injection），而不仅是错误声明：

```
GP-001 违反：检测到反向依赖
正确方向：domain → shared → external
建议：将共享逻辑提取到 app/lib/shared/
```

## 关键设计原则

1. **用户透明**：用户只参与 intent → feature；后续全 AI 自主执行
2. **Atomic Feature**：边界清晰，可独立验证，不污染其他 feature
3. **Plan == ExecPlan**：当 feature 够小时合并，减少文档开销
4. **状态机器拥有**：交付状态不手写，由机器同步生成
5. **质量左移**：质量门禁尽量提前（pre-commit > CI > 人工 review）
6. **信任 AI**：不过度约束；做完回填，不做信任 AI 自主探索

## 命令

```bash
# 服务生命周期
make run        # 启动服务（带 correlation ID 追踪）
make stop       # 优雅停止服务
make verify     # 健康检查（PID + 可选 HTTP health endpoint）
make test       # 运行测试套件
make logs       # 查看最近日志

# 可观测性
./controllability/log.sh recent 50   # 查看最近日志
./controllability/verify.sh          # 检查服务健康状态
```

## 服务配置

- **Correlation ID**：每次 `start.sh` 运行生成，用于日志追踪
- **Health endpoint**：默认 `http://localhost:8080/health`（可通过 `HEALTH_ENDPOINT` 环境变量配置）
- **Log 目录**：`.harness/observability/logs/`
- **PID 文件**：`.harness/{project-name}.pid`

## 添加新项目

为新项目设置 harness-engineering：

1. 复制 `.harness/` 作为基础设施
2. 自定义 `controllability/start.sh` 的启动机制
3. 替换 `{{project-name}}` 为实际项目名
4. 在 `.harness/golden-principles/` 添加 Golden Principles
5. 在 `.harness/evals/` 设置回归测试 Evals
6. 建立 `features/` 的 atomic feature 集合
