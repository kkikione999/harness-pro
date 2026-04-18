# Implementer分析

## 1. 现有Skill与Creator能力的映射

| Creator子能力 | 现有Skill | 状态 | 说明 |
|--------------|-----------|------|------|
| 分析代码库 | `harness-pro-create-plan` | ✅ 已有 | Three-Step Code Reading（Step1-3） |
| 生成ARCHITECTURE.md | `harness-pro-decompose-requirement` | ✅ 已有 | skeleton-bootstrap.md + Step 2.5 ARCHITECTURE.md Auto-Update in complete-work |
| 生成lint脚本 | 无 | ❌ 缺失 | p0-checks.sh是手写模板，未自动生成 |
| 生成verify脚本 | 无 | ❌ 缺失 | 无自动生成机制 |
| 审计评分(0-100) | 无 | ❌ 缺失 | 无评分机制 |

**关键发现**：
- Creator的"代码分析"能力已融入`create-plan`的Three-Step Code Reading
- "生成文档"能力已融入`decompose-requirement`的skeleton-bootstrap和`complete-work`的Step 2.5
- **lint脚本和verify脚本生成是主要缺口**

## 2. 现有Skill与Executor能力的映射

| Executor子能力 | 现有Skill | 状态 | 说明 |
|---------------|-----------|------|------|
| 检测CLAUDE.md是否存在 | `harness-pro-decompose-requirement` | ✅ 已有 | Skeleton Check步骤 |
| 不存在就自动调Creator | `harness-pro-decompose-requirement` | ✅ 已有 | Skeleton Check缺失时读取skeleton-bootstrap.md |
| 检测环境 | `harness-pro-complete-work` | ✅ 部分 | Step 1发现项目命令，但非专门的环境检测 |
| 加载上下文 | `harness-pro-create-plan` | ✅ 已有 | 写context.md供worker使用 |
| 制定计划 | `harness-pro-create-plan` | ✅ 已有 | 完整plan.md生成 |
| 人类批准 | `harness-pro-decompose-requirement` | ✅ 已有 | User Clarification Loop |
| 执行 | `harness-pro-execute-task` | ✅ 已有 | Team/Solo/Direct三种模式 |
| 验证 | `harness-pro-complete-work` | ✅ 已有 | Step 1 Fresh Verification |
| 完成 | `harness-pro-complete-work` | ✅ 已有 | Integration + Cleanup |

**关键发现**：
- Executor的"检测→调Creator"能力已完全融入decompose-requirement的Skeleton Check
- 唯一缺口是"环境检测"不够专门化

## 3. 方案A：不新增Skill

### 改造decompose-requirement

**改动点**：
1. 增强Skeleton Check：新增"代码库扫描"逻辑，产出ARCHITECTURE.md和Golden Principles
2. 新增lint脚本生成能力：在bootstrap过程中生成`.harness/golden-principles/layers.conf`和`.harness/golden-principles/p0-rules.md`

**改动文件**：
- `.claude/skills/harness-pro-decompose-requirement/SKILL.md`
- `.claude/skills/harness-pro-decompose-requirement/references/skeleton-bootstrap.md`（新增脚本生成逻辑）

**优点**：
- 所有初始化逻辑集中在一处
- 与现有Skeleton Check流程自然衔接
- 用户只需经过decompose-requirement一个入口

**缺点**：
- SKILL.md变得更复杂（从entry point变成还承担初始化职责）
- Creator的lint/verify生成能力分散在bootstrap而非独立Skill

### 改造create-plan

**改动点**：
1. 在Three-Step Code Reading后新增"生成lint规则"步骤
2. 基于代码库结构自动生成Golden Principles

**改动文件**：
- `.claude/skills/harness-pro-create-plan/SKILL.md`

**优点**：
- 代码分析逻辑本来就在create-plan，lint生成可基于同样上下文
- 不增加decompose-requirement复杂度

**缺点**：
- create-plan的职责变成"分析+生成lint"，不够单一
- lint生成应该是初始化阶段一次性的，不是每次plan都要做

### 方案A结论

