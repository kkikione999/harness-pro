# Superpowers 完整调用链路图

> 基于 superpowers v5.0.7 全部 14 个 Skill 的分析
> 生成日期: 2026-04-16

---

## 一、全局流程图（主生命周期）

```
用户消息
  │
  ▼
┌──────────────────────────────────┐
│  using-superpowers               │  ◄── 入口守卫：检查是否有 Skill 适用
│  (Gate Keeper)                   │      即使只有 1% 可能也必须触发
│                                  │
│  优先级：                         │
│  1. 用户指令 (CLAUDE.md)          │
│  2. Superpowers Skills           │
│  3. 默认系统提示词                │
│                                  │
│  Skill 优先级：                   │
│  Process Skills 先于              │
│  Implementation Skills           │
└──────────┬───────────────────────┘
           │
           ▼
   ┌───────┴────────┐
   │ 任务类型判断     │
   └───┬────┬────┬───┘
       │    │    │
   ┌───▼┐ ┌▼──┐ ┌▼───────┐
   │创意 │ │Bug│ │计划执行  │
   │任务 │ │调试│ │任务     │
   └─┬──┘ └┬──┘ └┬───────┘
     │     │     │
     ▼     ▼     ▼
```

---

## 二、完整生命周期：从创意到交付

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SUPERPOWERS 完整开发生命周期                           │
└─────────────────────────────────────────────────────────────────────────┘

 Phase 1              Phase 2              Phase 3              Phase 4
 DESIGN               PLAN                EXECUTE              FINISH
 ─────────            ─────────           ─────────            ─────────

┌──────────┐     ┌──────────┐     ┌──────────────────┐    ┌──────────┐
│brainstorm│────▶│writing   │────▶│subagent-driven   │───▶│finishing │
│  -ing    │     │  -plans  │     │  -development    │    │  -branch │
│          │     │          │     │                  │    │          │
│ 9 步     │     │ Plan doc │     │ per Task:        │    │ 4 选项   │
│ 检查清单  │     │ + Self   │     │  implementer     │    │ Merge/PR │
│          │     │  Review  │     │  spec-reviewer   │    │ Keep/    │
│ 输出:     │     │          │     │  code-reviewer   │    │  Discard │
│ spec.md  │     │ 输出:     │     │                  │    │          │
│          │     │ plan.md  │     │ 输出:             │    │ 输出:     │
│ 触发:     │     │          │     │  实现代码+测试     │    │  集成结果  │
│ next:    │     │ 触发:     │     │                  │    │          │
│ writing  │     │ next:    │     │ 触发:             │    │ 清理:     │
│  -plans  │     │ subagent │     │ finishing-branch  │    │ worktree │
│          │     │  或       │     │                  │    │          │
└──────────┘     │ executing│     └──────────────────┘    └──────────┘
                 │  -plans  │
                 └──────────┘

贯穿全过程的支撑 Skills:
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ using-git        │  │ test-driven      │  │ systematic       │
│  -worktrees      │  │  -development    │  │  -debugging      │
│                  │  │                  │  │                  │
│ 被调用时机:       │  │ TDD Red-Green    │  │ 4 Phase:         │
│ • brainstorming  │  │  -Refactor       │  │ • Root Cause     │
│   设计确认后      │  │                  │  │ • Pattern        │
│ • subagent-driven│  │ 被 implementer   │  │ • Hypothesis     │
│   执行前          │  │  subagent 使用   │  │ • Implementation │
│ • executing-plans│  │                  │  │                  │
│   执行前          │  │                  │  │                  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 三、brainstorming 详细流程

