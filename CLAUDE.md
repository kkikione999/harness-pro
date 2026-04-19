# CLAUDE.md

## 仓库使命

将 Qoder Harness Engineering 落地到本仓库，建立一套让 AI Agent 能稳定产出正确代码的运行环境。

参考文章：[Qoder 工程实践：Harness Engineering 指南](./Qoder工程实践-Harness-Engineering指南.md)

## 核心原则

### 1. 仓库是唯一的事实来源

所有架构决策、分层规则、编码规范必须以版本化文件形式存在于仓库中。不在仓库里的规则，Agent 看不见。

### 2. AGENTS.md 是地图，不是手册

控制在 100 行以内，只做索引和指路。详细内容分散到 `docs/` 目录按需加载。

### 3. 高层可以 import 低层，反过来不行

依赖方向必须严格遵循层级约束，层级违反是 Agent 翻车的头号原因。

### 4. 协调者不写代码

中等复杂度以上的任务，协调者只做规划、委派、汇总，不直接修改源代码。

### 5. 验证先于执行

涉及新位置创建文件或添加跨包 import 时，先问"这样做合法吗"，再动手。

## 项目结构

```
harness-simple/
├── CLAUDE.md              # 本文件
├── Qoder工程实践-Harness-Engineering指南.md  # 参考文章
├── AGENTS.md              # Agent 入口指南（待创建）
└── docs/                  # 详细文档（待创建）
    ├── ARCHITECTURE.md
    ├── DEVELOPMENT.md
    └── design-docs/
```

## 落地计划

- [ ] 创建 `AGENTS.md`（100 行以内的索引入口）
- [ ] 创建 `docs/ARCHITECTURE.md`（架构总览）
- [ ] 创建 `docs/DEVELOPMENT.md`（开发指南）
- [ ] 添加 `scripts/lint-deps`（依赖方向检查）
- [ ] 添加 `scripts/lint-quality`（质量规则检查）
- [ ] 添加 `scripts/validate.py`（统一验证入口）
- [ ] 创建 `harness/` 目录结构（tasks/ trace/ memory/）
- [ ] 建立 Critic → Refiner 反馈循环

## 参考文章核心要点

- **仓库即 OS**：Agent 需要操作系统般的环境感知能力
- **四层验证管道**：build → lint-arch → test → verify
- **三层记忆**：情景记忆、程序记忆、失败记忆
- **轨迹编译**：重复成功的任务模式可编译为确定性脚本
- **环境设计投入回报 > Prompt 调优**
