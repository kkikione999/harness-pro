# Golden Principles 改造方案

> 三视角辩论综合报告：哲学分析 × 最小化改造 × 魔鬼代言人
> 参照源：阿里云 Qoder Harness Engineering 实践

---

## 一、哲学分析师视角：阿里云的5大核心理念

### 理念 1：验证优先于教导

> "与其教 Agent 怎么做，不如让它自己验证做得对不对。靠代码、linter、测试来保证正确性，而不是靠 LLM 的'直觉'。"

- 阿里云实现：lint-deps + lint-quality + verify_action.py，全部机械执行
- OpenAI 实现：custom linters + structural tests，自动拦截
- **我们现状**：P0 checks（4条规则）已经在做，但只有事后检查，没有事前预防
- **差距**：理念一致，但覆盖面和时机有差距

### 理念 2：约束边界，不约束写法

> "Harness 约束的是架构边界，不是具体写法。在这个边界之内怎么实现，随便。就像管理大型平台团队一样：中心化约束，本地自治。"

- 阿里云实现：Layer 0-4 层级编号，规则只有一条：高层不 import 低层
- OpenAI 实现："opinionated, mechanical rules" + 结构测试
- **我们现状**：CLAUDE.md 有 "200-400 lines typical, 800 max" 等编码风格规则，但**没有架构边界约束**
- **差距**：我们管了文件大小（P0-002），但不管依赖方向。这是最大缺口

### 理念 3：事前预防胜于事后修复

> "层级违反是 Agent 翻车的头号原因。50 行写完再修 vs 写之前问一次，代价差距巨大。"

- 阿里云实现：verify_action.py 在创建文件/添加 import 前先验证合法性
- OpenAI：未明确提及
- **我们现状**：完全没有。P0 checks 只在 milestone 完成后跑
- **差距**：我们只有"事后验尸"，没有"事前体检"

### 理念 4：错误信息即教学

> "一条好的报错，本身就是一次教学。"

- 阿里云实现：报错包含 Layer 编号 + 规则说明 + 具体修复建议
- OpenAI 实现：lint 消息注入修复指令到 agent 上下文
- **我们现状**：P0-001 有 "Fix: Move secrets to environment variables"，但 P0-003/004 基本只是状态报告
- **差距**：部分有，但质量参差不齐

### 理念 5：只进不退的自进化

> "Harness 不是一套只会老化的静态规范，而是一套'只进不退'的自我改进系统。"

- 阿里云实现：Critic 分析失败模式 → Refiner 更新规则 → 下一个 Agent 受益
- OpenAI 实现：recurring background Codex tasks 扫描偏差 → 开重构 PR
- **我们现状**：GC Engine 概念在 CLAUDE.md 中定义，但**未实现**
- **差距**：理念有，执行为零

### 三方哲学对比表

| 理念 | 我们 | 阿里云 | OpenAI |
|------|------|--------|--------|
| 验证优先于教导 | 有（P0 checks） | 有（更全面） | 有（linters+tests） |
| 约束边界不约束写法 | **缺**（只管文件大小） | 有（Layer 依赖方向） | 有（mechanical rules） |
| 事前预防 | **缺** | 有（verify_action） | 未提及 |
| 错误信息即教学 | 部分（P0-001有，其余弱） | 有（模板化） | 有（注入上下文） |
| 自进化系统 | **缺**（概念有，执行零） | 有（Critic→Refiner） | 有（background tasks） |

---

## 二、最小化改造设计师视角：落地路径

### 现有链路验证能力盘点

| Skill | 当前验证 | 缺什么 |
|-------|---------|--------|
| decompose-requirement | 无 | 不需要（纯需求分析） |
| create-plan | 无验证，但有代码阅读（自然发现架构） | 不需要（纯规划） |
| **execute-task** | P0 checks 在 milestone 后跑 | **缺：事前预防、架构边界检查** |
| complete-work | Fresh verification（P0 + tests + lint + build） | **缺：架构边界检查** |
| tdd | 无 lint 集成 | 低优先（execute-task 覆盖） |
| systematic-debugging | 无 lint 集成 | 低优先（debugging 场景特殊） |

### 改造清单（按优先级排序）

#### P0-1: 增强 P0 checks 错误信息质量