```
用户: "我想做 X"
        │
        ▼
┌──────────────────────────────────────────────────┐
│  brainstorming (Phase 1: DESIGN)                  │
│                                                   │
│  Checklist (每项创建 TodoWrite 任务):               │
│                                                   │
│  1. Explore project context                       │
│     工具: Read, Glob, Grep, Bash(git log)          │
│                                                   │
│  2. Offer Visual Companion?                       │
│     条件: 涉及视觉问题                              │
│     工具: Bash(start-server.sh)                    │
│     ▸ 独立消息，不与其他内容合并                      │
│                                                   │
│  3. Ask clarifying questions (一次一个)             │
│     工具: AskUserQuestion / 直接对话                │
│                                                   │
│  4. Propose 2-3 approaches                        │
│     输出: 带推荐理由的方案对比                        │
│                                                   │
│  5. Present design sections                       │
│     逐段呈现，每段确认                               │
│     工具: AskUserQuestion                          │
│                                                   │
│  6. Write design doc                              │
│     保存到: docs/superpowers/specs/                │
│     工具: Write                                    │
│     然后: Bash(git commit)                         │
│                                                   │
│  7. Spec self-review (inline 修复)                 │
│     • Placeholder scan (TBD/TODO)                 │
│     • Internal consistency                        │
│     • Scope check                                 │
│     • Ambiguity check                             │
│                                                   │
│  8. User reviews written spec                     │
│     工具: AskUserQuestion                          │
│                                                   │
│  9. ▶ Invoke writing-plans skill                  │
│     ★ 终态：只能调用 writing-plans                   │
│        不能调用任何其他实现 Skill                     │
└──────────────────────────────────────────────────┘
```

---

## 四、writing-plans 详细流程

```
brainstorming 完成 (spec.md 已批准)
        │
        ▼
┌──────────────────────────────────────────────────┐
│  writing-plans (Phase 2: PLAN)                    │
│                                                   │
│  Scope Check:                                     │
│  ├─ 单一子系统 → 继续写 plan                       │
│  └─ 多个独立子系统 → 建议拆分为多个 plan             │
│                                                   │
│  File Structure:                                  │
│  先规划文件结构，再分解任务                           │
│                                                   │
│  Plan Document:                                   │
│  ┌─────────────────────────────────────────┐      │
│  │ Header:                                 │      │
│  │   Goal / Architecture / Tech Stack      │      │
│  │                                         │      │
│  │ Per Task:                               │      │
│  │   Files (Create/Modify/Test)            │      │
│  │   Steps (checkbox, 2-5 min each)        │      │
│  │     - [ ] Write failing test (含代码)    │      │
│  │     - [ ] Run test to verify fail       │      │
│  │     - [ ] Write minimal implementation  │      │
│  │     - [ ] Run test to verify pass       │      │
│  │     - [ ] Commit                        │      │
│  └─────────────────────────────────────────┘      │
│                                                   │
│  保存到: docs/superpowers/plans/                   │
│                                                   │
│  Self-Review (自己检查，不用 subagent):              │
│  1. Spec coverage (每个需求有对应 Task?)             │
│  2. Placeholder scan                              │
│  3. Type consistency (类型/签名前后一致?)            │
│                                                   │
│  输出选项:                                         │
│  ┌───────────────────────────────────────┐        │
│  │ 1. Subagent-Driven (recommended)      │        │
│  │    ▸ superpowers:subagent-driven-dev  │        │
│  │                                       │        │
│  │ 2. Inline Execution                   │        │
│  │    ▸ superpowers:executing-plans      │        │
│  └───────────────────────────────────────┘        │
│                                                   │
│  用户选择 → 触发对应 Skill                          │
└──────────────────────────────────────────────────┘
```

---

## 五、subagent-driven-development 详细流程（核心执行引擎）

