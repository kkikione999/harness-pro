# Harness Pro Plugin

> A Claude Code plugin for orchestrating long, multi-step development tasks with multi-agent collaboration, iOS simulator automation, and multi-language LSP support.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Long-Task Executor](#long-task-executor)
  - [Harness-Pro Doctor](#harness-pro-doctor)
  - [iOS Simulator Automation](#ios-simulator-automation)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [License](#license)

---

## Overview

**Harness Pro Plugin** is a Claude Code plugin designed for complex software engineering workflows. It coordinates multiple specialized sub-agents through a structured 8-step pipeline, turning vague feature requests into production-ready code — with user approval at every critical gate.

Key workflows:

- **Plan → Implement → Review → E2E Verify → Commit** — fully automated long-task execution
- **iOS Simulator Automation** — control iOS simulators via WebDriverAgent for UI testing
- **Multi-Language LSP Support** — intelligent code navigation for TypeScript, Swift, Go, and Python
- **Pre-Push Safety Hook** — automatic `/simplify` review before `git push`

---

## Features

| Feature | Description |
|---------|-------------|
| **Long-Task Executor** | 8-step orchestration pipeline for non-trivial development tasks |
| **5 Sub-Agents** | `plan-agent`, `worker`, `reviewer`, `e2e-runner`, `doc-updater` |
| **Parallel Execution** | Independent phases dispatched concurrently; dependent phases run sequentially |
| **Uncapped Review Loop** | Reviewer audits code; fix-worker addresses issues; loops until PASS |
| **E2E Verification** | Runs test suite + performs user-perspective end-to-end verification |
| **Conditional Commit** | Auto-commits only when tree is clean, tests pass, and no secrets detected |
| **utell-ios MCP** | iOS simulator control: tap, swipe, type, screenshot, list elements |
| **LSP Servers** | TypeScript, Swift (SourceKit), Go (gopls), Python (Pyright) |
| **Health Check** | One-command diagnostic for all plugin components |
| **Pre-Push Hook** | Automatically runs `/simplify` before `git push` |

---

## Installation

### One-Line Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/josh-folder/harness-pro-plugin/main/install.sh | bash
```

The script will:
1. Check prerequisites (git, python3, Claude Code)
2. Clone the plugin repository to `~/.claude/plugins/marketplaces/harness-pro-marketplace/`
3. Register the marketplace in Claude Code's plugin registry
4. Install and enable the plugin
5. Run a health check

After installation, **restart Claude Code** or run `/reload` to activate.

> **Security note**: If you prefer to review the script before running it, see [install.sh](install.sh) or use the Manual Install option below.

### Manual Install

```bash
git clone https://github.com/josh-folder/harness-pro-plugin.git
cd harness-pro-plugin
./install.sh
```

### Install via Claude Code `mcp`

If the plugin is available in a registered marketplace:

1. Run `mcp` in Claude Code
2. Search for **"harness-pro-plugin"**
3. Click **Install**

### Prerequisites

| Runtime | Purpose | Install Command |
|---------|---------|-----------------|
| Node.js 18+ | LSP servers | `brew install node` |
| npm | Package manager | Bundled with Node.js |
| Go 1.21+ | gopls LSP | `brew install go` |
| Python 3.10+ | MCP server | `brew install python` |
| git | Clone repository | `brew install git` |
| uv (optional) | Python runner | `brew install uv` |

### LSP Servers (Optional)

For full LSP support, install the language servers you need:

```bash
# TypeScript / JavaScript
npm i -g typescript-language-server typescript

# Python
npm i -g pyright

# Go
go install golang.org/x/tools/gopls@latest

# Swift (macOS only — bundled with Xcode CLI tools)
xcode-select --install
```

### Post-Install Verification

```bash
/harness-pro-doctor
```

---

## Submit to Claude Plugin Marketplace (Official)

To make this plugin discoverable by all Claude Code users through the built-in `mcp` marketplace:

1. **Host your plugin code** in a public GitHub repository (e.g., `github.com/josh-folder/harness-pro-plugin`)
2. **Submit a PR** to [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official)
3. **Add an entry** to the marketplace JSON with a `url` or `git-subdir` source pointing to your repository

Example entry for `claude-plugins-official` marketplace:
```json
{
  "name": "harness-pro-plugin",
  "description": "Coordinator skill for long, multi-step development tasks...",
  "author": { "name": "josh-folder" },
  "category": "development",
  "source": {
    "source": "url",
    "url": "https://github.com/josh-folder/harness-pro-plugin.git"
  }
}
```

Once merged, all Claude Code users will be able to install it via `mcp` → Search → Install with one click.

---

## Usage

### Long-Task Executor

The core skill. Trigger it naturally by describing a non-trivial requirement:

```
Implement a user authentication system with JWT tokens and refresh token rotation
```

Or explicitly:

```
/long-task-executor
```

**The 8-Step Pipeline:**

```
1. Read Context      → Analyze CLAUDE.md and project structure
2. Restate           → Summarize the requirement in plain language
3. Approval Gate     → Wait for your explicit "yes / go / approved"
4. Spawn Plan-Agent  → Generate a phased execution plan
5. Dispatch Workers  → Implement phases (parallel when independent)
6. Review Loop       → Reviewer audits → fix-worker addresses → loop until PASS
7. E2E Verify        → Run tests + user-perspective verification
8. Conditional Commit→ Commit only if all safety gates pass
```

**Key Design Principles:**

- **You are always in control** — no code is written until you approve the restated requirement
- **No artificial iteration caps** — the review loop continues until the reviewer approves
- **Safety-first commits** — dirty trees, failing tests, or detected secrets block auto-commit

### Harness-Pro Doctor

Diagnose your plugin installation:

```
/harness-pro-doctor
```

Checks: runtimes, LSP servers, MCP server (utell-ios), plugin data directory, hooks validity.

### iOS Simulator Automation

Control iOS simulators via natural language:

```
Launch the iOS simulator with my app, tap the login button, enter "test@example.com",
screenshot the home screen, and swipe up to dismiss the keyboard.
```

Available actions: `launch_app`, `tap`, `double_tap`, `long_press`, `swipe`, `type_keys`,
`screenshot`, `list_elements`, `press_button` (Home, Back, Volume), `set_orientation`.

**Configuration** (optional — auto-detected from Xcode project):

| Config Key | Default | Description |
|------------|---------|-------------|
| `UTELL_BUNDLE_ID` | auto-detected | iOS app bundle identifier |
| `UTELL_WDA_HOST` | `127.0.0.1` | WebDriverAgent host |
| `UTELL_WDA_PORT` | `8100` | WebDriverAgent port |
| `UTELL_WDA_PATH` | auto-searched | Path to WebDriverAgent.xcodeproj |

---

## Configuration

Plugin configuration is managed through Claude Code's plugin system. The following settings are available:

### User Config (in `plugin.json`)

All iOS simulator settings are optional — the plugin attempts auto-configuration from your Xcode project.

```json
{
  "UTELL_BUNDLE_ID": "com.example.myapp",
  "UTELL_WDA_HOST": "127.0.0.1",
  "UTELL_WDA_PORT": "8100",
  "UTELL_WDA_PATH": "/path/to/WebDriverAgent"
}
```

### Hooks

The plugin registers a `PreToolUse` hook that runs `/simplify` review before any `git push` command.

Disable by editing `hooks/hooks.json` if desired.

---

## Architecture

```
harness-pro-plugin/
├── agents/                    # Sub-agent definitions
│   ├── plan-agent.md          # Generates phased execution plans
│   ├── worker.md              # Implements one plan phase
│   ├── reviewer.md            # Audits code for correctness & style
│   ├── e2e-runner.md          # Runs tests + user-perspective E2E
│   └── doc-updater.md         # Updates documentation
│
├── skills/
│   ├── long-task-executor/    # Main orchestration skill
│   │   ├── SKILL.md
│   │   ├── steps/             # 8-step workflow definitions
│   │   └── references/        # Decision rules & gating logic
│   └── harness-pro-doctor/    # Health-check diagnostic skill
│
├── mcp/
│   └── utell-ios/             # iOS simulator MCP server
│       ├── server.py
│       ├── bridge_client.py
│       ├── swift_parser.py
│       ├── thunk_generator.py
│       └── run.sh
│
├── hooks/
│   ├── hooks.json             # Hook registrations
│   └── pre-push-simplify.sh   # Pre-push safety check
│
├── scripts/
│   └── install-lsp-deps.sh    # LSP dependency installer
│
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest
│   └── marketplace.json       # Marketplace listing
│
└── README.md
```

### Sub-Agent Collaboration Model

```
User Requirement
       │
       ▼
  Coordinator (Long-Task Executor)
       │
       ├──► plan-agent ──► Plan File
       │                        │
       ├──► worker(s) ───► Code Changes
       │                        │
       ├──► reviewer ────► PASS / FAIL
       │        ▲               │
       │        └── fix-worker ◄┘ (loop until PASS)
       │
       ├──► e2e-runner ──► Test Results + E2E Report
       │
       └──► Conditional Commit (gated)
```

The coordinator is the sole decision-maker. Sub-agents never invoke each other directly.

---

## Requirements

| Component | Minimum Version |
|-----------|----------------|
| Claude Code | Latest stable |
| Node.js | 18.x |
| npm | 9.x |
| Python | 3.10+ |
| Go | 1.21+ (for gopls) |
| macOS | 12+ (for SourceKit / iOS simulator) |
| Xcode | 14+ (for iOS simulator / WebDriverAgent) |

---

## License

MIT License — see [plugin.json](.claude-plugin/plugin.json) for details.

---

---

---

---

# Harness Pro 插件

> 一款用于编排多步骤复杂开发任务的 Claude Code 插件，支持多智能体协作、iOS 模拟器自动化和多语言 LSP 支持。

---

## 目录

- [概述](#概述)
- [功能特性](#功能特性)
- [安装](#安装)
- [使用](#使用)
  - [长任务执行器](#长任务执行器)
  - [Harness-Pro 诊断工具](#harness-pro-诊断工具)
  - [iOS 模拟器自动化](#ios-模拟器自动化)
- [配置说明](#配置说明)
- [架构](#架构)
- [环境要求](#环境要求)
- [许可证](#许可证)

---

## 概述

**Harness Pro 插件** 是一款专为复杂软件工程工作流设计的 Claude Code 插件。它通过一个结构化的 8 步流水线协调多个专业子智能体，将模糊的功能需求转化为生产级代码 —— 在每个关键节点都要求用户确认。

核心工作流：

- **规划 → 实现 → 审查 → E2E 验证 → 提交** —— 全自动长任务执行
- **iOS 模拟器自动化** —— 通过 WebDriverAgent 控制 iOS 模拟器进行 UI 测试
- **多语言 LSP 支持** —— 智能代码导航，支持 TypeScript、Swift、Go 和 Python
- **推送前安全钩子** —— `git push` 前自动运行 `/simplify` 审查

---

## 功能特性

| 功能 | 说明 |
|---------|-------------|
| **长任务执行器** | 针对非平凡开发任务的 8 步编排流水线 |
| **5 个子智能体** | `plan-agent`（规划）、`worker`（实现）、`reviewer`（审查）、`e2e-runner`（端到端测试）、`doc-updater`（文档更新） |
| **并行执行** | 独立阶段并行派发；依赖阶段按顺序执行 |
| **无限审查循环** | 审查员审计代码；修复工作者解决问题；循环直到通过 |
| **E2E 验证** | 运行测试套件 + 执行用户视角的端到端验证 |
| **条件提交** | 仅当工作区干净、测试通过、无敏感信息时才自动提交 |
| **utell-ios MCP** | iOS 模拟器控制：点击、滑动、输入、截图、列出元素 |
| **LSP 语言服务器** | TypeScript、Swift（SourceKit）、Go（gopls）、Python（Pyright） |
| **健康检查** | 一键诊断所有插件组件 |
| **推送前钩子** | `git push` 前自动运行 `/simplify` |

---

## 安装

### 一键安装（推荐）

```bash
curl -sSL https://raw.githubusercontent.com/josh-folder/harness-pro-plugin/main/install.sh | bash
```

脚本会自动完成：
1. 检查前置依赖（git、python3、Claude Code）
2. 克隆插件仓库到 `~/.claude/plugins/marketplaces/harness-pro-marketplace/`
3. 向 Claude Code 注册该应用市场
4. 安装并启用插件
5. 运行健康检查

安装完成后，**重启 Claude Code** 或运行 `/reload` 激活插件。

> **安全提示**：如果你希望在运行前审查脚本内容，可查看 [install.sh](install.sh) 或使用下面的手动安装方式。

### 手动安装

```bash
git clone https://github.com/josh-folder/harness-pro-plugin.git
cd harness-pro-plugin
./install.sh
```

### 通过 Claude Code `mcp` 安装

如果该插件已在某个已注册的应用市场中：

1. 在 Claude Code 中运行 `mcp`
2. 搜索 **"harness-pro-plugin"**
3. 点击 **安装**

### 前置条件

| 运行时 | 用途 | 安装命令 |
|---------|---------|-----------------|
| Node.js 18+ | LSP 语言服务器 | `brew install node` |
| npm | 包管理器 | Node.js 自带 |
| Go 1.21+ | gopls LSP | `brew install go` |
| Python 3.10+ | MCP 服务器 | `brew install python` |
| git | 克隆仓库 | `brew install git` |
| uv（可选） | Python 运行器 | `brew install uv` |

### 语言服务器（可选）

如需完整的 LSP 支持，安装你需要的语言服务器：

```bash
# TypeScript / JavaScript
npm i -g typescript-language-server typescript

# Python
npm i -g pyright

# Go
go install golang.org/x/tools/gopls@latest

# Swift（仅 macOS —— Xcode CLI 工具自带）
xcode-select --install
```

### 安装后验证

```bash
/harness-pro-doctor
```

---

## 提交到 Claude 官方插件市场

要让所有 Claude Code 用户都能通过内置的 `mcp` 应用市场发现并安装本插件：

1. **将插件代码托管**在公开 GitHub 仓库（如 `github.com/josh-folder/harness-pro-plugin`）
2. **向 [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) 提交 PR**
3. **在 marketplace JSON 中添加条目**，使用 `url` 或 `git-subdir` 类型的 source 指向你的仓库

官方市场条目示例：
```json
{
  "name": "harness-pro-plugin",
  "description": "Coordinator skill for long, multi-step development tasks...",
  "author": { "name": "josh-folder" },
  "category": "development",
  "source": {
    "source": "url",
    "url": "https://github.com/josh-folder/harness-pro-plugin.git"
  }
}
```

PR 合并后，所有 Claude Code 用户即可通过 `mcp` → 搜索 → 一键安装。

---

## 使用

### 长任务执行器

核心技能。自然地描述一个非平凡的需求即可触发：

```
实现一个带有 JWT Token 和刷新 Token 轮换机制的用户认证系统
```

或显式调用：

```
/long-task-executor
```

**8 步流水线：**

```
1. 读取上下文      → 分析 CLAUDE.md 和项目结构
2. 重述需求        → 用简洁语言总结需求
3. 确认关卡        → 等待你明确的 "是 / 开始 / 确认"
4. 生成计划        → 生成分阶段执行计划
5. 派发工作者      → 实现各阶段（独立时并行）
6. 审查循环        → 审查员审计 → 修复工作者处理 → 循环直到通过
7. E2E 验证        → 运行测试 + 用户视角验证
8. 条件提交        → 仅当所有安全检查通过时才提交
```

**核心设计原则：**

- **你始终掌控全局** —— 在你确认重述的需求之前，不会写任何代码
- **没有人为的迭代上限** —— 审查循环持续进行，直到审查员通过
- **安全优先的提交** —— 工作区未清理、测试失败或检测到敏感信息时，阻止自动提交

### Harness-Pro 诊断工具

诊断你的插件安装状态：

```
/harness-pro-doctor
```

检查项：运行时、LSP 语言服务器、MCP 服务器（utell-ios）、插件数据目录、钩子有效性。

### iOS 模拟器自动化

通过自然语言控制 iOS 模拟器：

```
启动 iOS 模拟器并打开我的 App，点击登录按钮，输入 "test@example.com"，
截取首页截图，然后上滑收起键盘。
```

可用操作：`launch_app`（启动应用）、`tap`（点击）、`double_tap`（双击）、`long_press`（长按）、`swipe`（滑动）、`type_keys`（输入文字）、`screenshot`（截图）、`list_elements`（列出元素）、`press_button`（Home/返回/音量键）、`set_orientation`（设置屏幕方向）。

**配置**（可选 —— 自动从 Xcode 项目检测）：

| 配置项 | 默认值 | 说明 |
|------------|---------|-------------|
| `UTELL_BUNDLE_ID` | 自动检测 | iOS 应用 Bundle ID |
| `UTELL_WDA_HOST` | `127.0.0.1` | WebDriverAgent 主机地址 |
| `UTELL_WDA_PORT` | `8100` | WebDriverAgent 端口 |
| `UTELL_WDA_PATH` | 自动搜索 | WebDriverAgent.xcodeproj 的路径 |

---

## 配置说明

插件配置通过 Claude Code 的插件系统管理。以下设置可用：

### 用户配置（位于 `plugin.json`）

所有 iOS 模拟器设置都是可选的 —— 插件会尝试从你的 Xcode 项目自动配置。

```json
{
  "UTELL_BUNDLE_ID": "com.example.myapp",
  "UTELL_WDA_HOST": "127.0.0.1",
  "UTELL_WDA_PORT": "8100",
  "UTELL_WDA_PATH": "/path/to/WebDriverAgent"
}
```

### 钩子

插件注册了一个 `PreToolUse` 钩子，在任何 `git push` 命令前运行 `/simplify` 审查。

如需禁用，请编辑 `hooks/hooks.json`。

---

## 架构

```
harness-pro-plugin/
├── agents/                    # 子智能体定义
│   ├── plan-agent.md          # 生成分阶段执行计划
│   ├── worker.md              # 实现单个计划阶段
│   ├── reviewer.md            # 审计代码正确性和风格
│   ├── e2e-runner.md          # 运行测试 + 用户视角 E2E
│   └── doc-updater.md         # 更新文档
│
├── skills/
│   ├── long-task-executor/    # 主编排技能
│   │   ├── SKILL.md
│   │   ├── steps/             # 8 步工作流定义
│   │   └── references/        # 决策规则与关卡逻辑
│   └── harness-pro-doctor/    # 健康检查诊断技能
│
├── mcp/
│   └── utell-ios/             # iOS 模拟器 MCP 服务器
│       ├── server.py
│       ├── bridge_client.py
│       ├── swift_parser.py
│       ├── thunk_generator.py
│       └── run.sh
│
├── hooks/
│   ├── hooks.json             # 钩子注册配置
│   └── pre-push-simplify.sh   # 推送前安全检查
│
├── scripts/
│   └── install-lsp-deps.sh    # LSP 依赖安装脚本
│
├── .claude-plugin/
│   ├── plugin.json            # 插件清单
│   └── marketplace.json       # 应用市场列表
│
└── README.md
```

### 子智能体协作模型

```
用户需求
    │
    ▼
  协调器（长任务执行器）
    │
    ├──► plan-agent ──► 计划文件
    │                        │
    ├──► worker(s) ───► 代码变更
    │                        │
    ├──► reviewer ────► 通过 / 失败
    │        ▲               │
    │        └── fix-worker ◄┘（循环直到通过）
    │
    ├──► e2e-runner ──► 测试结果 + E2E 报告
    │
    └──► 条件提交（带关卡检查）
```

协调器是唯一的决策者。子智能体之间从不直接互相调用。

---

## 环境要求

| 组件 | 最低版本 |
|-----------|----------------|
| Claude Code | 最新稳定版 |
| Node.js | 18.x |
| npm | 9.x |
| Python | 3.10+ |
| Go | 1.21+（用于 gopls） |
| macOS | 12+（用于 SourceKit / iOS 模拟器） |
| Xcode | 14+（用于 iOS 模拟器 / WebDriverAgent） |

---

## 许可证

MIT 许可证 —— 详见 [plugin.json](.claude-plugin/plugin.json)。
