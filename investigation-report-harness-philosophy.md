# 多源 Harness 设计哲学调查报告

**调查员**: philosophy-analyst
**日期**: 2026-04-05
**范围**: Anthropic (2篇), LangChain (2篇), Martin Fowler / Thoughtworks (1篇)

---

## 一、各流派核心观点摘要

### 1. Anthropic 流派：GAN 启发的多 Agent 架构 + 渐进式简化

**文章01** (Prithvi Rajasekaran, 2026-03-24) — *Harness design for long-running application development*
**文章02** (Justin Young, 2025-11-26) — *Effective harnesses for long-running agents*

**核心命题**: Harness 的价值在于补充模型自身无法完成的事情；随着模型改进，Harness 应随之瘦身，但新的能力前沿会持续需要新的 Harness 设计。

**关键设计原则**:

| 原则 | 说明 |
|------|------|
| **多Agent分工** | Planner / Generator / Evaluator 三角色架构，灵感来自 GAN 的生成器-判别器对抗结构 |
| **上下文重置 vs 压缩** | 上下文重置(Context Reset)提供"干净起点"但需要精心设计移交产物；压缩(Compaction)保持连续性但无法消除"上下文焦虑" |
| **分离评估** | 自我评估存在系统性偏差(模型倾向于称赞自己的输出)；独立评估者比让生成器批判自身工作更可行 |
| **Sprint分解** | 将复杂任务分解为可管理的 Sprint，每个 Sprint 有明确的"完成定义"(Sprint Contract) |
| **渐进式简化** | 当模型能力提升时(Opus 4.5 → 4.6)，逐一移除组件测试其是否 still load-bearing；而非一次性激进精简 |
| **结构化移交** | 文件系统作为 Agent 间通信媒介；进度文件 + git 历史作为跨会话状态载体 |

**量化证据**:
- 单Agent: 20分钟 / $9 → Harness(三Agent): 6小时 / $200，输出质量显著提升
- 简化后Harness(Opus 4.6): 3小时50分 / $124，去掉了 Sprint 分解但保留 Planner + Evaluator

**核心洞察**: "Harness 的有趣组合空间不会随着模型改进而缩小，而是会移动。AI 工程师的有趣工作是持续找到下一个新颖组合。"

---

### 2. LangChain 流派：组件解剖学 + 数据驱动迭代

**文章03** (Vivek Trivedy, 2026-03-11) — *The Anatomy of an Agent Harness*
**文章04** (LangChain Team, 2026-02-17) — *Improving Deep Agents with Harness Engineering*

**核心命题**: Agent = Model + Harness。如果你不是模型，你就是 Harness。Harness 工程的目标是将模型"尖刺状的智能"塑造成任务所需的形状。

**Harness解剖学(文章03)**:

```
Harness = {
  System Prompts,
  Tools / Skills / MCPs,
  Bundled Infrastructure (filesystem, sandbox, browser),
  Orchestration Logic (subagent spawning, handoffs, model routing),
  Hooks/Middleware (compaction, continuation, lint checks)
}
```

**从"期望行为"反向推导 Harness 设计的方法论**:

| 期望行为 | Harness 设计 |
|----------|-------------|
| 持久化存储 & 跨会话 | 文件系统 + git |
| 自主解决问题 | bash + code exec (通用工具) |
| 安全执行环境 | Sandbox 隔离执行 |
| 持续学习 & 知识更新 | Memory 文件 + Web Search + MCP (Context7) |
| 对抗上下文腐败 | Compaction + 工具调用卸载 + Skills 渐进披露 |
| 长时间自主执行 | Ralph Loop + 规划 + 自验证 |

**数据驱动改进(文章04)**:
- Terminal Bench 2.0 上仅通过 Harness 调优: 52.8% → 66.5% (+13.7分)，模型不变(gpt-5.2-codex)，从 Top 30 → Top 5
- 核心方法论: **Trace Analyzer Skill** — 自动分析失败 traces，识别模式，定向改进

**五大实践要点**:
1. **上下文工程代理**: 为 Agent 注入目录结构、可用工具、编码规范
2. **强制自验证**: 模型偏向首个可行解；需强提示去运行测试并迭代
3. **Traces 作为反馈信号**: 让 Agent 调试自身 traces
4. **检测并修复坏模式**: LoopDetectionMiddleware 等确定性干预
5. **为特定模型定制 Harness**: 不同模型需要不同的提示策略

---

### 3. Martin Fowler / Thoughtworks 流派：经典控制论视角

**文章05** (Birgitta Böckeler, 2026-04-02) — *Harness engineering for coding agent users*