```
Plan 已写好，用户选择了 "Subagent-Driven"
        │
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│  subagent-driven-development (Phase 3: EXECUTE)                     │
│                                                                     │
│  前置: using-git-worktrees (创建隔离工作区)                           │
│        工具: Bash(git worktree add), Bash(npm install/cargo build)   │
│        验证: Bash(git check-ignore), Bash(测试套件)                   │
│                                                                     │
│  ════════════════ Per Task 循环 ════════════════                     │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  Step A: Dispatch Implementer Subagent                     │    │
│  │  ┌────────────────────────────────────────────────────┐    │    │
│  │  │ Prompt: ./implementer-prompt.md                    │    │    │
│  │  │ 工具: Task (general-purpose agent)                  │    │    │
│  │  │ 内容: 完整 Task 文本 + 上下文 + 目录路径             │    │    │
│  │  │                                                    │    │    │
│  │  │ 实现: 使用 test-driven-development                 │    │    │
│  │  │   RED → GREEN → REFACTOR                           │    │    │
│  │  │   工具: Write(测试), Bash(运行测试),                 │    │    │
│  │  │         Edit(实现), Bash(git commit)                │    │    │
│  │  │                                                    │    │    │
│  │  │ Self-Review: 完整性/质量/纪律/测试                   │    │    │
│  │  │                                                    │    │    │
│  │  │ 返回状态:                                           │    │    │
│  │  │  DONE / DONE_WITH_CONCERNS /                       │    │    │
│  │  │  BLOCKED / NEEDS_CONTEXT                           │    │    │
│  │  └────────────────────────────────────────────────────┘    │    │
│  │                          │                                  │    │
│  │              ┌───────────┴──────────┐                      │    │
│  │              │ 有问题?               │                      │    │
│  │              └───┬─────────┬────────┘                      │    │
│  │                  │         │                               │    │
│  │           NEEDS_CONTEXT   BLOCKED                          │    │
│  │           提供上下文重发   升级模型/拆分/上报                 │    │
│  │                  │         │                               │    │
│  │                  ▼         ▼                               │    │
│  │              DONE / DONE_WITH_CONCERNS                     │    │
│  │                          │                                  │    │
│  │                          ▼                                  │    │
│  │  Step B: Dispatch Spec Reviewer Subagent                   │    │
│  │  ┌────────────────────────────────────────────────────┐    │    │
│  │  │ Prompt: ./spec-reviewer-prompt.md                  │    │    │
│  │  │ 工具: Task (general-purpose agent)                  │    │    │
│  │  │ 职责: 验证代码是否匹配规格 (不多不少)                 │    │    │
│  │  │                                                    │    │    │
│  │  │ 检查: Read(实际代码) → 逐行比对需求                   │    │    │
│  │  │   • Missing requirements                           │    │    │
│  │  │   • Extra/unneeded work                            │    │    │
│  │  │   • Misunderstandings                              │    │    │
│  │  │                                                    │    │    │
│  │  │ 返回: ✅ Spec compliant / ❌ Issues found           │    │    │
│  │  └────────────────────────────────────────────────────┘    │    │
│  │                          │                                  │    │
│  │                 ┌───────┴───────┐                          │    │
│  │                 │ Spec 合规?     │                          │    │
│  │                 └───┬───────┬───┘                          │    │
│  │                     │       │                              │    │
│  │                    YES      NO → Implementer 修复           │    │
│  │                     │            → 重新 Spec Review         │    │
│  │                     ▼                                      │    │
│  │  Step C: Dispatch Code Quality Reviewer Subagent           │    │
│  │  ┌────────────────────────────────────────────────────┐    │    │
│  │  │ Prompt: ./code-quality-reviewer-prompt.md          │    │    │
│  │  │ 模板: requesting-code-review/code-reviewer.md      │    │    │
│  │  │ 工具: Task (superpowers:code-reviewer)              │    │    │
│  │  │ 职责: 验证代码质量 (整洁、可测试、可维护)             │    │    │
│  │  │                                                    │    │    │
│  │  │ 输入: Bash(git diff BASE_SHA..HEAD_SHA)            │    │    │
│  │  │ 检查:                                              │    │    │
│  │  │   • Code Quality (DRY/错误处理/类型安全)            │    │    │
│  │  │   • Architecture (设计/扩展性/性能/安全)            │    │    │
│  │  │   • Testing (真实测试/边缘情况/集成测试)             │    │    │
│  │  │   • Requirements (完整性/无 scope creep)            │    │    │
│  │  │                                                    │    │    │
│  │  │ 返回: Strengths + Issues                           │    │    │
│  │  │   Critical (Must Fix) / Important (Should Fix)     │    │    │
│  │  │   Minor (Nice to Have) + Assessment                │    │    │
│  │  └────────────────────────────────────────────────────┘    │    │
│  │                          │                                  │    │
│  │                 ┌───────┴───────┐                          │    │
│  │                 │ 质量通过?       │                          │    │
│  │                 └───┬───────┬───┘                          │    │
│  │                     │       │                              │    │
│  │                    YES      NO → Implementer 修复           │    │
│  │                     │            → 重新 Quality Review      │    │
│  │                     ▼                                      │    │
│  │              Mark Task Complete                            │    │
│  │              工具: TaskUpdate                              │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                           │                                         │
│                  ┌───────┴───────┐                                 │
│                  │ 还有 Task?     │                                 │
│                  └───┬───────┬───┘                                 │
│                      │       │                                     │
│                     YES      NO                                    │
│                      │       │                                     │
│              回到 Step A    ▼                                      │
│                          Final Code Review                         │
│                          工具: Task (code-reviewer)                 │
│                          对整个实现做最终审查                         │
│                               │                                    │
│                               ▼                                    │
│                  finishing-a-development-branch                     │
│                                                                     │
│  ═════════════════════════════════════════════                      │
│                                                                     │
│  Model Selection 策略:                                              │
│  ┌──────────────────────────────────────────┐                      │
│  │ 机械实现 (1-2 files, 完整 spec) → 快模型  │                      │
│  │ 集成协调 (多文件, 模式匹配)    → 标准模型  │                      │
│  │ 架构/设计/审查                 → 最强模型  │                      │
│  └──────────────────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 六、executing-plans 详细流程（替代执行路径）

```
用户选择了 "Inline Execution"
        │
        ▼
