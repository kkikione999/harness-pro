# Harness Engineering 落地指导书

> **基于14篇行业博客的深度调查 + 6人小队辩论综合**
> **主框架**: OpenAI "Harness Engineering: Leveraging Codex in an Agent-First World"
> **融合**: Anthropic GAN架构 + LangChain 解剖学 + MartinFowler 控制论
> **产出日期**: 2026-04-05

---

## 第一部分：核心架构决策（辩论结论）

### 1.1 单Agent vs 多Agent：渐进式路径

**辩论结论**：以单Agent Loop为起点，按需引入多Agent分工。

| 阶段 | 架构 | 适用场景 | 依据 |
|------|------|----------|------|
| **Phase 0** | 单Agent + 工具调用 | 常规编码任务 | Codex实战验证：3人/5月/1M行代码 |
| **Phase 1** | 单Agent + Evaluator Hook | 质量敏感任务 | 在Agent Loop中加入评估步骤，不需要架构变更 |
| **Phase 2** | Planner + Executor + Evaluator 三Agent | 复杂长时运行任务 | Anthropic量化：单Agent $9/20min → 三Agent $200/6h，质量显著提升 |

**判断标准**：
- 任务预估 < 1小时 → 单Agent
- 任务 1-6小时且需要质量保证 → 单Agent + Evaluator Hook
- 任务 > 6小时或涉及多领域 → 三Agent架构

**关键原则**：多Agent间通过**文件系统**通信（非内存共享），利用 long-runner 的文件栈作为Agent间的结构化移交产物。

### 1.2 上下文管理：Compaction + 文件栈互补

**辩论结论**：文件栈（外部化状态）+ Compaction（内部状态压缩）**互补而非竞争**。

| 机制 | 解决的问题 | 保留什么 | 丢失什么 |
|------|-----------|---------|---------|
| **文件栈** | 任务方向一致性、跨会话持久化 | Goals、Plan、Decisions、Status | 推理过程的中间步骤 |
| **Compaction** | 上下文窗口溢出、推理连续性 | 模型的潜在理解（加密表示） | 低优先级的对话细节 |

**6层上下文中各层的持久化策略**：

| 层 | 内容 | 持久化方式 |
|----|------|-----------|
| L1 结构元数据 | 项目结构、依赖关系 | 文件栈 + Git |
| L2 人类标注 | 领域专家知识 | docs/ 目录（版本控制） |
| L3 代码衍生 | 模式、不变量 | Golden Principles + Linters |
| L4 机构知识 | 文档、决策记录 | 文件栈的 Documentation.md |
| L5 持久记忆 | 纠正、学习 | .claude/memory/ |
| L6 运行时上下文 | 当前查询、实时状态 | Compaction |

**落地原则**：任何影响任务完成判断的信息必须写入文件栈（不依赖Compaction保留）。

### 1.3 Golden Principles vs Evals：统一质量管理

**辩论结论**：Golden Principles（代码不变量）和 Evals（Agent行为评估）是**同一条质量光谱的两端**。

```
质量光谱：
[静态不变量] ←—— Golden Principles / Linters / 结构测试 ——→ [动态评估]
                                                          Evals / Trace分析 / 人工审查

前馈（预防）                                    反馈（检测）
```

**统一管理框架**：

| 类别 | 检测时机 | 工具 | 示例 |
|------|---------|------|------|
| P0 阻塞合并 | Pre-commit / CI | 自定义Linter + 结构测试 | 依赖方向违反、API格式不一致 |
| P1 GC周期修复 | 定期后台扫描 | Agent扫描任务 + 自动重构PR | 命名不一致、死代码 |
| P2 Evals回归测试 | 每次模型/Harness变更 | Evals Suite + Grader | 功能正确性、行为回归 |
| P3 能力边界探索 | 月度 | Capability Evals | 新任务类型成功率 |

---

## 第二部分：可落地架构设计