**核心命题**: Harness 是一个控制系统(cybernetic governor)，结合前馈和反馈来调控代码库趋向期望状态。其终极目标不是消除人类输入，而是将人类输入引导到最重要的地方。

**控制论框架**:

| 维度 | 类型 | 说明 |
|------|------|------|
| **方向** | 前馈(Feedforward) | 在 Agent 行动前预见并引导行为 |
| **方向** | 反馈(Feedback) | 在 Agent 行动后观察并帮助自纠 |
| **执行类型** | 计算(Computational) | 确定性、快速 — 测试、linter、类型检查 |
| **执行类型** | 推理(Inferential) | 语义分析、AI 代码审查 — 慢但能处理语义 |

**四象限分类法**:

|  | 计算(Computational) | 推理(Inferential) |
|--|---------------------|-------------------|
| **前馈(Feedforward)** | Code mods, bootstrap scripts | AGENTS.md, Skills, 编码规范 |
| **反馈(Feedback)** | 结构测试, linter hooks, 类型检查 | AI code review, LLM-as-judge |

**三大 Harness 类别**:
1. **可维护性 Harness**: 最容易构建，利用已有工具(linter, 测试覆盖, 复杂度检测)
2. **架构适应性 Harness**: 性能测试 + 可观测性标准 + 适应度函数
3. **行为 Harness**: 最难但最重要 — 功能规格(前馈) + 测试套件 + 变异测试(反馈)

**独特贡献**:
- **Harnessability(可 Harness 性)**: 代码库的可治理性取决于技术选择(强类型语言天然拥有类型检查传感器)
- **Harness 模板**: 企业常见服务拓扑的 Harness 打包(指南 + 传感器)
- **持续漂移传感器**: 在变更生命周期之外持续运行的监控(死代码检测、依赖扫描)
- **质量左移(Shift Left)**: 越早发现问题，修复成本越低

---

## 二、异同对比矩阵

### 架构哲学对比

| 维度 | Anthropic | LangChain | MartinFowler/Thoughtworks |
|------|-----------|-----------|--------------------------|
| **核心隐喻** | GAN (生成器-判别器) | 解剖学(组件清单) | 控制论(前馈/反馈) |
| **关注焦点** | 多Agent协作 & 长时间运行 | 组件设计 & 数据驱动优化 | 系统化质量控制 |
| **目标受众** | AI 工程师(构建者) | AI 工程师(构建者) | 软件工程师(使用者) |
| **Harness定义** | 模型之外的一切 | Agent = Model + Harness | 编码Agent的外层控制 |
| **评估策略** | 独立Evaluator Agent | 自验证循环 + Trace分析 | 计算传感器 + 推理传感器 |
| **上下文管理** | Reset vs Compaction, 结构化移交 | Compaction, 工具卸载, Skills渐进披露 | 前馈上下文注入(AGENTS.md等) |
| **迭代方法** | 逐一移除组件测试 | Trace驱动的改进循环 | 转向循环(人类观察问题→改进Harness) |
| **复杂度观** | 随模型进步可简化，但新的前沿需要新的复杂度 | Harness knob空间巨大，压缩到3个核心 | Harness应持续演进，不需全部消除 |
| **人类角色** | 设计者/调优者 | Trace分析者/改进者 | 转向者，将注意力引导到最重要处 |
| **可量化验证** | 成本/时间/质量对比 | Benchmark分数提升 | 代码质量指标/覆盖率 |

### 关注点差异

| 关注点 | Anthropic | LangChain | MartinFowler |
|--------|-----------|-----------|--------------|
| 多Agent编排 | 核心关注 | 提及但非重点 | 未涉及 |
| 长时间自主运行 | 核心关注 | 重要关注 | 间接关注(通过质量左移) |
| 上下文工程 | Reset/Handoff Artifacts | Compaction/Progressive Disclosure | 前馈上下文注入 |
| 自验证 | Evaluator Agent(独立) | Prompt-driven + Middleware | 计算传感器(测试/linter) |
| 模型- Harness 协训练 | 提及但非核心 | 明确讨论(post-training with harness in loop) | 未涉及 |
| 可维护性/架构 | 未涉及 | 未涉及 | 核心关注(三大类别之一) |
| 安全/沙箱 | 提及(Playwright MCP) | 核心关注(Sandbox primitive) | 未涉及 |
| Harness 可移植性 | 未涉及 | 明确(不同模型需不同Harness) | 提及(Harnessability) |
| 数据驱动改进 | 定性观察 | 量化驱动(Trace分析) | 定性(转向循环) |