┌──────────────────────────────────────────────────┐
│  executing-plans                                  │
│                                                   │
│  前置: using-git-worktrees                        │
│                                                   │
│  Step 1: Load & Review Plan                      │
│    工具: Read(plan file)                          │
│    如有疑虑 → AskUserQuestion                     │
│    无疑虑 → TaskCreate (所有 Tasks)                │
│                                                   │
│  Step 2: Execute Tasks (顺序执行)                 │
│    每个 Task:                                     │
│    1. TaskUpdate(in_progress)                     │
│    2. 严格按 Plan 步骤执行                         │
│       工具: Write, Edit, Bash, Read               │
│    3. 运行验证命令                                 │
│       工具: Bash(测试命令)                          │
│    4. TaskUpdate(completed)                       │
│                                                   │
│  Step 3: finishing-a-development-branch           │
│                                                   │
│  遇到阻塞时:                                       │
│    STOP → 向用户求助，不要猜测                      │
└──────────────────────────────────────────────────┘
```

---

## 七、systematic-debugging 详细流程

```
遇到 Bug / 测试失败 / 异常行为
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│  systematic-debugging                                        │
│                                                              │
│  铁律: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Phase 1: Root Cause Investigation                   │     │
│  │                                                     │     │
│  │ 1. Read Error Messages                              │     │
│  │    工具: Read(错误日志/stack trace)                   │     │
│  │                                                     │     │
│  │ 2. Reproduce Consistently                           │     │
│  │    工具: Bash(复现命令)                               │     │
│  │                                                     │     │
│  │ 3. Check Recent Changes                             │     │
│  │    工具: Bash(git diff, git log)                     │     │
│  │                                                     │     │
│  │ 4. Multi-Component: Add Diagnostic                  │     │
│  │    工具: Edit(添加诊断日志)                           │     │
│  │    工具: Bash(运行收集证据)                           │     │
│  │                                                     │     │
│  │ 5. Trace Data Flow (backward)                       │     │
│  │    参考: root-cause-tracing.md                      │     │
│  │    工具: Read, Grep(追踪调用链)                      │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                          ▼                                    │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Phase 2: Pattern Analysis                           │     │
│  │                                                     │     │
│  │ 1. Find Working Examples                            │     │
│  │    工具: Grep, Glob(搜索类似代码)                     │     │
│  │                                                     │     │
│  │ 2. Compare Against References                       │     │
│  │    工具: Read(参考实现，完整阅读)                     │     │
│  │                                                     │     │
│  │ 3. Identify Differences                             │     │
│  │ 4. Understand Dependencies                         │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                          ▼                                    │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Phase 3: Hypothesis & Testing                       │     │
│  │                                                     │     │
│  │ 1. Form Single Hypothesis (写下来)                   │     │
│  │ 2. Test Minimally (最小变更)                         │     │
│  │    工具: Edit, Bash(验证)                            │     │
│  │ 3. Verify Before Continuing                         │     │
│  │    ✅ → Phase 4                                     │     │
│  │    ❌ → 新假设 (回到 Phase 3)                        │     │
│  └──────────────────────┬──────────────────────────────┘     │
│                          ▼                                    │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Phase 4: Implementation                             │     │
│  │                                                     │     │
│  │ 1. Create Failing Test (★ test-driven-development)  │     │
│  │    工具: Write(测试文件)                              │     │
│  │    工具: Bash(运行测试，确认失败)                     │     │
│  │                                                     │     │
│  │ 2. Implement Single Fix (只改根因)                   │     │
│  │    工具: Edit(修复代码)                               │     │
│  │                                                     │     │
│  │ 3. Verify Fix                                       │     │
│  │    工具: Bash(运行测试套件)                           │     │
│  │                                                     │     │
│  │ 4. Fix 不工作?                                      │     │
│  │    < 3 次 → 回到 Phase 1                            │     │
│  │    ≥ 3 次 → 质疑架构 (与用户讨论)                    │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                              │
│  辅助文件:                                                    │
│  • root-cause-tracing.md — 反向追踪技术                       │
│  • defense-in-depth.md — 多层验证                             │
│  • condition-based-waiting.md — 条件轮询替代 timeout           │
│  • find-polluter.sh — 查找测试污染脚本                        │
└──────────────────────────────────────────────────────────────┘
```

---

## 八、test-driven-development 详细流程（微观循环）

```
被 implementer subagent 调用
        │
        ▼
