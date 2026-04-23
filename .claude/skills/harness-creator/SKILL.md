---
name: harness-creator
description: Analyze a codebase and generate harness infrastructure (AGENTS.md, docs/, scripts/, harness/ directories, layer rules). Use when user wants to set up, bootstrap, or initialize harness infrastructure for their project. Also use when auditing an existing project or improving harness coverage. Multi-language: TypeScript, Go, Python, Swift.
---

# Harness Creator

你是 harness 基础设施的生成器，由脚本门控管线驱动。你**不自调度** — 管线脚本告诉你下一步做什么。

## 管线循环

收到创建/审计/改善请求后:

```
1. 初始化:
   bash {skill-dir}/scripts/creator-pipeline init

2. 循环:
   a. bash {skill-dir}/scripts/creator-pipeline check   → 读当前状态
   b. 下一步 = current_step + 1 (如果为 0 则从 1 开始)
   c. bash {skill-dir}/scripts/creator-pipeline gate {下一步}  → 检查前置条件
      - 退出码 0 → 读 steps/{下一步}.md, 执行
      - 退出码 1 → BLOCKED, 报告用户, 停止
   d. 执行步骤内容 (步骤文件会告诉你读哪些 reference)
   e. bash {skill-dir}/scripts/creator-pipeline advance {下一步} [key=value]...
   f. Step 5 完成 → 结束

3. 结束: 输出最终报告
```

`{skill-dir}` = 本 SKILL.md 所在目录。

## 步骤索引

| 文件 | 做什么 | 必须读取的 reference |
|------|--------|---------------------|
| `steps/01-detect.md` | 检测模式 + 语言 | 无 |
| `steps/02-audit.md` | 评分 + 层级映射 | `references/audit.md`, `references/layer-rules.md` |
| `steps/03-generate.md` | 生成所有文件 | `references/generator.md`, `references/layer-rules.md`, `references/e2e-strategies.md`, 语言模板 |
| `steps/04-verify.md` | 验证 + 修复循环 | 无 |
| `steps/05-report.md` | 输出报告 | 无 |

## 核心原则 (生成 AGENTS.md 时必须包含)

1. **仓库是唯一事实来源** — 规则在 Git 里，不在聊天记录里
2. **协调者不写代码** — 超过 1 个文件的改动，委派给 sub-agent
3. **验证先于执行** — 跨模块改动前先跑 lint-deps
4. **上下文很贵** — sub-agent prompt 要聚焦，不要塞大上下文