### 2.1 Harness 系统总体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        客户端层 (Clients)                         │
│   CLI / IDE / Web / Desktop / MCP Client                        │
│   ↕ JSON-RPC over stdio (JSONL)                                 │
├──────────────────────────────────────────────────────────────────┤
│                        App Server (Harness Core)                 │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────────┐ │
│  │ Protocol │  │ Thread Mgr   │  │ Agent Loop Engine          │ │
│  │ Layer    │  │ (Create/     │  │ ┌────────────────────────┐ │ │
│  │          │  │  Resume/     │  │ │ Prompt Builder         │ │ │
│  │ Item     │  │  Fork/      │  │ │ ├─ System Instructions  │ │ │
│  │ Turn     │  │  Archive)   │  │ │ ├─ Permissions          │ │ │
│  │ Thread   │  │             │  │ │ ├─ AGENTS.md (目录)     │ │ │
│  └──────────┘  └──────────────┘  │ │ ├─ File Stack          │ │ │
│                                  │ │ ├─ Skills              │ │ │
│                                  │ │ └─ User Message        │ │ │
│                                  │ ├────────────────────────┤ │ │
│                                  │ │ Model Inference        │ │ │
│                                  │ │ (Responses API / OSS)  │ │ │
│                                  │ ├────────────────────────┤ │ │
│                                  │ │ Tool Execution         │ │ │
│                                  │ │ ├─ Sandbox (Shell/FS)  │ │ │
│                                  │ │ ├─ MCP Servers         │ │ │
│                                  │ │ └─ Skills Registry     │ │ │
│                                  │ ├────────────────────────┤ │ │
│                                  │ │ Context Manager        │ │ │
│                                  │ │ ├─ Compaction          │ │ │
│                                  │ │ └─ File Stack Sync     │ │ │
│                                  │ └────────────────────────┘ │ │
│                                  └────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                        质量保障层 (Quality)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Golden       │  │ Evals Suite  │  │ GC Engine              │ │
│  │ Principles   │  │ (Capability  │  │ (定期扫描 → 评分 →     │ │
│  │ (P0 Linters) │  │  + Regression│  │  自动重构PR)           │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                        安全与执行环境层                            │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Container    │  │ Network      │  │ Secret                 │ │
│  │ Isolation    │  │ Policy Layer │  │ Injection              │ │
│  │ (per task)   │  │ (Allowlist)  │  │ (Domain-scoped)        │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                        可观测性层 (per Worktree)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Logs (LogQL) │  │ Metrics      │  │ UI (Chrome DevTools    │ │
│  │              │  │ (PromQL)     │  │  Protocol)             │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 目录结构规范

```
project-root/
├── AGENTS.md                          # ~100行，目录式（不写详细规则）
├── .harness/                          # Harness 核心配置
│   ├── config.yaml                    # Harness 全局配置
│   ├── file-stack/                    # Durable Project Memory
│   │   ├── prompt.md                  # Goals + Non-goals + Constraints + Done-when
│   │   ├── plan.md                    # Milestones + Acceptance Criteria
│   │   ├── implement.md               # Execution Instructions + Progress
│   │   └── documentation.md           # Status + Decisions + Known Issues
│   ├── golden-principles/             # 机械可验证的不变量
│   │   ├── README.md                  # 原则索引
│   │   ├── GP-001-dependency-direction.md
│   │   ├── GP-002-api-envelope.md
│   │   ├── GP-003-error-handling.md
│   │   └── ...
│   ├── evals/                         # Evals 测试套件
│   │   ├── capability/                # 能力评估
│   │   ├── regression/               # 回归测试
│   │   └── golden/                   # Golden 解（参考答案）
│   ├── skills/                        # Agent Skills 注册表
│   │   ├── cdp-inspect/              # CDP 浏览器操作
│   │   │   ├── SKILL.md
│   │   │   └── resources/
│   │   ├── log-query/                # LogQL 查询
│   │   ├── perf-validate/            # 性能验证
│   │   └── git-worktree/             # Worktree 生命周期管理
│   └── linters/                       # 自定义 Linters
│       ├── dependency-direction.py
│       ├── api-envelope.py
│       └── error-handling.py
├── docs/                              # 结构化知识库（渐进式披露）
│   ├── architecture.md               # 系统架构
│   ├── conventions.md                # 编码规范
│   ├── testing.md                    # 测试策略
│   ├── workflows/                    # 常见工作流
│   │   ├── feature-development.md
│   │   ├── bug-fix.md
│   │   └── deployment.md
│   └── runbooks/                     # 运维手册
│       ├── incident-response.md
│       └── debugging.md
├── tests/
│   ├── structural/                   # 结构测试（验证架构不变量）
│   └── evals/                        # Eval 测试执行
└── src/                              # 业务代码
    └── [domain]/                     # 按业务域组织
        ├── api/                      # API 层
        ├── logic/                    # 业务逻辑层
        └── data/                     # 数据层
```

---

## 第三部分：Durable Project Memory 文件栈模板

### 3.1 prompt.md（规格书）

```markdown
# [项目名称]

## Goals
- [明确的目标，每个一行]

## Non-Goals
- [明确不做的事，防止 scope creep]

## Hard Constraints
| 维度 | 约束 |
|------|------|
| Performance | [具体指标，如"API响应 <200ms p99"] |
| Determinism | [确定性要求] |
| Security | [安全约束，参考security-sandbox checklist] |
| Platform | [平台限制] |

## Deliverables
- [ ] [交付物1：具体描述 + 验收标准]
- [ ] [交付物2]

## Done When
- [ ] [验收检查1]
- [ ] [验收检查2]
- Demo flow:
  1. [步骤1]
  2. [步骤2]
```

### 3.2 plan.md（里程碑计划）

```markdown
# Implementation Plan

## Milestone 1: [名称]
**Scope**: [一段话描述范围]
**Acceptance Criteria**:
- [ ] [标准1]
- [ ] [标准2]
**Validation Commands**:
```bash
[具体的验证命令，如 npm test -- --grep "feature X"]
```
**Stop-and-fix**: If any validation fails, repair before proceeding.

---

## Milestone 2: [名称]
...

---

## Decision Log
| # | Decision | Rationale | Date | Milestone |
|---|----------|-----------|------|-----------|
| D1 | [决策] | [原因] | YYYY-MM-DD | M1 |
```

### 3.3 implement.md（执行指令）

```markdown
# Execution Instructions

## Operating Rules
1. plan.md is the source of truth — work milestone by milestone
2. Run validation after completing each milestone
3. Keep diffs scoped — do NOT expand scope
4. Update documentation.md after each milestone
5. If stuck >3 attempts on a milestone → log blocker and re-evaluate

## Current Focus
**Active Milestone**: M[N] — [名称]

## Progress
| Milestone | Status | Validation | Notes |
|-----------|--------|------------|-------|
| M1 | DONE | PASS | [简述] |
| M2 | IN PROGRESS | PENDING | [当前工作] |
| M3 | PENDING | - | - |
```

### 3.4 documentation.md（状态日志）

```markdown
# Project Status

## Current State
- **Active Milestone**: M[N]
- **Completed**: M1, M2, ...
- **Next**: M[N+1]
- **Blockers**: [如果有]

## Architecture Decisions
### AD-[N]: [决策标题]
- **Context**: [为什么需要做这个决策]
- **Decision**: [做了什么决策]
- **Consequences**: [trade-offs]

## How to Run
```bash
[启动命令]
```

## How to Demo
[演示步骤]

## Known Issues
- [问题1] — Priority: [P0/P1/P2]
- [问题2]

## Follow-ups
- [ ] [后续工作1]
- [ ] [后续工作2]
```

---

## 第四部分：AGENTS.md 模板（~100行目录式）

```markdown
# [项目名称] — Agent Guide

## Quick Reference
- Architecture → docs/architecture.md
- Coding Conventions → docs/conventions.md
- Testing Strategy → docs/testing.md
- Golden Principles → .harness/golden-principles/README.md

## Project Structure
- `src/[domain]/` — Business domains (each: api/ + logic/ + data/)
- `src/shared/` — Shared utilities (import restrictions apply)
- `tests/` — Test mirror of src/
- `.harness/` — Harness configuration and file stack
- `docs/` — Structured knowledge base

## Architecture Rules (enforced by linters)
- Dependency direction: domain → shared → external (NEVER reverse)
- Each domain: api/ (routes) → logic/ (services) → data/ (repos)
- No cross-domain imports except through shared/
- See docs/architecture.md for full rules

## Workflows
- Feature development → docs/workflows/feature-development.md
- Bug fix → docs/workflows/bug-fix.md
- Deployment → docs/workflows/deployment.md

## Quality Gates (enforced mechanically)
- `make lint` — Golden Principles compliance (P0 only, blocks merge)
- `make test-structural` — Architecture invariant verification
- `make test` — Full test suite (>80% coverage required)
- `make evals` — Regression evals on model/Harness changes

## File Stack (for long-running tasks)
- Spec → .harness/file-stack/prompt.md
- Plan → .harness/file-stack/plan.md
- Execution → .harness/file-stack/implement.md
- Status → .harness/file-stack/documentation.md
```

---

## 第五部分：Golden Principles 框架

### 5.1 规则模板

每条 Golden Principle 必须包含：

```markdown
## GP-[NNN]: [规则名称]
**Rule**: [明确的、无歧义的规则描述]
**Rationale**: [为什么这条规则存在]
**Verification**: [如何机械验证 — linter/测试/扫描]
**Priority**: [P0 阻塞合并 | P1 GC周期修复 | P2 低优先级]
**Counter-example**: [违反规则的示例]
```

### 5.2 推荐初始规则集

| ID | 规则 | 验证方式 | 优先级 |
|----|------|---------|--------|
| GP-001 | 依赖方向：domain→shared→external，禁止反向 | dependency-direction.py linter | P0 |
| GP-002 | API响应统一envelope格式 | api-envelope.py linter | P0 |
| GP-003 | 所有错误路径显式处理，禁止空catch | error-handling.py linter | P0 |
| GP-004 | 公开API必须附测试，覆盖率不可降 | CI coverage gate | P0 |
| GP-005 | 同一概念全库统一术语 | 术语表 + 定期扫描 | P1 |
| GP-006 | 禁止硬编码secret/credential | secret-scan.py + pre-commit hook | P0 |
| GP-007 | 文件长度 <800行，函数 <50行 | complexity-check.py | P1 |
| GP-008 | 新增domain必须包含api/logic/data三层 | 结构测试 | P0 |

### 5.3 GC（垃圾回收）循环

```
每周自动执行：
  1. 扫描 → 对每条GP检查全库合规率
  2. 评分 → 更新各模块的质量等级 (A/B/C/D)
  3. 识别 → 找出D级模块和退化趋势
  4. 重构 → 为D级模块自动开重构PR
  5. 报告 → 更新质量看板
```

**核心原则**：技术债务 = 高利息贷款 → 持续小额偿还 > 痛苦大批量偿还

---

## 第六部分：Evals 体系设计

### 6.1 三类Evals

| 类型 | 目标通过率 | 频率 | 数据来源 |
|------|-----------|------|---------|
| **Capability Evals** | 低→逐步提升 | 月度/模型升级时 | 新任务类型、挑战性case |
| **Regression Evals** | 接近100% | 每次变更 | 生产bug、用户报告、已知失败case |
| **Quality Evals** | 趋势追踪 | GC周期 | Golden Principles合规率 |

### 6.2 Grader选择优先级

```
优先使用：
  1. Code-based Grader（确定性、快速、可复现）
     — 字符串匹配、正则、二进制测试、静态分析
  2. Model-based Grader（灵活性）
     — 仅当code-based无法覆盖时使用
  3. Human Grader（金标准）
     — 抽样验证grader有效性
```

### 6.3 Eval Case模板

```yaml
# .harness/evals/regression/case-001.yaml
id: "REG-001"
name: "API response envelope format"
type: regression
priority: P0
input:
  task: "Create a new API endpoint for user profile"
  context: "docs/workflows/feature-development.md"
golden_output:
  - type: code
    description: "Endpoint returns {success, data, error, meta} envelope"
  - type: test
    description: "Test verifies envelope structure"
grader:
  type: code-based
  check: "api-envelope linter + test pass"
source: "Bug report #123 — missing error field in response"
```

### 6.4 Evals从0到1路线图

1. **Week 1**: 从已有bug中提取20-50个eval case
2. **Week 2**: 为每个case编写Golden解
3. **Week 3**: 建立eval harness + CI集成
4. **Week 4**: 选择grader组合，验证transcripts
5. **持续**: 每个新bug → 新eval case；监控capability eval饱和度

---

## 第七部分：安全 Checklist

### 7.1 容器安全
- [ ] 每个任务独立容器，无共享状态
- [ ] 容器文件系统临时化，任务完成后销毁
- [ ] 容器内无持久凭证——仅在egress时注入
- [ ] 资源限制（CPU/内存/磁盘/网络）按容器执行

### 7.2 网络安全
- [ ] 所有出站流量通过集中策略层
- [ ] 域名级allowlist
- [ ] 域名级secret注入（secret从不进入prompt或容器环境变量）
- [ ] 每容器/每用户速率限制

### 7.3 权限模型
- [ ] 权限透传：Agent继承用户权限，永远不超过
- [ ] 权限指令注入在system级别（最高优先级）
- [ ] Approval模式：suggest(默认) → auto-edit → full-auto
- [ ] 权限变更需要重新认证

### 7.4 Shell Tool安全
- [ ] 模型只能**提议**命令——平台验证后才执行
- [ ] 命令allowlist/blocklist在mediation层执行
- [ ] 并发命令在隔离会话中执行
- [ ] 每命令超时强制

### 7.5 多Agent安全（Phase 2）
- [ ] 每个Agent独立的权限scope
- [ ] Agent间通信通过文件系统（非共享内存）
- [ ] 通信产物受同样的权限透传规则约束
- [ ] Agent间不能直接调用——必须通过Orchestrator

---

## 第八部分：可观测性集成（per Worktree）

### 8.1 Worktree 隔离架构

```
每个变更（change）对应：
┌──────────────────────────────┐
│ worktree-[change-id]/        │
│ ├── src/                     │  ← 独立代码副本
│ ├── app instance             │  ← 可启动的应用实例
│ ├── ephemeral obs stack      │
│ │   ├── Loki (logs)          │  ← LogQL 可查询
│ │   ├── Prometheus (metrics) │  ← PromQL 可查询
│ │   └── Chrome (CDP)         │  ← UI 可检查
│ └── .harness/file-stack/     │  ← 独立状态文件
└──────────────────────────────┘
```

### 8.2 性能断言示例

Prompt 可以包含：
- "确保服务启动在800ms内完成" → Agent用PromQL验证
- "四个关键用户旅程中没有span超过2秒" → Agent用TraceQL验证
- "登录页面正确渲染登录表单" → Agent用CDP截图+DOM快照验证

### 8.3 Agent Skills for Observability

| Skill | 功能 | 触发条件 |
|-------|------|---------|
| `cdp-inspect` | DOM快照、截图、导航 | 涉及UI变更的任务 |
| `log-query` | LogQL查询日志 | 涉及后端变更的任务 |
| `metric-check` | PromQL查询+断言 | 涉及性能要求的任务 |
| `perf-validate` | 端到端性能验证 | 涉及性能约束的任务 |
| `git-worktree` | Worktree创建/清理 | 所有任务 |

---

## 第九部分：分阶段落地路线图

### Phase 0: 基础设施搭建（Week 1-2）

**目标**：建立Harness最小可行骨架

| 步骤 | 产出 | 验证标准 |
|------|------|---------|
| 0.1 创建目录结构 | .harness/, docs/, tests/structural/ | 目录存在且AGENTS.md <100行 |
| 0.2 编写AGENTS.md | 目录式Agent指南 | Agent能根据它找到所有文档 |
| 0.3 建立文件栈模板 | prompt.md, plan.md, implement.md, documentation.md | 模板可用`harness init`生成 |
| 0.4 实现3条P0 Golden Principles | dependency-direction, api-envelope, error-handling | `make lint` 能检测违反 |
| 0.5 建立CI pipeline | lint + test-structural + coverage gate | PR自动检查 |

**关键约束**：此阶段所有代码都可以由Agent生成——包括linters、模板、CI配置。

### Phase 1: 质量体系建立（Week 3-4）

**目标**：Evals体系 + GC引擎

| 步骤 | 产出 | 验证标准 |
|------|------|---------|
| 1.1 收集初始eval数据集 | 20-50个case from真实bug | 每个case有Golden解 |
| 1.2 构建eval harness | Capability + Regression两套 | `make evals` 可执行 |
| 1.3 实现GC扫描引擎 | 定期扫描Golden Principles合规率 | 自动产出质量报告 |
| 1.4 自动重构PR | GC引擎自动开重构PR | D级模块自动获得重构PR |
| 1.5 Trace分析基础设施 | 收集每次运行的完整trace | Trace可查询、可分析 |

### Phase 2: 长时运行支持（Week 5-6）

**目标**：支持6小时+自主运行

| 步骤 | 产出 | 验证标准 |
|------|------|---------|
| 2.1 Worktree隔离 | 每任务独立worktree | Agent能并行工作不互相干扰 |
| 2.2 Ephemeral Observability | 每worktree配套obs stack | Agent能用LogQL/PromQL查询 |
| 2.3 CDP集成 | Chrome DevTools Protocol接入 | Agent能截图、获取DOM |
| 2.4 文件栈自动化 | 里程碑自动验证、状态自动更新 | 25小时运行不需要人工干预 |
| 2.5 Context Compaction | 接入/compact端点或等效机制 | 长运行中context不溢出 |

### Phase 3: 多Agent演进（Week 7-8）

**目标**：按需引入多Agent分工

| 步骤 | 产出 | 验证标准 |
|------|------|---------|
| 3.1 Evaluator Hook | Agent Loop中加入评估步骤 | 单Agent能自验证 |
| 3.2 Agent间通信协议 | 基于文件系统的结构化移交 | Generator→Evaluator无缝衔接 |
| 3.3 Planner Agent | 独立的任务分解和里程碑规划 | 三Agent协作完成复杂任务 |
| 3.4 多Agent安全 | 独立权限scope + Orchestrator | 无权限泄漏 |
| 3.5 渐进式简化机制 | A/B测试框架（完整 vs 精简Harness） | 量化每个组件的load-bearing状态 |

---

## 第十部分：核心数据参考

### 10.1 OpenAI Harness实战数据

| 指标 | 数值 | 含义 |
|------|------|------|
| 团队规模 | 3 engineers | 小团队+Agent=大产出 |
| 开发周期 | 5 months | 从空仓库到内部发布 |
| 代码量 | ~1M lines | 全Agent生成 |
| PR数量 | ~1,500 | 平均3.5 PR/人/天 |
| 单次Codex运行 | 6+ hours | 经常在人类睡眠时运行 |
| 最长单次运行 | ~25 hours | 13M tokens, 30k lines |
| AGENTS.md | ~100 lines | 目录式，非百科全书 |

### 10.2 LangChain量化改进数据

| 指标 | 数值 | 含义 |
|------|------|------|
| Benchmark | Terminal Bench 2.0 | 标准评测 |
| 仅调Harness提升 | 52.8% → 66.5% | +13.7分，模型不变 |
| 排名变化 | Top 30 → Top 5 | Harness的ROI极高 |

### 10.3 Anthropic成本对比

| 配置 | 时间 | 成本 | 质量 |
|------|------|------|------|
| 单Agent (Opus 4.5) | 20min | $9 | 基准 |
| 三Agent Harness (Opus 4.5) | 6h | $200 | 显著提升 |
| 简化Harness (Opus 4.6) | 3h50m | $124 | 等效（模型进步允许简化）|

---

## 第十一部分：七条融合设计原则（最终版）

从6份报告的辩论中提炼的7条不可妥协的原则：

1. **渐进式披露原则**：给Agent地图，不要百科全书。AGENTS.md <100行，详细知识放docs/。

2. **机械执行优于文档约束原则**：任何不能被自动验证的规则都不属于Golden Principles——它属于文档。

3. **文件栈 + Compaction 互补原则**：任务关键信息写文件栈（不依赖Compaction），推理连续性靠Compaction。

4. **权限透传原则**：Agent永远不超过用户权限。多Agent场景下每个Agent独立scope。

5. **GC式技术债务管理原则**：技术债务 = 高利息贷款。持续小额自动偿还 > 痛苦大批量手动清理。

6. **数据驱动迭代原则**：用Trace分析识别失败模式，用Evals量化改进效果。不盲目调参。

7. **渐进式架构演进原则**：从单Agent开始，按需引入多Agent。每次模型升级后测试组件load-bearing状态，做减法释放资源。

---

## 附录A：Harness 配置参考

```yaml
# .harness/config.yaml
harness:
  version: "1.0"
  name: "[项目名称]"

  agent:
    model: "gpt-5.3-codex"        # 可配置的模型端点
    reasoning: "high"              # low / medium / high / extra-high
    max_tokens: 1000000            # 单次运行token上限
    auto_compact: true             # 自动compaction
    compact_limit: 80000           # compaction触发阈值

  approval_mode: "suggest"         # suggest / auto-edit / full-auto

  file_stack:
    enabled: true
    path: ".harness/file-stack/"
    auto_sync: true                # 自动同步文件栈状态

  quality:
    golden_principles: ".harness/golden-principles/"
    evals: ".harness/evals/"
    gc_schedule: "0 2 * * 0"      # 每周日凌晨2点GC扫描
    coverage_gate: 80              # 测试覆盖率门禁

  security:
    sandbox: true                  # 启用沙箱
    network_policy: "allowlist"    # allowlist / open
    secret_injection: "domain-scoped"
    zdr: false                     # Zero Data Retention

  observability:
    per_worktree: true             # 每worktree独立obs stack
    log_endpoint: "http://localhost:3100"     # Loki
    metric_endpoint: "http://localhost:9090"   # Prometheus
    cdp_enabled: true              # Chrome DevTools Protocol
```

## 附录B：快速启动命令

```bash
# 1. 初始化Harness项目
harness init [project-name]

# 2. 启动Agent（自动读取AGENTS.md和文件栈）
harness run --task "Implement feature X per .harness/file-stack/prompt.md"

# 3. 运行质量检查
harness quality check          # Golden Principles + 结构测试
harness quality evals          # 运行Evals套件
harness quality gc             # 运行GC扫描

# 4. 查看状态
harness status                 # 文件栈状态 + 质量等级
harness trace analyze          # 分析最近运行的traces
```

---

---

## 附录C：辩论记录与共识（6人交叉辩论精华）

### 辩论1：单Agent vs 多Agent架构选择

**arch-architect 立场**：Codex单Agent Loop已通过1M行代码实战验证。Thread/Turn/Item原语可自然扩展为多Agent（通过Sub-Turn或Orchestrator折叠回单Loop）。多Agent不是更好的架构，而是解决特定问题的工具。

**philosophy-analyst 立场**（修正后）：接受挑战。原报告将独立Evaluator列为P0是错误的——应从Codex单Agent约束出发。Middleware/Hook模式（LangChain方案）可零架构变更实现所有控制逻辑，升级为P0。

**共识判断标准**：
- 生成和评估需要**不同系统提示词**（不同价值函数）→ 多Agent
- 单Agent上下文窗口不够 → 多Agent
- 存在**可量化的自我肯定偏差** → 多Agent
- 子任务可并行 → 多Agent
- 否则 → 单Agent + Middleware

### 辩论2：Compaction vs Context Reset + 文件栈

**ctx-manager 结论**：
- Compaction保留**理解**但不保留**精度**——像记得对话大意但丢失精确规格
- Anthropic自己的证据：Opus 4.6让Context Reset变得不必要（单session 2+小时），但复杂多Agent仍需结构化移交
- **黄金规则**：需要跨Context Reset存活的信息必须文件持久化，Compaction只负责session内连续性

**long-runner 结论**：
- 文件栈管理"what & why"（语义一致性），Compaction管理"how to fit"（物理容量）
- 文件栈自身也需要"垃圾回收"——滚动窗口保留最近3个里程碑，更早的压缩为摘要
- **一句话**：Compaction保证物理上能运行，文件栈保证语义上不漂移

**6层持久化策略（辩论共识）**：

| 层 | 策略 | 理由 |
|----|------|------|
| L1-L3 | 文件持久化 | 机器生成/人类标注/代码衍生——必须跨session存活 |
| L4 | 混合：索引文件持久化，详情按需加载 | 机构知识量大但访问模式可预测 |
| L5 | 文件持久化 | 纠正和学习太宝贵，不能依赖Compaction |
| L6 | Compaction | 运行时上下文是临时性的，session内连续即可 |

### 辩论3：Golden Principles vs Evals边界

**quality-guardian 结论**：
- GP是Evals的**子集**——专注于静态代码不变量的Evals
- 边界模糊但核心区别：GP检查**代码库本身**（持续的），Evals检查**Agent行为**（事件驱动的）
- GC式管理 vs 持续漂移传感器：**同一闭环的不同阶段**——传感器检测，GC修复
- 统一管理框架分三层：静态不变量(CI) → 行为Evals(eval harness) → 人工审查(抽样)

**关键洞察**：从失败到规则的转化循环——每个被Evals捕获的新失败模式，最终应编码为新的Golden Principle。Evals"发现未知"，GP"防止已知重复发生"。

### 辩论4：多Agent安全新风险

**security-sandbox 新增发现（辩论产出）**：

| 风险类型 | 描述 | 缓解措施 |
|----------|------|---------|
| **Poisoned Intermediates** | Generator被注入后写入恶意内容，Evaluator信任读取 | 中间产物必须schema验证 |
| **TOCTOU** | Planner检查时和Generator执行时文件已变 | 使用content hash或不可变快照 |
| **Cross-agent Data Leakage** | Planner看到敏感信息，摘要传给低权限Generator | 信息流分类策略 |
| **权限级联** | Evaluator不应有写权限，Planner不应有执行权限 | 按Agent角色划分权限子集 |

**安全原则升级**：从"agent = user's proxy"变为"each agent = scoped delegate with subset of user permissions"。Orchestrator而非Agent自身执行边界。

### 辩论5：修正后的落地优先级（最终共识）

**philosophy-analyst 的认知修正**：原报告犯了"从理想方案出发排优先级"的错误。修正后从Codex单Agent Loop约束出发：

| 优先级 | 方案 | 来源 | 理由 |
|--------|------|------|------|
| **P0** | Middleware/Hook模式 | LangChain | **零架构变更**。before_model/wrap_tool_call等直接映射到App Server Hook。实现自验证+上下文注入+死循环检测 |
| **P1** | 计算型前馈/反馈控制 | MartinFowler | 仅需配置：AGENTS.md（前馈）+ pre-commit hooks（反馈）。Codex已有能力 |
| **P2** | Trace分析流水线 | LangChain | 需要基础设施投入，但建成后为所有优化提供量化基础 |
| **P3** | 文件栈增强（VerifyCriteria） | Anthropic + long-runner | 在Plan.md和Implement.md间加入验证标准文件，单Agent内实现"事前协商" |
| **P4** | 独立Evaluator Agent | Anthropic | **从原P0降至P4**。需架构变更+安全模型重设计。仅在单Agent自验证不足时投入 |

**最务实路径**：LangChain Middleware实现 + MartinFowler分类框架 = 在不改变Codex架构的前提下实现所有控制逻辑。

---

> **本文档由6人调查小队（arch-architect, ctx-manager, long-runner, security-sandbox, philosophy-analyst, quality-guardian）深度调查14篇行业博客、交叉辩论后综合产出。**
> **主框架基于OpenAI Harness Engineering实战经验，融合Anthropic多Agent架构、LangChain数据驱动方法论、MartinFowler控制论框架。**
> **辩论关键修正：philosophy-analyst接受三项挑战，将独立Evaluator从P0降至P4，将Middleware/Hook升为P0。**