┌──────────────────────────────────────────────────┐
│  test-driven-development                         │
│                                                  │
│  铁律: NO PRODUCTION CODE WITHOUT A FAILING TEST │
│                                                  │
│  ┌─────────┐                                     │
│  │  RED    │ 写一个最小化失败测试                  │
│  │         │ 工具: Write(测试文件)                 │
│  └────┬────┘                                     │
│       ▼                                          │
│  ┌──────────────┐                                │
│  │ Verify RED   │ 确认测试失败 (不是因为 typo)     │
│  │              │ 工具: Bash(运行测试)              │
│  └────┬─────────┘                                │
│       │                                          │
│   失败? ──── No (通过了?) → 修测试，重来          │
│   Yes │                                          │
│       ▼                                          │
│  ┌──────────┐                                    │
│  │  GREEN   │ 写最少的代码让测试通过               │
│  │          │ 工具: Edit(实现代码)                 │
│  └────┬─────┘                                    │
│       ▼                                          │
│  ┌───────────────┐                               │
│  │ Verify GREEN  │ 确认通过 + 其他测试不坏         │
│  │               │ 工具: Bash(运行全部测试)        │
│  └────┬──────────┘                               │
│       │                                          │
│   通过? ──── No → 修代码，不修测试               │
│   Yes │                                          │
│       ▼                                          │
│  ┌────────────┐                                  │
│  │  REFACTOR  │ 清理重复 / 改善命名 / 提取辅助     │
│  │            │ 工具: Edit                        │
│  └────┬───────┘                                  │
│       │                                          │
│       ▼                                          │
│  Verify GREEN (保持通过)                          │
│  工具: Bash(运行全部测试)                          │
│       │                                          │
│       ▼                                          │
│  下一个失败测试 → 回到 RED                        │
└──────────────────────────────────────────────────┘
```

---

## 九、finishing-a-development-branch 详细流程

```
所有 Tasks 完成，测试通过
        │
        ▼