---

## 三、融合设计方案

### 设计原则提炼(取各家之长)

从三家方案中提取的 **7 条融合设计原则**:

1. **分离评估原则** (Anthropic)
   - 生成者和评估者必须是不同的 Agent/组件
   - 评估标准必须从主观判断转化为可评分的具体条款
   - Evaluator 的有用性取决于任务难度相对于模型能力的边界

2. **行为反向推导原则** (LangChain)
   - 从"我们期望 Agent 做什么"出发，反向推导需要什么 Harness 组件
   - 每个 Harness 组件的存在都应回答一个明确的"模型做不到什么"的问题

3. **前馈+反馈双通道原则** (MartinFowler)
   - 前馈(Guide)预防问题发生，反馈(Sensor)检测并自纠
   - 两条通道必须协同工作，缺少任一条都会导致系统性盲区
   - 优先使用计算型(确定性)控制，推理型(语义)作为补充

4. **数据驱动迭代原则** (LangChain)
   - 使用 Trace 分析识别失败模式
   - 定向改进而非盲目调参
   - 量化衡量每次 Harness 变更的效果

5. **渐进式简化原则** (Anthropic)
   - 新模型发布后逐一测试各组件的 load-bearing 状态
   - 不做激进的一次性精简
   - 简化后释放的资源用于新的能力前沿

6. **上下文分层管理原则** (三家融合)
   - Anthropic: 结构化移交产物(进度文件 + git)
   - LangChain: Compaction + 工具卸载 + Skills 渐进披露
   - MartinFowler: 前馈上下文注入 + 质量左移
   - **融合**: 三层上下文架构 — 持久层(文件系统/git) + 会话层(Compaction) + 即时层(Skills/Middleware)

7. **转向循环原则** (MartinFowler + LangChain)
   - 人类观察 → 改进 Harness → 自动化 → 再次观察
   - Harness 改进本身可以用 AI 辅助(Trace Analyzer / Agent 辅助生成 linter)
   - 目标不是消除人类，而是将人类注意力引导到高杠杆点

### 统一 Harness 框架概念设计

