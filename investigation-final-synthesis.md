# Harness x Superpowers 调查总结：统一重构方案

> 设计哲学：AI 是足够聪明的，流程设计保持简洁，不要设计过多的复杂。

---

## 一、核心发现

三组调查员从不同维度分析后，得出一高度一致的结论：

**Superpowers 和 Harness 不是两套对立的系统，而是同一目标的不同层次。**

| 维度 | Superpowers | Harness | 统一方向 |
|------|------------|---------|---------|
| 设计哲学 | AI辅助人类开发 | AI自主开发 | AI自主，人类只参与意图确认 |
| 流程入口 | brainstorming（全面探索） | decompose-requirement（聚焦拆解） | 后者，更轻量 |
| 质量保障 | Agent间review（主观+客观） | 机械linter（纯客观） | linter打底 + milestone review |
| 文档详细度 | 假设工程师零上下文 | 轻量指引，AI自探索 | 后者，信任AI |
| 用户参与 | 5-7个确认点 | 1-3个确认点 | 后者，单次交接 |

---

## 二、6个核心冲突（按严重度排序）

### HIGH 严重度（3个）

**冲突1：入口混乱**
- Superpowers: `using-superpowers` 全局门卫，1%阈值就触发 brainstorming
- Harness: `decompose-requirement` 只在明确的feature请求时触发
- **解决**：统一入口为 decompose-requirement，移除 using-superpowers 的门卫机制

**冲突2：Artifact 格式不兼容**
- Superpowers: `docs/superpowers/specs/` + `docs/superpowers/plans/`
- Harness: `features/{id}/index.md` + `features/{id}/plan.md`
- **解决**：统一使用 Harness 的 `features/` 目录结构

**冲突3：Feature 粒度不匹配**
- Superpowers: spec粒度灵活，无atomic概念
- Harness: 强制atomic feature，有明确边界和out_of_bound
- **解决**：采用 Harness atomic feature 模型，以 CLAUDE.md 为准

### MEDIUM 严重度（2个）

**冲突4：冗余用户检查点**
- Superpowers: 5-7个确认点（brainstorming确认、plan review、执行方式选择...）
- Harness: 1-3个确认点（仅在 intent→feature 边界）
- **解决**：采用 Harness 单次交接原则，feature确认后AI自主执行

**冲突5：质量检查时机冲突**
- Superpowers: 每个task后做review（per-task）
- Harness: 每个milestone后做lint（per-milestone）
- **解决**：per-milestone review，效率更高，质量不减

### LOW 严重度（1个）

**冲突6：文档哲学差异**
- Superpowers: 假设工程师零上下文，详尽文档
- Harness: 轻量指引，信任AI探索
- **解决**：轻量指引，不做过度文档

---

## 三、统一 Skill 架构：14 → 6

### 现状 vs 目标

| 当前 Superpowers (14 skills) | 统一架构 (6 skills) | 动作 |
|------------------------------|---------------------|------|
| using-superpowers | (移除) | 门卫功能合并到 decompose-requirement |
| brainstorming | (合并) | 合并到 decompose-requirement |
| decompose-requirement | **decompose-requirement** | 保留，作为统一入口 |
| writing-plans | (合并) | 合并到 create-plan |
| plan-feature | (合并) | 与 writing-plans 重复 |
| subagent-driven-development | (移除) | 过度工程，信任AI用TDD直接执行 |
| execute-plan | (合并) | 合并到 execute-task |
| executing-plans | (移除) | 与 execute-plan 重复 |
| finishing-a-development-branch | (合并) | 合并到 complete-work |
| verification-before-completion | (合并) | 合并到 complete-work |
| test-driven-development | **test-driven-development** | 保留，核心质量铁律 |
| systematic-debugging | **systematic-debugging** | 保留，核心调试方法 |
| requesting-code-review | (移除) | milestone review替代 |
| receiving-code-review | (移除) | milestone review替代 |
| using-git-worktrees | (移除) | 过度工程 |
| dispatching-parallel-agents | (移除) | 内建能力，无需独立skill |
| writing-skills | (移除) | 元skill，超出范围 |

### 6个统一 Skill 定义

```
用户需求 → [1.decompose] → [2.create-plan] → [3.execute-task] ← [5.debug]
                                                            ↓
                                                    [4.complete-work]
```