┌──────────────────────────────────────────────────┐
│  finishing-a-development-branch                  │
│                                                  │
│  Step 1: Verify Tests                            │
│    工具: Bash(测试套件)                            │
│    失败 → STOP，先修测试                           │
│    通过 → 继续                                    │
│                                                  │
│  Step 2: Determine Base Branch                   │
│    工具: Bash(git merge-base)                     │
│                                                  │
│  Step 3: Present 4 Options                       │
│    ┌──────────────────────────────────────────┐  │
│    │ 1. Merge locally to <base-branch>        │  │
│    │    工具: Bash(git checkout, merge)        │  │
│    │    验证: Bash(测试)                        │  │
│    │    清理: Bash(git branch -d, worktree rm) │  │
│    │                                          │  │
│    │ 2. Push + Create PR                      │  │
│    │    工具: Bash(git push -u)                │  │
│    │    工具: Bash(gh pr create)               │  │
│    │    保留 worktree                          │  │
│    │                                          │  │
│    │ 3. Keep as-is                            │  │
│    │    报告分支名和 worktree 路径              │  │
│    │    保留 worktree                          │  │
│    │                                          │  │
│    │ 4. Discard (需输入 "discard" 确认)        │  │
│    │    工具: Bash(git checkout, branch -D)    │  │
│    │    清理: Bash(git worktree remove)        │  │
│    └──────────────────────────────────────────┘  │
│                                                  │
│  Step 5: Cleanup Worktree (Option 1,4)           │
│    工具: Bash(git worktree remove)                │
└──────────────────────────────────────────────────┘
```

---

## 十、横向辅助 Skills

### dispatching-parallel-agents

```
多个独立问题需要并行处理
        │
        ▼
┌──────────────────────────────────────────────────┐
│  dispatching-parallel-agents                     │
│                                                  │
│  判断: 多个失败? 独立? 无共享状态?                  │
│                                                  │
│  Pattern:                                        │
│  1. Identify Independent Domains                 │
│     工具: Read, Grep(分析失败文件)                 │
│                                                  │
│  2. Create Focused Agent Tasks                   │
│     每个 Agent: 一个 scope + 清晰目标 + 约束      │
│                                                  │
│  3. Dispatch in Parallel                         │
│     工具: Task × N (同时发出多个)                  │
│                                                  │
│  4. Review & Integrate                           │
│     工具: Read(每个 Agent 的输出)                  │
│     工具: Bash(git diff, 测试套件)                 │
└──────────────────────────────────────────────────┘
```

### requesting-code-review

```
需要代码审查
        │
        ▼
┌──────────────────────────────────────────────────┐
│  requesting-code-review                          │
│                                                  │
│  1. Get git SHAs                                 │
│     工具: Bash(git rev-parse)                     │
│                                                  │
│  2. Dispatch code-reviewer subagent              │
│     工具: Task (superpowers:code-reviewer)        │
│     模板: code-reviewer.md                       │
│     输入: WHAT/BASE_SHA/HEAD_SHA/DESCRIPTION     │
│                                                  │
│  3. Act on feedback                              │
│     Critical → 立即修复                           │
│     Important → 修复后继续                        │
│     Minor → 记录待处理                            │
│                                                  │
│  修复工具: Edit, Write, Bash                      │
└──────────────────────────────────────────────────┘
```

### receiving-code-review

```
收到 Code Review 反馈
        │
        ▼
┌──────────────────────────────────────────────────┐
│  receiving-code-review                           │
│                                                  │
│  流程:                                           │
│  READ → UNDERSTAND → VERIFY → EVALUATE →        │
│  RESPOND → IMPLEMENT                             │
│                                                  │
│  禁止: "You're right!" / "Great point!"          │
│       (表演性赞同，不验证就实现)                    │
│                                                  │
│  对不明确的反馈:                                   │
│    STOP → 问清楚 ALL items → 再实现               │
│                                                  │
│  外部反馈: 先验证再实现                             │
│    工具: Grep(检查是否真的被使用)                   │
│    工具: Read(检查上下文)                           │
│                                                  │
│  YAGNI Check:                                    │
│    "实现得更好" → grep 实际使用 → 未使用就删除      │
│                                                  │
│  Push Back 条件:                                  │
│    破坏现有功能 / 缺乏上下文 / 违反 YAGNI          │
│    技术上不正确 / 有遗留兼容原因                    │
└──────────────────────────────────────────────────┘
```

### verification-before-completion

```
即将声称 "完成了"
        │
        ▼
