# Progressive-Rules 设计文档

---

## 辩论概览

| 角色 | 核心立场 | 关键贡献 |
|------|----------|----------|
| **architect** | Rules是"编译器目标" | 提出Enforced/Advisory/Knowledge分层；语言规则是Override而非继承 |
| **philosopher** | 扬弃哲学 + 索引失效风险 | 递归困境分析；递减强制原则；知识作为"被召唤的流" |
| **pragmatist** | 6周实施路线图 | 完整目录结构；frontmatter格式；CLI工具；向后兼容迁移 |
| **critic** | 质疑必要性 | 现有rules已是渐进式；与progressive-docs概念混淆；Golden Principles边界不清 |

---

## 一、设计背景与动机

### 1.1 现有Rules系统的问题

**architect的诊断**：现有rules是"静态Markdown文件"，Agent需要自己解析和应用。规则是"凝固的智慧"，无法适应动态上下文。

**philosopher的批判**：
- **本体论困境**：规则是疆域的投射，而非疆域本身
- **强制性与灵活性的二律背反**：声称universal的规则，实则是语言特定假设的伪装
- **索引坍缩风险**：如果AGENTS.md过于简洁，所有问题都指向同一文档

**critic的质疑**：
> "现有rules系统已经是渐进式的。progressive-rules是在解决一个已经解决的问题，还是在解决一个不存在的问题？"

### 1.2 progressive-rules解决的真实问题

**辩论共识**：progressive-rules必须解决一个**具体的、可描述的失败模式**，而不是为了"渐进式"的概念新颖度。

| 失败模式 | 现有rules的问题 | progressive-rules的解决 |
|----------|----------------|------------------------|
| **规则与验证脱节** | 规则写在Markdown里，但没有人知道是否被遵守 | Enforced规则 = Linter验证，P0阻塞合并 |
| **语言规则继承混乱** | `typescript/coding-style.md`引用`../common/coding-style.md`，但Go和TS的immutability完全不同 | 语言规则独立覆盖，无需引用common |
| **Golden Principles边界模糊** | 哪些规则可机械验证？哪些需要人工审查？ | 明确的三层分类：Enforced/Advisory/Knowledge |
| **规则演进无版本管理** | 规则变更无法追踪，Agent可能看到不一致的规则 | 版本化 + 向后兼容迁移 |

### 1.3 与progressive-docs的关系（辩论焦点）

**architect的立场**：progressive-docs是progressive-rules的"运行时文档"。Rules定义"做什么"（质量断言），docs解释"为什么"（背景知识）。

**critic的质疑**：两套"渐进式"系统是否会造成概念混淆？

**辩论结论**：

```
progressive-docs: 知识的渐进式披露
├── AGENTS.md (入口协议：何时查找)
└── docs/ (文档协议：查找什么)

progressive-rules: 规则的渐进式强制
├── AGENTS.md (引用rules/)
├── rules/ (强制规范 + 机械验证)
└── golden-principles/ (P0断言，可执行)

两者的分工：
- progressive-docs管"知识在哪"
- progressive-rules管"规则是什么+是否遵守"
```

---

## 二、核心设计原则（辩论后修订）

### 2.1 七条融合设计原则

基于辩论，将HARNESS-GUIDE的七条原则扩展为progressive-rules专用原则：

| # | 原则 | 来源 | 说明 |
|---|------|------|------|
| **R1** | 规则即契约 | architect | Rules是机器可执行的断言，而非人类可读的指南 |
| **R2** | 机械验证优于文档约束 | HARNESS-GUIDE | 不能被自动验证的规则 → 降为Advisory或Knowledge |
| **R3** | 层级独立覆盖 | architect + 辩论修订 | 语言规则是Override而非继承扩展，避免共同基类假设 |
| **R4** | 递减强制原则 | philosopher | 新领域强约束，随经验积累释放为默认实践 |
| **R5** | 版本化与向后兼容 | pragmatist | 规则演进需要migration路径，Agent可指定规则版本 |
| **R6** | 索引完备性保障 | philosopher | AGENTS.md必须包含元规则（何时查找），防止索引坍缩 |
| **R7** | 真实失败驱动 | critic | 每条规则必须对应一个具体的、可描述的失败模式 |

### 2.2 层级的辩证定义

**philosopher的分析**：

```
Enforced (P0):
  - 定义：Linter可机械验证，违反 = 阻塞合并
  - 哲学定位：最低保障线，不可妥协
  - 示例：依赖方向、API envelope、禁止空catch

Advisory (P1):
  - 定义：Linter可检测，但只警告不阻塞
  - 哲学定位：专业判断的默认值，不是强制执行
  - 示例：函数长度<50行、文件长度<800行

Knowledge (Docs):
  - 定义：无法自动化，Agent理解后内化执行
  - 哲学定位：背景知识，按需获取
  - 示例：为什么选择这种架构、trade-offs解释
```