- **改动位置**：`.claude/skills/harness-pro-execute-task/scripts/p0-checks.sh`
- **改动量**：小改（每个 check 的 echo 语句增加2-3行）
- **影响范围**：零副作用，纯改善已有输出
- **是否需要新 skill**：否
- **具体做法**：每个 P0 check 的报错信息包含三层：
  1. **What**：检测到什么违规
  2. **Why**：为什么这是违规（规则解释）
  3. **How**：怎么修（具体修复动作）

```
当前 P0-001:
  "CRITICAL P0-001: Hardcoded secrets found in: {file}"
  "Fix: Move secrets to environment variables or secret manager"

改善后 P0-001:
  "CRITICAL P0-001: Hardcoded secrets detected"
  "  File: {file}:{line}"
  "  Why: Secrets in source code leak via git history, logs, and error reports."
  "  Fix: 1) Add to .env file, 2) Reference via process.env.VARIABLE_NAME"
  "  Reference: See security.md Secret Management section"
```

#### P0-2: 新增 P0-005 架构边界检查

- **改动位置**：
  1. `p0-checks.sh` 新增 `check_architecture()` 函数
  2. 项目根目录新增 `.harness/golden-principles/layers.conf`（层级定义文件）
- **改动量**：中改（新增一个函数 + 一个配置文件）
- **影响范围**：如果 layers.conf 不存在则 SKIP（向后兼容）
- **是否需要新 skill**：否
- **具体做法**：
  - layers.conf 格式：`layer_number: directory_pattern`（每行一条）
  - p0-checks.sh 扫描 import 语句，验证方向
  - 如果项目没有 layers.conf → 输出 "SKIP P0-005: No layer definitions found" 并通过

#### P0-3: 在 execute-task 中加入预验证指引

- **改动位置**：`.claude/skills/harness-pro-execute-task/SKILL.md`
- **改动量**：小改（在 Behavioral Guidelines 部分新增一段）
- **影响范围**：影响 worker agent 行为，但不改变流程结构
- **是否需要新 skill**：否
- **具体做法**：在 "1. Think Before Coding" 之后新增一段：

```markdown
### 1.5. Pre-validate Structural Changes

Before creating a file or adding a cross-package import, ask: "is this action legal?"
Run: `bash .claude/skills/harness-pro-execute-task/scripts/p0-checks.sh --pre-check`
The --pre-check flag runs only architecture boundary checks (P0-005), not the full suite.
If it fails, fix the plan before writing any code.

When pre-validation is needed:
- Creating a file in a new directory → YES
- Adding an import from a different package/layer → YES
- Modifying a function body → NO
- Adding a test file → NO
```

#### P0-4: 增加 P0 checks 的 --pre-check 模式

- **改动位置**：`p0-checks.sh`
- **改动量**：小改（加一个参数解析 + 条件执行）
- **影响范围**：零副作用（默认行为不变）
- **具体做法**：`--pre-check` 只跑 P0-005（架构检查），不跑全量

#### P1-1: 失败日志记录

- **改动位置**：`p0-checks.sh` 在 VIOLATIONS > 0 时追加记录
- **改动量**：小改（加几行 echo 到日志文件）
- **影响范围**：零副作用
- **具体做法**：失败时自动 append 到 `.harness/trace/failures/p0-failures.log`
  格式：`{timestamp} | {P0-xxx} | {file} | {violation_summary}`

#### P2-1: Critic→Refiner 自进化循环

- **改动量**：大改（需要新的运行机制）
- **建议**：**延后**。等到 .harness/trace/failures/ 积累了足够数据再实现。
- 当前替代：在 complete-work 的 Worker Discoveries 机制中，鼓励 agent 记录 lint 规则改进建议

#### P2-2: 轨迹编译

- **建议**：**延后**。需要50+次同类任务执行历史才有价值。

### 是否需要新 Skill？

**不需要。** 理由：
1. 预验证 → 是 execute-task 的行为指引（段落新增），不是新 skill
2. 架构边界检查 → 是 P0 checks 的扩展（新增规则），不是新 skill
3. 自进化 → 是未来阶段，现在只需积累数据

---

## 三、魔鬼代言人视角：质疑与辩论

### 质疑 1：架构边界检查是否过度设计？

**质疑**：我们的项目是 Python 脚本 + Markdown 文档仓库。有明确的 Layer 划分吗？为这种项目做 import 方向检查是否值得？

**反方论据**：阿里云的 lint-deps 是面向大型 Go/TypeScript 项目的。我们的 harness-blogs 仓库没有复杂的包依赖关系。