┌──────────────────────────────────────────────────┐
│  verification-before-completion                  │
│                                                  │
│  铁律: NO COMPLETION CLAIMS WITHOUT FRESH        │
│       VERIFICATION EVIDENCE                      │
│                                                  │
│  Gate Function:                                  │
│  1. IDENTIFY: 什么命令能证明?                     │
│  2. RUN: 执行完整命令 (新鲜的)                     │
│     工具: Bash(测试/lint/build)                   │
│  3. READ: 完整输出 + exit code                    │
│  4. VERIFY: 输出确认声明?                         │
│  5. ONLY THEN: 做出声明                           │
│                                                  │
│  必须验证的场景:                                   │
│  • "Tests pass" → 需要测试命令输出: 0 failures    │
│  • "Bug fixed" → 需要原始症状测试通过              │
│  • "Build succeeds" → 需要构建命令: exit 0        │
│  • "Requirements met" → 逐条 checklist           │
└──────────────────────────────────────────────────┘
```

---

## 十一、Skill 间调用关系总图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SKILL 调用关系拓扑                                │
└─────────────────────────────────────────────────────────────────────────┘

                          ┌─────────────────────┐
                          │  using-superpowers   │
                          │  (全局入口守卫)       │
                          └──────────┬──────────┘
                                     │
                 ┌───────────────────┼───────────────────┐
                 │                   │                   │
          ┌──────▼──────┐     ┌─────▼──────┐     ┌─────▼──────────┐
          │ brainstorming│     │ systematic │     │  writing       │
          │              │     │ debugging  │     │  -skills       │
          │              │     │            │     │  (创建新 Skill) │
          └──────┬───────┘     └─────┬──────┘     └───────────────┘
                 │                   │
                 │                   │ 调用
                 │                   ▼
                 │            ┌──────────────┐
                 │            │ test-driven  │
                 │            │ -development │
                 │            └──────────────┘
                 │                   ▲
                 ▼                   │
          ┌──────────────┐          │
          │ writing      │          │
          │ -plans       │          │
          └──────┬───────┘          │
                 │                   │
         ┌───────┴───────┐          │
         │               │          │
  ┌──────▼──────┐ ┌─────▼────────┐ │
  │ subagent    │ │ executing    │ │
  │ -driven     │ │ -plans       │ │
  │ -development│ │              │ │
  └──────┬──────┘ └──────┬───────┘ │
         │               │         │
         │  调用 3 类     │         │
         │  subagent:    │         │
         │               │         │
  ┌──────▼──────┐        │         │
  │ implementer │────────┘         │
  │ subagent    │──→ test-driven   │
  │             │    -development  │
  ├─────────────┤                  │
  │ spec        │                  │
  │ reviewer    │                  │
  │ subagent    │                  │
  ├─────────────┤                  │
  │ code quality│                  │
  │ reviewer    │                  │
  │ subagent    │──→ requesting    │
  │             │    -code-review  │
  └──────┬──────┘                  │
         │                         │
         ▼                         │
  ┌──────────────┐                 │
  │ finishing    │                 │
  │ -a-dev-      │                 │
  │ branch       │                 │
  └──────┬───────┘                 │
         │                         │
         ▼                         │
  ┌──────────────┐                 │
  │ using-git    │◄────────────────┘
  │ -worktrees   │  (被多个 Skill 前置调用)
  └──────────────┘

  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
  │ dispatching  │  │ requesting   │  │ receiving        │
  │ -parallel    │  │ -code-review │  │ -code-review     │
  │ -agents      │  │              │  │                  │
  │ (独立使用)    │  │ (被 subagent │  │ (收到 review     │
  │              │  │  调用)       │  │  时使用)          │
  └──────────────┘  └──────────────┘  └──────────────────┘

  ┌──────────────────┐
  │ verification     │
  │ -before          │
  │ -completion      │
  │ (贯穿全流程       │
  │  声明前必验证)    │
  └──────────────────┘
```

