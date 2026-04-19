# MarkdownPreview

一个最小的 macOS Markdown 预览应用，只做一件事：打开并预览 `.md` / `.markdown` 文件。

## 功能

- 双击或通过 `Command + O` 打开 Markdown 文件
- 只读预览，不提供编辑能力
- 支持 `Preview / Source / Split` 三种渲染模式
- 每个 Markdown 文件会打开独立预览窗口，不会覆盖已有窗口
- 外部修改 Markdown 文件后，预览会自动刷新
- 点击文档里的本地 Markdown 链接会直接在应用内新开预览窗口
- 可注册为 Markdown 文件默认打开方式

## 构建

```bash
./scripts/build_app.sh
```

构建完成后会生成：

```bash
dist/MarkdownPreview.app
```

## 测试

```bash
swift test
./scripts/test_smoke.sh
```

## 设为默认打开方式

```bash
swift scripts/set_default_handler.swift dist/MarkdownPreview.app
```

如果你想把应用放到 `~/Applications`：

```bash
mkdir -p ~/Applications
cp -R dist/MarkdownPreview.app ~/Applications/
swift scripts/set_default_handler.swift ~/Applications/MarkdownPreview.app
```

## 说明

- 预览使用专门的 Markdown 组件渲染，标题、段落、列表、代码块会按块级语义展示
- 预览会使用当前文档目录作为相对链接和图片的解析基准
- 默认关联只针对 Markdown 类型，不会接管普通 `.tx