**关键辩证关系（philosopher提出）**：

> "机械验证和灵活判断不是对立关系，而是同一质量光谱的两端。真正的设计决策是：这条规则位于光谱的哪一点？"

---

## 三、架构设计

### 3.1 目录结构

```
~/.claude/progressive-rules/
│
├── _registry.json                    # 全局规则注册表（pragmatist设计）
├── _registry.schema.json             # JSON Schema验证
│
├── common/                           # Layer 1: 核心通用原则
│   ├── _meta.yaml                   # 层级元数据
│   ├── _extends.yaml                 # 声明性覆盖关系（空，表示无基类）
│   │
│   ├── agents.md                    # <100行，目录入口
│   ├── coding-style.md
│   ├── security.md
│   ├── testing.md
│   ├── git-workflow.md
│   ├── patterns.md
│   ├── performance.md
│   ├── hooks.md
│   │
│   └── golden-principles/           # P0 Enforced断言
│       ├── GP-001-dep-direction.md
│       ├── GP-002-api-envelope.md
│       └── GP-003-no-empty-catch.md
│
├── typescript/                       # Layer 2: 语言特定覆盖（独立完整）
│   ├── _meta.yaml
│   ├── _extends.yaml                 # 空，声明无需继承common
│   ├── coding-style.md              # TS特定规范（独立完整）
│   ├── testing.md
│   └── golden-principles/           # TS专用的P0 linters
│
├── golang/                           # Layer 2: Go特定覆盖
├── python/                           # Layer 2: Python特定覆盖
├── swift/                            # Layer 2: Swift特定覆盖
│
├── projects/                        # Layer 3: 项目特定规则（未来）
│   └── [project-name]/
│
├── config.yaml                       # Rules全局配置
├── migrations/                       # v1→v2迁移脚本
│
├── cli/                              # 命令行工具
│   ├── main.py
│   ├── validate.py
│   ├── check.py
│   ├── diff.py
│   └── migrate.py
│
├── linters/                          # P0机械验证工具
│   ├── dependency-direction.py
│   ├── secret-scan.py
│   ├── api-envelope.py
│   └── complexity-check.py
│
└── templates/
    ├── rule-template.md
    └── extends-template.yaml
```

**继承优先级**：`projects > [language] > common`（具体覆盖通用）

### 3.2 规则文件格式

```markdown
---
id: GP-001
name: dependency-direction
category: architecture
layer: common
priority: P0
mechanically_verifiable: true
status: active
enforced_by:
  - linter: linters/dependency-direction.py
    ci_gate: pre-merge
  - test: tests/structural/test-dependency-direction.py
applies_to: [golang, typescript, python]
extends: null
deprecated: false
created: 2026-04-05
updated: 2026-04-05
failure_mode: "domain依赖shared时，模块边界模糊，重构风险增加"
---

## GP-001: 依赖方向规则

**规则**: domain → shared → external，禁止反向依赖

**理由**: 单向依赖保证模块边界清晰，便于测试和重构

**失败模式**: domain依赖shared时，模块边界模糊，重构风险增加

**验证方式**:
- 机械验证: `linters/dependency-direction.py`
- CI门禁: pre-merge强制执行

**Counter-example**:
```python
# WRONG: shared依赖domain
from domain.orders.models import Order  # 反向依赖

# CORRECT: domain依赖shared
from shared.cache import RedisCache    # 单向依赖
```
```

### 3.3 注册表设计

```json
{
  "version": "2.0",
  "config": {
    "locked": false,
    "overrides": {}
  },
  "rules": {
    "GP-001": {
      "file": "common/golden-principles/GP-001-dep-direction.md",
      "layer": "common",
      "priority": "P0",
      "mechanically_verifiable": true,
      "enforced_by": ["linters/dependency-direction.py"]
    },
    "GP-002": {
      "file": "typescript/coding-style.md",
      "layer": "typescript",
      "priority": "P0",
      "mechanically_verifiable": true,
      "overrides": "GP-001",
      "enforced_by": ["linters/dependency-direction.py"]
    }
  },
  "layers": {
    "common": { "path": "common/", "priority": 1, "extends": null },
    "typescript": { "path": "typescript/", "priority": 2, "extends": null },
    "golang": { "path": "golang/", "priority": 2, "extends": null },
    "projects": { "path": "projects/", "priority": 3 }
  }
}
```

---

## 四、与progressive-docs的对接

### 4.1 分工边界