---

## 十二、工具使用汇总

| Skill | 使用的工具 |
|-------|-----------|
| **using-superpowers** | Skill (调用其他 Skill) |
| **brainstorming** | Read, Glob, Grep, Bash(git log), AskUserQuestion, Write(spec), Bash(git commit), Bash(start-server.sh) |
| **writing-plans** | Read(spec + codebase), Write(plan), Bash(git commit), AskUserQuestion |
| **subagent-driven-development** | Task(implementer), Task(spec-reviewer), Task(code-reviewer), TaskUpdate, Bash(git diff), Read |
| **executing-plans** | Read(plan), TaskCreate, TaskUpdate, Write, Edit, Bash(tests) |
| **test-driven-development** | Write(test), Edit(code), Bash(run tests) |
| **systematic-debugging** | Read(errors), Bash(reproduce, git diff), Grep, Edit(diagnostic), Write(test), Bash(find-polluter.sh) |
| **using-git-worktrees** | Bash(git worktree add, git check-ignore, npm install, tests) |
| **requesting-code-review** | Bash(git rev-parse, git diff), Task(code-reviewer) |
| **receiving-code-review** | Grep, Read, Edit, Bash(tests) |
| **verification-before-completion** | Bash(tests, lint, build) |
| **finishing-a-development-branch** | Bash(tests, git merge/push/branch, gh pr create, git worktree remove), AskUserQuestion |
| **dispatching-parallel-agents** | Task × N (并行), Read(结果), Bash(集成测试) |
| **writing-skills** | Task(baseline test), Write(SKILL.md), Bash(render-graphs.js), Bash(wc -w) |

---

## 十三、Subagent 类型与 Prompt 模板

```
┌─────────────────────────────────────────────────────────────┐
│                   Subagent 调用体系                          │
├──────────────┬────────────────────────┬────────────────────┤
│ Subagent 角色 │ Prompt 模板            │ 调用者              │
├──────────────┼────────────────────────┼────────────────────┤
│ Implementer  │ implementer-prompt.md  │ subagent-driven    │
│              │ 内部使用 TDD            │ -development       │
│              │ 返回: DONE / BLOCKED   │                    │
│              │   / NEEDS_CONTEXT      │                    │
├──────────────┼────────────────────────┼────────────────────┤
│ Spec         │ spec-reviewer-prompt   │ subagent-driven    │
│ Reviewer     │  .md                   │ -development       │
│              │ 返回: ✅ / ❌ Issues    │                    │
├──────────────┼────────────────────────┼────────────────────┤
│ Code Quality │ code-quality-reviewer  │ subagent-driven    │
│ Reviewer     │  -prompt.md            │ -development       │
│              │ 使用 code-reviewer.md  │ → requesting       │
│              │ 返回: Strengths/Issues │   -code-review     │
├──────────────┼────────────────────────┼────────────────────┤
│ Plan         │ plan-document-reviewer │ writing-plans      │
│ Reviewer     │  -prompt.md            │ (可选)             │
│              │ 返回: Approved/Issues  │                    │
├──────────────┼────────────────────────┼────────────────────┤
│ Spec Doc     │ spec-document-reviewer │ brainstorming      │
│ Reviewer     │  -prompt.md            │ (可选)             │
│              │ 返回: Approved/Issues  │                    │
├──────────────┼────────────────────────┼────────────────────┤
│ Parallel     │ (无固定模板，           │ dispatching        │
│ Investigator │  内联构建 prompt)       │ -parallel-agents   │
└──────────────┴────────────────────────┴────────────────────┘
```