**推荐改造decompose-requirement**，因为：
1. skeleton-bootstrap.md已经是"初始化逻辑"的文件，新增lint/verify生成顺理成章
2. create-plan的职责是"制定计划"，不应该承担"生成规则"的职责
3. 初始化是一次性行为，适合放在入口Skill

## 4. 方案B：新增Skill

### 新增harness-pro-initialize Skill

**放置位置**：decompose-requirement之前，作为独立入口

**职责**：
1. 检测CLAUDE.md是否存在
2. 不存在则扫描代码库
3. 生成ARCHITECTURE.md、Golden Principles、lint规则
4. 存在则直接退出，让用户进入decompose-requirement

**改动点**：
- 新增`.claude/skills/harness-pro-initialize/SKILL.md`
- 改造现有skill调用逻辑，先检查CLAUDE.md再决定是否触发initialize

**优点**：
- 职责单一：initialize只做初始化
- 与阿里云Creator/Executor模型对齐
- decompose-requirement保持简洁

**缺点**：
- 新增一个Skill，团队需要维护更多文件
- 初始化是低频操作，可能显得过度设计

### 方案B结论

**不推荐**，理由：
1. 现有decompose-requirement的Skeleton Check已经承担"检测+初始化"职责
2. 新增Skill增加维护成本
3. 阿里云的"Creator自动调"在我们的架构中已经被Skeleton Check替代

## 5. 文件修改清单

### 最小改动（方案A增强decompose-requirement）

#### 1. `.claude/skills/harness-pro-decompose-requirement/references/skeleton-bootstrap.md`

**新增内容**：
```markdown
## 新增：Lint脚本生成

在Scenario B（Existing Project）扫描后，自动生成：

1. `.harness/golden-principles/layers.conf`
   - 基于目录结构推断层
   - 格式：`layer_num  directory_name`

2. `.harness/golden-principles/p0-rules.md`
   - 基于代码语言推断P0规则
   - 包含：文件大小限制、命名规范、禁止反向依赖等
```

#### 2. `.claude/skills/harness-pro-decompose-requirement/SKILL.md`

**改动**：在Skeleton Check步骤增加一行：
```
- Missing → read references/skeleton-bootstrap.md → bootstrap（包含lint脚本生成）→ continue
```

**优点**：只需改一处，Skeleton Check语义不变

### 最小可行MVP（只改一个文件）

**只改skeleton-bootstrap.md**：
- 新增lint脚本生成逻辑
- 不改SKILL.md核心逻辑
- 风险最低，可单独测试

**MVP产出**：
1. CLAUDE.md（已有）
2. docs/ARCHITECTURE.md（已有）
3. **NEW**: `.harness/golden-principles/layers.conf`（自动推断）
4. **NEW**: `.harness/golden-principles/p0-rules.md`（基于语言）

## 6. 优先级排序

| 优先级 | 改动 | 理由 |
|--------|------|------|
| **1. 最小MVP** | 只改skeleton-bootstrap.md | 最低风险，新能力独立测试 |
| **2. 短期** | 增强skeleton-bootstrap.md的lint生成 + 改SKILL.md让它调用 | 完整实现Creator的lint生成能力 |
| **3. 长期** | 新增harness-pro-initialize Skill | 如果初始化逻辑持续膨胀，考虑拆分 |

## 7. 最小可行MVP

**只改一个文件**：`.claude/skills/harness-pro-decompose-requirement/references/skeleton-bootstrap.md`

**能跑什么**：
- 第一次进入项目时（无CLAUDE.md）
- 自动扫描代码库结构
- 生成ARCHITECTURE.md
- **新增**：生成`layers.conf`和`p0-rules.md`
- 然后进入正常的decompose-requirement流程

**不改变任何现有Skill的逻辑**，只是给skeleton-bootstrap.md增加输出物。

---

## 总结

| 问题 | 答案 |
|------|------|
| Creator的"生成文档/脚本"能力融入现有Skill？ | ✅ 文档已融入，❌ lint/verify脚本缺失 |
| 最小化改造方案？ | 增强skeleton-bootstrap.md，新增lint生成逻辑 |
| Executor的"自动调Creator"在哪里？ | 已在decompose-requirement的Skeleton Check，无需改动 |
| MVP是什么？ | 只改skeleton-bootstrap.md一个文件 |