| progressive-docs | progressive-rules | 关系 |
|-----------------|------------------|------|
| AGENTS.md (入口) | AGENTS.md 引用 rules/ | 入口协议统一 |
| docs/ (详细文档) | golden-principles/ (可执行断言) | 知识 vs 规范 |
| AUDIT→GENERATE→PROBE | Enforced→Advisory→Knowledge | 流程正交 |

### 4.2 对接点

```
AGENTS.md (入口)
├── "Rules → rules/common/"         ← 指向rules/
├── "Architecture → docs/architecture.md"
└── "Quality Gates → rules/common/golden-principles/"

rules/common/golden-principles/GP-001.md
└── "背景知识 → docs/architecture/dependency-direction.md"
```

### 4.3 关键设计决策

**决策：AGENTS.md是统一的入口，不分progressive-docs还是progressive-rules**

- AGENTS.md不重复"渐进式"概念
- 统一引用：`Rules → rules/`、`Docs → docs/`
- Agent根据引用类型自行判断：该查规则还是该查文档

---

## 五、实施路线图

### Phase 0: 基础设施（Week 1）

**目标**：建立progressive-rules骨架，向后兼容现有rules

| 步骤 | 产出 | 验证标准 |
|------|------|----------|
| 0.1 | 创建 `~/.claude/progressive-rules/` 目录结构 | 目录存在 |
| 0.2 | 迁移5条核心规则（带frontmatter） | `pro rules check --layer common` 可执行 |
| 0.3 | 生成 `_registry.json` | JSON Schema验证通过 |
| 0.4 | 建立符号链接向后兼容 | `~/.claude/rules/` → `~/.claude/progressive-rules/` |

### Phase 1: 机械验证（Week 2-3）

**目标**：实现3个P0 linters

| 步骤 | 产出 | 验证标准 |
|------|------|----------|
| 1.1 | 实现 `dependency-direction.py` linter | `pro rules validate GP-001` |
| 1.2 | 实现 `secret-scan.py` linter | 检测硬编码secret |
| 1.3 | 实现 `api-envelope.py` linter | API响应格式验证 |
| 1.4 | Pre-commit hook集成 | `git commit` 触发P0检查 |

### Phase 2: CI/CD集成（Week 4）

**目标**：质量门禁自动化

| 步骤 | 产出 | 验证标准 |
|------|------|----------|
| 2.1 | GitHub Actions workflow | PR自动触发P0检查 |
| 2.2 | 覆盖率门禁 | coverage < 80% 阻塞合并 |
| 2.3 | 质量看板 | 合规率报告 |

### Phase 3: 语言层级（Week 5-6）

**目标**：建立typescript/golang覆盖

| 步骤 | 产出 | 验证标准 |
|------|------|----------|
| 3.1 | typescript/coding-style.md | 与common的差异清晰标注 |
| 3.2 | golang/coding-style.md | Go特定规范（独立完整） |
| 3.3 | `pro rules diff --layer typescript` | 层级差异可比较 |

### Phase 4: 高级特性（Week 7-8）

**目标**：版本迁移 + GC引擎

| 步骤 | 产出 | 验证标准 |
|------|------|----------|
| 4.1 | v1→v2迁移脚本 | `pro rules migrate --from v1 --to v2` |
| 4.2 | GC扫描引擎 | 定期扫描+自动重构PR |
| 4.3 | 文档生成 | `pro rules docs --rule GP-001` |

---

## 六、关键设计决策记录

### 决策1：语言规则是Override而非继承

**问题**：现有 `typescript/coding-style.md` 使用 `extends ../common/coding-style.md`。但Go的指针receiver vs 不可变对象原则，TS的mutable vs immutable，继承模型假设共同基类存在。

**决策**：语言规则是独立覆盖，每个文件自包含，无需引用 `../common/`。

**理由**：不同语言的idiom可能根本不同，强行继承会造成规则冲突。

### 决策2：AGENTS.md包含元规则

**问题**：philosopher指出"递归困境"——索引的完整性依赖于知识，但索引本身又是激活知识的触发器。

**决策**：AGENTS.md必须包含**元规则**（何时查找），而不仅仅是"展开后能看到什么"的索引。

```markdown
# AGENTS.md

## Rules (progressive-rules)
- P0 Enforced → rules/common/golden-principles/ (必须遵守)
- P1 Advisory → rules/common/coding-style.md (建议遵守)
- Knowledge → docs/ (按需查阅)

## When to Check Rules
- **Before writing code**: Check P0 rules for your language
- **After writing code**: Run `pro rules check --layer [lang] --priority P0`
- **During code review**: Advisor will flag P1 violations
```

### 决策3：Golden Principles必须对应失败模式

**问题**：critic质疑"Golden Principles边界定义不清"。