```
┌─────────────────────────────────────────────────────────┐
│                    Unified Harness                       │
├─────────────┬──────────────┬────────────────────────────┤
│             │              │                            │
│  前馈层     │   执行层      │      反馈层                │
│  (Guide)    │   (Execute)  │      (Sensor)              │
│             │              │                            │
│ ┌─────────┐ │ ┌──────────┐ │ ┌────────────────────────┐ │
│ │ Planner │ │ │ Generator│ │ │    Evaluator           │ │
│ │ (Anthro)│ │ │ (通用)   │ │ │    ┌─────┬──────┐      │ │
│ └────┬────┘ │ └────┬─────┘ │ │    │计算型│推理型│      │ │
│      │      │      │       │ │    │(M.F.)│(Anth)│      │ │
│ ┌────┴────┐ │ ┌────┴─────┐ │ │    └─────┴──────┘      │ │
│ │ Specs   │ │ │ Sandbox  │ │ │         │               │ │
│ │ AGENTS  │ │ │ + FS     │ │ │    ┌────┴─────┐         │ │
│ │ Skills  │ │ │ + Bash   │ │ │    │Trace     │         │ │
│ │ (M.F.)  │ │ │ + Browser│ │ │    │Analyzer  │         │ │
│ │ (Lang)  │ │ │ (Lang)   │ │ │    │(Lang)    │         │ │
│ └─────────┘ │ └──────────┘ │ │    └──────────┘         │ │
│             │              │ └────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │              上下文管理层                             │ │
│ │  持久层(FS/Git) + 会话层(Compaction) + 即时层(Skills)│ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │              转向循环(Steering Loop)                  │ │
│ │  人类观察 → Trace分析 → Harness改进 → 量化验证       │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 四、在 OpenAI Harness 框架基础上的融合落地建议

### 阶段一：吸收 Anthropic 的评估架构

**优先级：最高**

1. **引入独立 Evaluator Agent**
   - 在现有单Agent流程中加入评估环节
   - Evaluator 不与 Generator 共享上下文，避免确认偏差
   - 为 Evaluator 配备 Playwright MCP 或等效浏览器工具，实现真实交互式测试

2. **建立可评分的评估标准**
   - 将"代码质量"从主观判断转化为具体维度：功能完整性、代码整洁度、测试覆盖率、架构一致性
   - 为每个维度设定硬阈值(threshold)，低于阈值则打回

3. **Sprint Contract 模式**
   - 在实现前让 Generator 和 Evaluator 协商"完成定义"
   - 用文件系统作为通信媒介(Generator 提案 → Evaluator 审阅 → 确认后开始实现)

### 阶段二：吸收 LangChain 的数据驱动改进

**优先级：高**

1. **建立 Trace 分析流水线**
   - 收集每次运行的完整 traces(工具调用、模型输出、最终结果)
   - 使用 Agent 自动分析失败 traces，识别模式(死循环、过早停止、测试不足)
   - 形成改进建议 → 人工审核 → 实施 Harness 变更

2. **引入 Middleware/Hook 模式**
   - `PreCompletionChecklistMiddleware`: 在 Agent 退出前注入验证检查清单
   - `LoopDetectionMiddleware`: 跟踪单文件编辑次数，检测死循环
   - `LocalContextMiddleware`: 启动时自动发现目录结构、可用工具

3. **自验证循环强化**
   - 在系统提示中嵌入 Build-Verify-Fix 循环
   - 验证阶段必须运行测试并比对原始需求(而非自己的代码)

### 阶段三：吸收 MartinFowler 的系统化控制

**优先级：中高**

1. **构建四象限控制矩阵**
   - 为项目建立前馈/反馈 × 计算/推理的控制清单
   - 前馈: AGENTS.md(推理型), 代码模板(计算型), Skills(推理型)
   - 反馈: Linter hooks(计算型), 结构测试(计算型), AI code review(推理型)

2. **三大 Harness 类别逐步建设**
   - 第一阶段: 可维护性 Harness (linter + 测试覆盖 + 复杂度检测) — 投入产出比最高
   - 第二阶段: 架构适应性 Harness (适应度函数 + 性能测试 + 可观测性标准)
   - 第三阶段: 行为 Harness (功能规格 + 变异测试 + approved fixtures)

3. **质量左移实践**
   - 将反馈传感器尽量提前到开发流程中(pre-commit hook > CI > 人工审查)
   - 持续漂移传感器: 在变更生命周期外运行的监控(死代码、依赖扫描)

### 阶段四：融合创新

1. **模型适配层**
   - 认识到不同模型需要不同 Harness 配置(LangChain 明确量化了这一点)
   - 建立模型特定的提示库和工具配置

2. **Harness 自省能力**
   - 让 Agent 分析自身 traces，识别 Harness 层面的失败模式
   - 当传感器从不触发时，自动检测是质量好还是检测不足

3. **渐进式简化机制**
   - 每次模型升级后，运行 A/B 测试：完整 Harness vs 精简 Harness
   - 用量化数据判断每个组件是否 still load-bearing
   - 释放的资源投入到新的能力前沿

---

## 五、关键分歧与取舍建议

| 分歧点 | Anthropic 立场 | LangChain 立场 | MartinFowler 立场 | 建议 |
|--------|---------------|---------------|-------------------|------|
| **多Agent vs 单Agent** | 坚决多Agent(Planner/Generator/Evaluator) | 单Agent为主，子Agent为辅 | 不涉及，关注控制层 | 复杂任务用多Agent；简单任务用单Agent + Middleware |
| **上下文重置 vs 压缩** | 重置优于压缩(Opus 4.5)；4.6后压缩足够 | 压缩为主 | 不涉及 | 模型能力足够时用压缩；不足时用重置+移交 |
| **Evaluator 角色定位** | 独立Agent，有独立工具(Playwright) | 自验证循环(同一Agent内) | 计算传感器为主 | 三层验证：计算传感器(快) → 自验证(中) → 独立Evaluator(慢但准) |
| **Harness 复杂度方向** | 随模型进步简化 | 持续优化，不简化 | 持续演进 | 保持核心简单，按需扩展；新模型发布后做减法 |

---

## 六、总结

三家方案共同指向一个核心洞察：**Harness 的价值不在于弥补模型缺陷(这只是短期价值)，而在于构建一个系统，使模型智能得到有效利用(这是长期价值)。**

- **Anthropic** 贡献了最先进的 Agent 间协作架构(GAN 模式)和渐进式简化方法论
- **LangChain** 贡献了最完整的 Harness 组件解剖学和最可操作的数据驱动改进流程
- **MartinFowler/Thoughtworks** 贡献了最系统的控制论框架和最清晰的"人类角色"定位

融合这三家的核心理念，可以在 OpenAI 现有 Harness 框架基础上构建一个兼具**架构先进性**(Anthropic)、**数据驱动可优化性**(LangChain)和**系统化可信赖性**(MartinFowler)的统一 Harness 框架。
