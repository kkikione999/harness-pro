# GitHub README 快速参考卡

> 一页纸搞定 README 设计

---

## 🎯 README 的六大元素

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1️⃣ Hero Banner（大图）                                          │
│     尺寸：1200x600px                                             │
│     位置：顶部第一眼                                              │
│     内容：Logo 或产品图                                            │
│                                                                 │
│  2️⃣ 品牌宣言（引用框）                                             │
│     语法：> __粗体核心价值__                                       │
│     位置：Banner 下方                                             │
│     内容：一句话说清项目是什么                                    │
│                                                                 │
│  3️⃣ 产品预览图（中图）                                             │
│     尺寸：1200x800px                                             │
│     位置：宣言下方                                               │
│     内容：界面截图或功能演示                                       │
│                                                                 │
│  4️⃣ 功能亮点（表格+Emoji）                                         │
│     语法：| 🎯 Feature | Description |                          │
│     位置：预览图下方                                             │
│     内容：5-10 个核心功能                                          │
│                                                                 │
│  5️⃣ 用户评价（引用框群）                                             │
│     语法：> "引用" - 作者名                                          │
│     位置：功能下方                                               │
│     内容：5-10 条用户评价                                          │
│                                                                 │
│  6️⃣ 快速安装（代码块）                                               │
│     语法：```bash 命令 ```                                          │
│     位置：评价下方                                               │
│     内容：一行命令即可安装                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 复制粘贴模板

```markdown
# 项目名

![Hero Banner](https://github.com/username/repo/raw/main/.github/assets/hero.png)

> __一句话说清你的项目__   \
> [副标题或行动号召]

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
| ⚡ Fast | Lightning fast performance |
| 🔧 Easy | Simple to setup |
| 🛡️ Secure | Enterprise-grade security |

---

## Preview

![Product Preview](https://github.com/username/repo/raw/main/.github/assets/preview.png)

---

## Reviews

> "Best tool I've used!" - Happy User

> "Saved me hours of work!" - Another User

---

## Links

- [Documentation](./docs/)
- [GitHub](https://github.com/username/repo)
```

---

## 🖼️ 需要准备的内容

```
项目根目录/
├── README.md
├── .github/
│   └── assets/
│       ├── hero.png      ← 1200x600px
│       ├── preview.png   ← 1200x800px
│       └── logo.png      ← 512x512px（可选）
├── docs/
│   ├── installation.md
│   └── features.md
└── LICENSE
```

---

## 🎨 Emoji 快查表

| 用途 | Emoji |
|------|-------|
| 功能图标 | ⚡ 🎯 🔗 🛠️ 🧠 |
| 状态指示 | ✅ ⏳ 🚧 ❗ |
| 文档相关 | 📚 📖 📋 📝 |
| 导航指示 | ↗️ ↘️ ↖️ ↙️ |
| 警告提示 | ⚠️ 🚨 ❌ |

---

## 🛠️ 在线工具

| 用途 | 链接 |
|------|------|
| Badge 生成 | [shields.io](https://shields.io) |
| Hero Banner 设计 | [canva.com](https://www.canva.com) |
| GitHub Icons | [octicons.github.com](https://octicons.github.com) |
| Emoji 查询 | [api.github.com/emojis](https://api.github.com/emojis) |

---

## ✅ 发布前检查

- [ ] Hero Banner 已上传
- [ ] 产品预览图已上传
- [ ] 所有图片链接有效
- [ ] 代码块语法正确
- [ ] 表格格式正确
- [ ] 分隔线 `---` 使用正确
- [ ] 链接全部有效
- [ ] 拼写检查完成
- [ ] 移动端预览正常