**决策**：每条Golden Principle必须包含 `failure_mode` 字段。

```markdown
failure_mode: "当domain层依赖shared层时，模块边界模糊导致重构风险增加"
```

**理由**：没有失败模式支撑的规则，是过度设计的风险信号。

### 决策4：验证收益>维护成本检查点

**问题**：critic警告"渐进式加载逻辑本身的维护成本必须低于它带来的价值"。

**决策**：在Phase 0结束时进行ROI评估：
- 如果 `pro rules check` 执行时间 > 5秒，考虑优化
- 如果规则数量 < 20条，简化CLI复杂度
- 如果合规率提升 < 10%，重新评估机械验证的必要性

---

## 七、批评意见与反驳（辩论记录）

### 批评1：现有rules已是渐进式

**critic立场**：分层结构 + AGENTS.md pointer机制已经实现渐进式披露。

**反驳（architect）**：
- 现有分层是**静态包含**，不是**按需激活**
- 没有机械验证，不知道规则是否被遵守
- 没有明确的Enforced/Advisory/Knowledge分类

### 批评2：与progressive-docs概念混淆

**critic立场**：两套"渐进式"系统会造成维护成本叠加。

**辩论结论**：
- progressive-docs管**知识在哪**
- progressive-rules管**规则是什么+是否遵守**
- 分工明确，AGENTS.md统一入口

### 批评3：过度工程化风险

**critic立场**：在没有真实痛点的情况下增加复杂性。

**最终立场**：
- progressive-rules的价值必须在**有Enforced验证的真实场景**中体现
- 如果只有 <10条规则需要Enforced验证，先用简单脚本
- 当规则数量增长到需要系统性管理时，再引入完整CLI

---

## 八、核心反对意见汇总

| 反对意见 | 严重程度 | 缓解措施 |
|----------|----------|----------|
| 现有rules已是渐进式 | 高 | 强调机械验证和Enforced/Advisory/Knowledge分类是新增能力 |
| 与progressive-docs混淆 | 中 | 明确分工边界，AGENTS.md统一入口 |
| Golden Principles边界不清 | 高 | 每条规则必须包含failure_mode字段 |
| 维护复杂性增加 | 中 | Phase 0结束时做ROI评估 |
| 索引坍缩风险 | 高 | AGENTS.md必须包含元规则（何时查找） |

---

## 九、附录：辩论精华摘要

### architect的核心主张

1. **Rules是编译器目标**：机器可执行的质量断言，而非人类可读的指南
2. **三层分类**：Enforced (P0) / Advisory (P1) / Knowledge (Docs)
3. **语言规则独立覆盖**：无需引用../common/，每个文件自包含
4. **版本化与向后兼容**：规则演进需要migration路径
5. **progressive-docs是运行时文档**：Rules定义"做什么"，docs解释"为什么"

### philosopher的核心洞察

1. **扬弃哲学**：继承合理内核，克服不足，在更高层次综合
2. **索引失效风险**：最严峻问题——简洁索引导致无法形成有效查询意图
3. **递归困境**：索引完整性依赖知识，知识激活依赖索引
4. **递减强制原则**：新领域强约束，随经验积累释放为默认实践
5. **知识作为流**：从"被拥有的物"变为"被召唤的流"

### pragmatist的实施承诺

1. **6周路线图**：Phase 0基础设施 → Phase 1机械验证 → Phase 2 CI/CD → Phase 3语言层级 → Phase 4高级特性
2. **向后兼容**：符号链接保持现有rules继续工作
3. **增量迁移**：每条规则单独转换，无破坏性修改
4. **CLI工具**：validate / check / diff / migrate / docs

### critic的核心质疑

1. **最危险误解**："渐进式"本身就是价值，而不去追问"渐进式解决了什么问题"
2. **真实痛点要求**：必须举出现有rules系统无法处理的失败案例
3. **ROI门槛**：验证收益必须 > 维护成本

---

## 十、待解决问题

| 问题 | 负责角色 | 截止日期 |
|------|----------|----------|
| failure_mode如何标准化？ | architect | Phase 0完成前 |
| ROI评估标准是什么？ | team-lead | Phase 0结束时 |
| 如何验证AGENTS.md的元规则完备性？ | philosopher | Phase 0完成前 |
| progressive-docs的AUDIT→PROBE流程与rules验证如何协调？ | pragmatist | Phase 1完成前 |

---

> **本文档由4人辩论小队（architect, philosopher, pragmatist, critic）深度讨论后综合产出**
> **关键修正**：采纳critic的"真实失败驱动"原则，要求每条Golden Principle必须包含failure_mode
> **待决策**：Phase 0结束时进行ROI评估，决定是否继续实施
