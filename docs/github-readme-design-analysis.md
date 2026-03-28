# GitHub README 设计分析报告

> 分析对象：code-yeongyu/oh-my-openagent
> 分析日期：2026-03-17
> 目标：理解如何制作精美优雅的 GitHub README

---

## 目录

1. [README 视觉速览](#readme-视觉速览)
2. [七大核心设计元素](#七大核心设计元素)
3. [具体代码实现](#具体代码实现)
4. [需要上传的内容](#需要上传的内容)
5. [工具和资源推荐](#工具和资源推荐)
6. [设计原则总结](#设计原则总结)

---

## README 视觉速览

### 🎨 完整结构图

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │         🖼️ HERO BANNER（大图展示）          │        │
│  │  [Sisyphus Labs Logo - 产品形象]            │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  💬 品牌宣言引用框                         │        │
│  │  > We're building a fully productized...      │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  📊 社交媒体链接表格                         │        │
│  │  │ Discord │ X │ GitHub │                │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  🖼️ 产品预览大图（Hero Image）           │        │
│  │  [Oh My OpenCode 产品截图]                 │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  🎯 差异化定位（对比框）                     │        │
│  │  > Anthropic blocked OpenCode because...      │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  ⭐ 用户评价合集（引用框群）                 │        │
│  │  > "It made me cancel my Cursor..."         │        │
│  │  > "Sisyphus does it in 1 hour..."       │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  🚀 快速安装指引                           │        │
│  │  For Humans / For LLM Agents               │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  ⏭️ 跳过文档提示                             │        │
│  │  Skip This README                         │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  ✨ 功能亮点（表格 + Emoji）                │        │
│  │  | 🤖 Feature | What it does |           │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │  📚 详细文档链接                           │        │
│  │  See full Features Documentation           │        │
│  └─────────────────────────────────────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 七大核心设计元素

### 元素 1：🖼️ Hero Banner（大图展示）

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│          [大尺寸、高质量的 Logo 或产品图]                     │
│                                                             │
│              1200px 宽度 x 600px 高度                      │
│                                                             │
│    Sisyphus Labs - Sisyphus is agent that codes...      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
![Image 1: Sisyphus Labs - Sisyphus is agent that codes like your team.](https://github.com/code-yeongyu/oh-my-openagent/raw/dev/.github/assets/sisyphuslabs.png?v=2)
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **尺寸** | 1200x600px 或类似比例 |
| **格式** | PNG（支持透明）或 JPG |
| **内容** | 项目 Logo、品牌图或产品截图 |
| **文件位置** | `.github/assets/` 目录 |
| **命名规范** | 使用前缀如 `hero-`, `logo-` |
| **版本控制** | URL 可加 `?v=2` 缓存控制 |

### 元素 2：💬 品牌宣言（引用框）

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  > __We're building a fully productized version of...__   │
│  > __Join waitlist here.__                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
> __We're building a fully productized version of Sisyphus to define future of frontier agents.__   \
> Join waitlist here.__
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **语法** | `>` 开头，表示引用块 |
| **强调** | `__text__` 双下划线表示粗体 |
| **换行** | 行尾用 `\` 继续引用 |
| **用途** | 核心价值主张、品牌宣言 |
| **位置** | Hero Banner 下方 |

### 元素 3：📊 社交媒体表格

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Tip                                                        │
│                                                             │
│  | Image 2: Discord link | Join our Discord community... |   │
│  | --- | --- |                                              │
│  | Image 3: X link | News and updates... |               │
│  | Image 4: GitHub Follow | Follow @code-yeongyu... |  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
Tip

| Image 2: Discord link | Join our Discord community to connect with contributors and fellow `oh-my-opencode` users. |
| --- | --- |
| Image 3: X link | News and updates for `oh-my-opencode` used to be posted on my X account.   Since it was suspended mistakenly, @justsisyphus now posts updates on my behalf. |
| Image 4: GitHub Follow | Follow @code-yeongyu on GitHub for more projects. |
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **表格语法** | `|` 分隔列，`---` 分隔表头 |
| **图片嵌入** | 可以用图片链接作为单元格内容 |
| **图标** | 使用 Emoji 或 SVG 图标 |
| **布局** | 2 列或 3 列网格布局 |
| **用途** | 社交链接、联系方式、快速导航 |

### 元素 4：🎯 差异化定位（多行引用）

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  > Anthropic __blocked OpenCode because of us.__              │
│  > __Yes this is true.__                                 │
│  >                                                         │
│  > They want you locked in. Claude Code's a nice prison,   │
│  > but it's still a prison.                                │
│  >                                                         │
│  > We don't do lock-in here. We ride every model...         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
> Anthropic __blocked OpenCode because of us.__ __Yes this is true.__
>
> They want you locked in. Claude Code's a nice prison, but it's still a prison.
>
> We don't do lock-in here. We ride every model. Claude / Kimi / GLM for orchestration. GPT for reasoning. Minimax for speed. Gemini for creativity.
> The future isn't picking one winner—it's orchestrating them all. Models get cheaper every month. Smarter every month. No single provider will dominate. We're building for that open market, not their walled gardens.
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **多行引用** | 空行继续引用块 |
| **粗体强调** | `__text__` 关键词加粗 |
| **对比手法** | 明确竞争对手，突出差异 |
| **语言风格** | 直白、有力、略带反叛感 |
| **段落分隔** | 空行分割不同论点 |

### 元素 5：⭐ 用户评价（引用框合集）

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ## Reviews                                               │
│                                                             │
│  > "It made me cancel my Cursor subscription..."            │
│  > - Arthur Guiot                                         │
│                                                             │
│  > "If Claude Code does in 7 days what a human..."        │
│  > - B, Quant Researcher                                   │
│                                                             │
│  > "Knocked out 8000 eslint warnings..."                 │
│  > - Jacob Ferrari                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
## Reviews

> "It made me cancel my Cursor subscription. Unbelievable things are happening in open source community." - Arthur Guiot

> "If Claude Code does in 7 days what a human does in 3 months, Sisyphus does it in 1 hour. It just works until task is done. It is a discipline agent."   \
> - B, Quant Researcher

> "Knocked out 8000 eslint warnings with Oh My Opencode, just in a day"   \
> - Jacob Ferrari
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **引用形式** | `> "引用" - 作者名` |
| **引用符号** | 使用 `>` 表示引用 |
| **作者标注** | `-` 或 `—` 后接作者名 |
| **真实性** | 实际用户评价，包含署名 |
| **数量** | 5-10 条为宜，选择最佳评价 |
| **多样性** | 不同背景、不同使用场景的评价 |

### 元素 6：✨ 功能亮点（表格 + Emoji）

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  |  | Feature | What it does |                             │
│  | --- | --- | --- |                                      │
│  | 🤖 | __Discipline Agents__ | Sisyphus orchestrates...  │
│  | ⚡ | __`ultrawork` / `ulw`__ | One word...        │
│  | 🚪 | __IntentGate__ | Analyzes true user intent...  │
│  | 🔗 | __Hash-Anchored Edit Tool__ | `LINE#ID`...    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
|  | Feature | What it does |
| --- | --- | --- |
| 🤖 | __Discipline Agents__ | Sisyphus orchestrates Hephaestus, Oracle, Librarian, Explore. A full AI dev team in parallel. |
| ⚡ | __`ultrawork` / `ulw`__ | One word. Every agent activates. Doesn't stop until done. |
| 🚪 | __IntentGate__ | Analyzes true user intent before classifying or acting. No more literal misinterpretations. |
| 🔗 | __Hash-Anchored Edit Tool__ | `LINE#ID` content hash validates every change. Zero stale-line errors. Inspired by oh-my-pi. The Harness Problem → |
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **空列** | 首列留空给 Emoji |
| **Emoji 图标** | 每行一个独特图标 |
| **粗体标题** | `__标题__` 突出功能名 |
| **简洁描述** | 一两句话说明功能 |
| **顺序** | 按重要性或使用频率排序 |

### 元素 7：🔧 代码块和分隔线

#### 效果展示

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ---                                                        │
│                                                             │
│  ```bash                                                     │
│  Install and configure oh-my-opencode by following:          │
│  https://raw.githubusercontent.com/.../installation.md  │
│  ```                                                        │
│                                                             │
│  ---                                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 实现代码

```markdown
---

```bash
Install and configure oh-my-opencode by following instructions here:
https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md
```

---
```

#### 设计要点

| 要点 | 说明 |
|------|------|
| **分隔线** | `---` 水平分割线 |
| **代码块** | 三重反引号 `````language``` |
| **语言标记** | `bash`, `python`, `javascript` 等 |
| **语法高亮** | GitHub 自动根据语言高亮 |
| **用途** | 分隔不同章节、展示代码 |

---

## 具体代码实现

### 完整的 README 模板

```markdown
# [项目名称]

![Hero Banner](https://github.com/username/repo/raw/main/.github/assets/hero.png)

> __[核心价值主张]__   \
> [副标题或行动号召]

Tip

| [图标] Discord | [Discord 描述] |
| --- | --- |
| [图标] X | [X 账号描述] |
| [图标] GitHub | [GitHub 链接] |

![Product Preview](https://github.com/username/repo/raw/main/.github/assets/preview.png)

> [差异化定位或品牌故事]   \
> > [继续阐述...]
> > [更多内容...]

---

## Installation

### For Humans

```bash
# 简洁的安装命令
npm install your-package
```

### For LLM Agents

```bash
# AI 集成安装方式
curl -s https://raw.githubusercontent.com/username/repo/main/install.sh | bash
```

---

## Highlights

### 🚀 Feature One

[功能描述]

|  | Feature | What it does |
| --- | --- | --- |
| 🎯 | __Core Feature__ | Description here |
| ⚡ | __Fast Mode__ | Speed improvement |

---

## Reviews

> "User quote here" - User Name

> "Another quote" - Another User

> "Third quote" - Third User

---

## Author's Note

[作者声明或哲学说明]

---

## Links

- [Full Documentation](./docs/README.md)
- [Installation Guide](./docs/installation.md)
- [Contributing](./CONTRIBUTING.md)

---

[Loved by professionals at]

- Company 1
- Company 2
```

### Emoji 使用指南

| 类别 | 常用 Emoji | 用途 |
|------|------------|------|
| **功能** | ⚡ 🚀 🎯 🔗 | 核心功能图标 |
| **状态** | ✅ ⏳ 🚧 | 状态指示 |
| **操作** | 🔧 🛠️ 🔨 | 工具和操作 |
| **文档** | 📚 📖 📋 | 文档相关 |
| **导航** | 🔙 ⬆️ ⬇️ | 方向指示 |
| **警告** | ⚠️ 🚨 ❗ | 警告提示 |
| **庆祝** | 🎉 🌟 ⭐ | 成就亮点 |
| **科技** | 🤖 🧠 💻 | AI/技术 |

---

## 需要上传的内容

### 📁 目录结构

```
your-repository/
├── README.md                    # 主 README 文件
├── .github/                    # GitHub 专用目录
│   └── assets/               # 静态资源目录
│       ├── hero.png           # Hero Banner（1200x600）
│       ├── logo.png           # Logo 图标
│       ├── preview.png        # 产品预览图
│       ├── screenshot-1.png   # 功能截图
│       ├── screenshot-2.png
│       ├── feature-icon.svg   # 功能图标（可选）
│       └── ...
├── docs/                       # 文档目录
│   ├── installation.md       # 安装指南
│   ├── features.md          # 功能详解
│   └── api.md              # API 文档
└── src/                        # 源代码
```

### 🖼️ 图片资源清单

| 文件名 | 尺寸建议 | 用途 | 格式 |
|--------|----------|------|------|
| `hero.png` | 1200x600px | 主展示图 | PNG |
| `logo.png` | 512x512px | Logo 图标 | PNG（透明） |
| `preview.png` | 1200x800px | 产品预览 | PNG |
| `screenshot-1.png` | 1200x800px | 功能截图 | PNG |
| `banner.png` | 1200x200px | 次级横幅 | PNG |
| `icon.png` | 128x128px | 小图标 | PNG |

### 📝 文档内容清单

| 文件 | 内容 | 状态 |
|------|------|------|
| `README.md` | 项目主页 | 必需 |
| `LICENSE` | 开源协议 | 必需 |
| `CONTRIBUTING.md` | 贡献指南 | 推荐 |
| `CHANGELOG.md` | 更新日志 | 推荐 |
| `CODE_OF_CONDUCT.md` | 行为准则 | 可选 |
| `docs/installation.md` | 安装文档 | 推荐 |
| `docs/features.md` | 功能说明 | 推荐 |
| `docs/api.md` | API 文档 | 可选 |

---

## 工具和资源推荐

### 🛠️ Hero Banner 生成工具

| 工具 | 链接 | 特点 |
|------|------|------|
| **Canva** | [canva.com](https://www.canva.com) | 在线设计，大量模板 |
| **Figma** | [figma.com](https://www.figma.com) | 专业设计工具 |
| **REHeader** | [GitHub](https://github.com/khalby786/REHeader) | GitHub Profile 专用 |
| **Git Profile README Banner** | [GitHub](https://github.com/lewispour/Git-Profile-Readme-Banner) | 用户名横幅 |

### 🏷️ Badge（徽章）生成工具

| 工具 | 链接 | 用途 |
|------|------|------|
| **Shields.io** | [shields.io](https://shields.io) | 最流行的徽章生成器 |
| **Badgen** | [badgen.net](https://badgen.net) | 快速生成 GitHub 徽章 |
| **Readme-Codegen** | [readmecodegen.com](https://www.readmecodegen.com) | 综合生成器 |
| **ForTheBadge** | [forthebadge.com](https://forthebadge.com) | 趣味徽章 |

### 常用 Badge 示例

```markdown
<!-- 状态徽章 -->
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Status](https://img.shields.io/badge/build-passing-green.svg)
![Version](https://img.shields.io/badge/version-1.0.0-orange.svg)

<!-- GitHub 统计徽章 -->
![Stars](https://img.shields.io/github/stars/username/repo.svg?style=social)
![Forks](https://img.shields.io/github/forks/username/repo.svg?style=social)
![Issues](https://img.shields.io/github/issues/username/repo.svg)

<!-- 技术栈徽章 -->
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![React](https://img.shields.io/badge/react-18+-61DAFB.svg)
![TypeScript](https://img.shields.io/badge/Typescript-5.0+-3178C6.svg)
```

### 📚 README 灵感来源

| 资源 | 链接 | 说明 |
|------|------|------|
| **Awesome README** | [GitHub](https://github.com/matiassingers/awesome-readme) | 精选 README 集合 |
| **beautiful-profile-readme** | [GitHub Topic](https://github.com/topics/beautiful-profile-readme) | 精美 Profile README |
| **best-github-profile-readme** | [GitHub](https://github.com/maxontechn/best-github-profile-readme) | 按主题分类 |
| **Best-README-Template** | [GitHub](https://github.com/othneildrew/Best-README-Template) | 通用模板 |

---

## 设计原则总结

### 🎯 七大黄金法则

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  1. 🖼️ 视觉优先                                   │
│     • 首图是门面，决定第一印象                        │
│     • 1200x600px 是最佳尺寸                          │
│     • 高质量、专业设计                                   │
│                                                             │
│  2. 💬 价值清晰                                   │
│     • 一句话说清项目是什么                             │
│     • 用引用框突出核心价值                             │
│     • 差异化定位，突出优势                               │
│                                                             │
│  3. 📊 结构有序                                   │
│     • 分隔线 `---` 分割章节                            │
│     • 表格组织复杂信息                                   │
│     • 层级标题 ## ### 清晰导航                          │
│                                                             │
│  4. ✨ 视觉丰富                                   │
│     • Emoji 作为图标点缀                                   │
│     • 图片展示产品功能                                   │
│     • 代码块展示安装和用法                               │
│                                                             │
│  5. ⭐ 社交证明                                   │
│     • 用户评价增加可信度                                   │
│     • 社交链接方便连接                                   │
│     • Company Logo 显示背书                               │
│                                                             │
│  6. 🚀 行动引导                                   │
│     • 清晰的安装步骤                                     │
│     • 代码块方便复制                                     │
│     • 链接到详细文档                                     │
│                                                             │
│  7. 💡 品牌个性                                   │
│     • 俏皮的语言风格                                     │
│     • 统一的视觉元素                                     │
│     • 清晰的价值观表达                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 📋 检查清单

发布前请确认：

- [ ] **Hero Banner** 已上传并正确引用
- [ ] **Logo 图标** 清晰且符合品牌
- [ ] **项目描述** 一句话能说清
- [ ] **安装说明** 简单易用
- [ ] **用户评价** 至少 3 条
- [ ] **功能列表** 表格展示
- [ ] **文档链接** 全部有效
- [ ] **社交链接** Discord/X/GitHub
- [ ] **分隔线** 正确使用 `---`
- [ ] **代码块** 语法正确
- [ ] **Emoji** 使用恰当
- [ ] **图片尺寸** 优化加载
- [ ] **移动端** 阅读测试
- [ ] **拼写检查** 已完成
- [ ] **链接测试** 全部有效

---

## 快速上手模板

### 最小可运行版本

```markdown
# [项目名]

![Hero](https://github.com/username/repo/raw/main/.github/assets/hero.png)

> __[核心价值]__

---

## Quick Start

```bash
npm install your-package
your-package start
```

---

## Features

| 🎯 Feature | Description |
| --- | --- |
| ⚡ Fast | Blazing fast performance |
| 🔧 Easy | Simple to use |
| 🛡️ Secure | Enterprise-grade security |

---

## Reviews

> "Best tool ever!" - Happy User

---

## Links

- [Documentation](./docs/)
- [GitHub](https://github.com/username/repo)
```

---

## Sources

本文档参考了以下资源：

- [code-yeongyu/oh-my-openagent GitHub Repository](https://github.com/code-yeongyu/oh-my-openagent)
- [Shields.io Documentation](https://github.com/badges/shields/blob/master/README.md)
- [How to Design an Attractive GitHub Profile Readme](https://medium.com/design-bootcamp/how-to-design-an-attractive-github-profile-readme-3618d6c53783)
- [awesome-readme](https://github.com/matiassingers/awesome-readme)
- [Best-README-Template](https://github.com/othneildrew/Best-README-Template)
- [GitHub Topics: beautiful-profile-readme](https://github.com/topics/beautiful-profile-readme)
- [README Design Kit](https://medium.com/@mayur.s.pagote/transform-your-github-readme-into-a-masterpiece-with-readme-design-kit-ce294907a73b)
- [GitHub Emoji API](https://api.github.com/emojis)
- [Front-End Design Checklist](https://github.com/thedaviddias/Front-End-Design-Checklist)