#### Skill 1: decompose-requirement（需求拆解）
- **用途**: 将用户需求转换为 atomic feature 定义
- **触发**: 任何新功能、bug修复、变更请求
- **替代**: brainstorming + using-superpowers 门卫
- **关键行为**: 探索现有feature → 逐个澄清 → 提出atomic feature + 验收标准 → 用户确认
- **质量**: checklist验证feature的atomic性

#### Skill 2: create-plan（生成计划）
- **用途**: 从atomic feature生成轻量执行计划
- **触发**: atomic feature确认后
- **替代**: writing-plans + plan-feature
- **关键行为**: 读feature定义 → 定位文件 → 生成bite-sized task → 保存到 `.harness/file-stack/plan.md`
- **质量**: 自验证，不做subagent review循环

#### Skill 3: execute-task（执行实现）
- **用途**: 用TDD纪律执行计划
- **触发**: plan存在且准备执行
- **替代**: subagent-driven-development + execute-plan + executing-plans
- **关键行为**: 按plan逐步执行 → 每步TDD(RED→GREEN→REFACTOR) → 频繁commit → 更新plan进度
- **质量**: TDD铁律 + milestone边界review

#### Skill 4: test-driven-development（测试驱动）
- **用途**: 强制RED→GREEN→REFACTOR循环
- **触发**: 即将写/改任何生产代码时
- **铁律**: 没有失败的测试，就没有生产代码

#### Skill 5: systematic-debugging（系统调试）
- **用途**: 科学方法找根因再修复
- **触发**: 遇到bug、测试失败、异常行为时
- **铁律**: 没有根因调查，就没有修复
- **4阶段**: 根因调查 → 模式分析 → 假设验证 → 实现

#### Skill 6: complete-work（完成工作）
- **用途**: 验证完成 + 处理集成
- **触发**: 所有task完成且测试通过
- **替代**: finishing-a-development-branch + verification-before-completion
- **关键行为**: 运行新鲜验证（测试/lint/build）→ 提交集成选项 → 执行 → 清理
- **铁律**: 没有新鲜验证证据，就没有完成声明

---

## 四、统一质量体系：3层极简

```
Layer 1: TDD 铁律（实现过程中）
  → 每行代码都有测试证明

Layer 2: Mechanical Linter（milestone边界 + 提交前）
  → P0 规则机械验证，阻塞合并

Layer 3: Milestone Review（milestone完成时）
  → 单次code-reviewer pass，检查spec合规 + 代码质量

GC Engine: 自动技术债管理
  → 周期扫描，自动开PR修复P1问题
```

**移除的冗余**:
- ❌ 每task的code review（过度）
- ❌ Spec Reviewer + Code Quality Reviewer 双subagent（合并为1个）
- ❌ requesting/receiving-code-review 独立skill（milestone review替代）
- ❌ Progressive-rules CLI工具和registry（过度工程）

---

## 五、迁移路径

| 阶段 | 动作 | 风险 |
|------|------|------|
| Phase 1 | 实现 decompose-requirement，替代 brainstorming 入口 | 低 |
| Phase 2 | 简化 writing-plans → create-plan（移除subagent review） | 低 |
| Phase 3 | 移除 subagent-driven-development，信任AI + TDD | 中 |
| Phase 4 | 合并 execute-plan/executing-plans → execute-task | 低 |
| Phase 5 | 简化 finishing-branch → complete-work | 低 |
| Phase 6 | 废弃冗余skill（code-review skills, worktrees, parallel-agents） | 低 |

---

## 六、关键设计决策记录

| 决策 | 选择 | 原因 |
|------|------|------|
| 入口skill | decompose-requirement | 比brainstorming更聚焦，避免过度探索 |
| 用户参与点 | 单次交接（feature确认后自主） | 信任AI，减少流程中断 |
| 计划详细度 | 轻量指引（非详尽文档） | AI足够聪明，不需要手把手 |
| 质量机制 | TDD + linter + milestone review | 3层覆盖所有需求，不多不少 |
| Artifact位置 | features/{id}/ | Harness的feature-centric模型更合理 |
| Subagent使用 | 移除per-task review | 过度工程，milestone review足够 |
| 文档格式 | Harness plan.md 结构 | 统一格式减少认知负载 |

---

## 七、调查来源

- [Phase 1: 流程冲突分析](investigation-phase1-process-conflicts.md) — process-analyst
- [Phase 2: 质量体系差距分析](investigation-phase2-quality-gaps.md) — quality-architect
- [Phase 3: 简化统一设计](investigation-phase3-simplified-design.md) — simplification-designer