**正方反驳**：Golden Principles 不是为当前仓库设计的——它是为**所有使用我们 skill 链路的项目**设计的。layers.conf 做成可选配置就是正确的：有层级的项目定义它，没有的 SKIP。机制存在但不强制。

**判断**：✅ 做，但做成**可选**。layers.conf 不存在则自动 SKIP。

### 质疑 2：预验证机制会不会拖慢执行？

**质疑**：每个 Change step 前都跑一次检查，增加交互次数，降低执行速度。

**反方论据**：阿里云自己说了"不是每个操作都需要预验证"。如果只在新文件/跨包 import 时验证，触发频率很低，代价可忽略。

**正方反驳**：关键是触发条件——只在结构变更时验证，不在代码修改时。一个 feature 可能只有2-3次触发。

**判断**：✅ 做，但严格限制触发条件。不要做成"每步必验"。

### 质疑 3：Critic→Refiner 现在是否值得做？

**质疑**：我们连 P0 checks 都只有4条规则。在这个基础上建自进化系统，是不是空中楼阁？

**反方论据**：没有数据就没有分析。Critic 需要失败日志才能工作。我们连日志都没开始记。

**判断**：❌ 不做。改为先积累数据（P1-1 失败日志），等有数据再说。

### 质疑 4：三层记忆系统是否必要？

**质疑**：阿里云的三种记忆（情景/程序/失败）听起来很美，但我们的 file-stack 已经覆盖了情景（Worker Discoveries）和程序（plan templates）。加一个正式的三分类系统是过度工程。

**判断**：❌ 不做。file-stack 够用。只需补一个失败日志文件。

### 质疑 5：错误信息改善的 ROI 真的高吗？

**质疑**：改善错误信息听起来是"锦上添花"，不如加新规则来得实在。

**反方论据**：这是**最高 ROI 的改动**。原因：
1. 改动量极小（每个 check 加2-3行文字）
2. 对 agent 自修复能力的提升是指数级的——好的报错让 agent 一次修好，差的报错让它循环3次
3. 阿里云和 OpenAI **都强调**这一点，不是巧合

**判断**：✅ 做，且是第一优先。

### 质疑 6：如果只能做一件事？

**回答**：改善 P0 checks 的错误信息质量（P0-1）。
- 成本最低（改几行文字）
- 收益最高（agent 自修复能力翻倍）
- 零风险（不改逻辑，只改输出）
- 为后续改动打基础（错误信息是所有后续改进的接口）

---

## 四、综合结论：最终改造方案

### Phase 1：立即实施（改动量最小，收益最大）

| # | 改造项 | 改动位置 | 改动量 | 风险 |
|---|--------|---------|--------|------|
| 1 | P0 错误信息增强 | `p0-checks.sh` | 小改 | 零 |
| 2 | P0-005 架构边界检查（可选） | `p0-checks.sh` + `layers.conf` | 中改 | 低（可选配置） |
| 3 | 预验证行为指引 | `execute-task/SKILL.md` | 小改（+1段） | 零 |
| 4 | P0 checks --pre-check 模式 | `p0-checks.sh` | 小改 | 零 |
| 5 | 失败日志记录 | `p0-checks.sh` | 小改 | 零 |

### Phase 2：延后实施（等数据积累）

| # | 改造项 | 前置条件 |
|---|--------|---------|
| 6 | Critic→Refiner 循环 | 失败日志积累50+条 |
| 7 | 轨迹编译 | 同类任务执行3+次 |

### 不做的事

| 项 | 原因 |
|----|------|
| 三种记忆系统 | file-stack 已覆盖，不需要额外分类 |
| 新 skill | 所有改动都在现有 skill 内 |
| 四层验证管道 | 我们的 P0+tests+lint+build 已覆盖4层，无需重构 |
| 质量评分系统 | 等自进化循环建立后再考虑 |

### 核心设计理念总结

我们和阿里云的设计哲学差异根源在于：
- **阿里云**：以"仓库是操作系统"为核心 → 基础设施导向，强调约束和自动化
- **我们**：以"Feature 是 atomic 开发单元"为核心 → 任务导向，强调灵活和自治

两者不矛盾。阿里云的约束是我们的 Feature 执行时的"安全网"：
- Feature 边界由 decompose-requirement 定义（我们的优势）
- Feature 执行时的代码质量由 Golden Principles 保证（阿里云的优势）
- 两者结合：**在 Feature 的自治范围内，用机械化检查兜底**

一句话总结改造原则：

> **不改变 Feature 自治的流程，只在执行边界处加强机械化检查。**
