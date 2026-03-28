# README 设计文档（基于 `oh-my-openagent` 案例）

- 文档版本：v1.0
- 生成日期：2026-03-17
- 目标路径：`/Users/zhuran/harness-pro/docs/readme-design-document.md`

## 1. 目标

沉淀一套可复用的 GitHub README 设计方法，达到“首屏有冲击力、信息可扫读、转化路径清晰、维护成本可控”的效果。

## 2. 结论摘要：为什么它看起来精美且优雅

`oh-my-openagent` 的 README 效果来自组合设计，而不是单一工具：

1. 高质量视觉素材：`hero` 横幅 + 产品预览图 + 角色图，形成强品牌识别。
2. Markdown 与 HTML 混排：在 GitHub 渲染能力内做精细排版（居中、表格、固定宽度徽章、换行）。
3. 动态徽章增强“活性”：stars/release/issues + 自定义 endpoint 徽章，提供实时可信度。
4. 内容结构产品化：首屏价值主张 -> 社会证明 -> 安装 CTA -> 功能矩阵 -> 深入文档。
5. 持续迭代：通过大量 docs/readme 提交不断优化文案、素材和布局。

## 3. 设计框架（可直接复用）

## 3.1 信息架构

建议按以下顺序组织 README：

1. 顶部提示区（NOTE/TIP）：社群入口、最新动态。
2. 首屏视觉区：品牌横幅 + 产品截图（居中、可点击）。
3. 指标徽章区：版本、下载量、star、issue、license。
4. 多语言入口：`README.zh-cn.md` / `README.ja.md` 等。
5. 社会证明区：用户评价、外部引用、媒体链接。
6. 快速开始区：复制即用安装指令（Human 与 Agent 双路径）。
7. 功能亮点区：表格化展示“功能-价值”。
8. 深入文档导航：overview / features / config / troubleshooting。

## 3.2 视觉规范

1. 首屏图片统一风格（颜色、构图、字体气质一致）。
2. 徽章样式统一（如 `flat-square` + 一致 `labelColor`）。
3. 内容块间使用水平线 `---` 分节，避免大段文字堆叠。
4. 标题控制在短语级别，正文使用短句，强化扫读体验。

## 3.3 文案策略

1. 首段明确“价值主张 + 受众 + 行动”。
2. 功能描述避免技术罗列，强调“解决什么痛点”。
3. 每段尽量附可验证链接（发布页、文档、社区、案例）。
4. 安装入口尽量做到“一段可复制文本”完成启动。

## 4. 需要上传/准备的内容清单

## 4.1 仓库内必须文件

1. `README.md`（主文档）。
2. `.github/assets/`（图片资源目录），建议至少包含：
   - `hero.jpg`（头图）
   - `preview.png` / `omo.png`（产品截图）
   - 角色或模块图（可选）
3. 多语言 README（可选）：
   - `README.zh-cn.md`
   - `README.ja.md`
   - `README.ko.md`
4. 深入文档目录（可选但强烈建议）：`docs/guide/*`、`docs/reference/*`。

## 4.2 外部服务（按需）

1. 徽章服务：`img.shields.io`。
2. 自定义动态徽章 API（可选）：为 `shields.io/endpoint` 提供 JSON。

示例返回格式：

```json
{
  "schemaVersion": 1,
  "label": "npm downloads",
  "message": "1.2M",
  "color": "ff6b35",
  "labelColor": "000000",
  "style": "flat-square"
}
```

## 5. 实现步骤（从 0 到 1）

1. 先定信息架构：按“首屏 -> 证据 -> 安装 -> 功能 -> 文档”排章节。
2. 准备视觉素材：输出 2 张核心图（hero + preview），放入 `.github/assets/`。
3. 搭好顶部框架：NOTE/TIP + 居中图片区 + 徽章区 + 语言切换。
4. 写安装与功能矩阵：优先写“最短路径”，再补完整能力说明。
5. 增加社会证明：精选 3-8 条外部引用，必须带来源链接。
6. 接入动态徽章（可选）：部署 API 后绑定 `shields.io/endpoint`。
7. 用真实用户视角走读：确保 10 秒内看懂“是什么、值不值、怎么开始”。

## 6. 可复用 README 骨架

```md
> [!NOTE]
> 社区入口与公告

<div align="center">

[![Hero](./.github/assets/hero.jpg)](#project-name)
[![Preview](./.github/assets/preview.png)](#project-name)

[![Release](https://img.shields.io/github/v/release/OWNER/REPO?style=flat-square)](https://github.com/OWNER/REPO/releases)
[![Stars](https://img.shields.io/github/stars/OWNER/REPO?style=flat-square)](https://github.com/OWNER/REPO/stargazers)
[![Downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Fyour.site%2Fapi%2Fdownloads&style=flat-square)](https://www.npmjs.com/package/PACKAGE)

[English](README.md) | [简体中文](README.zh-cn.md)

</div>

## Project Name

一句话价值主张。

## Installation

最短可复制安装路径。

## Highlights

| Feature | Value |
| :-- | :-- |
| 功能 A | 解决的问题 A |
| 功能 B | 解决的问题 B |

## Docs

- [Overview](docs/guide/overview.md)
- [Features](docs/reference/features.md)
- [Configuration](docs/reference/configuration.md)
```

## 7. 质量验收清单

发布前建议逐条检查：

1. 首屏 5-10 秒内能看懂项目定位。
2. 所有图片加载稳定，移动端不炸版。
3. 徽章颜色/样式统一，无失效链接。
4. 安装步骤可直接复制执行。
5. 每个核心主张有证据链接支撑。
6. 文案风格一致，无中英混乱与术语漂移。
7. README 与 `docs` 内容一致，无过期描述。

## 8. 维护策略

1. 将 README 更新纳入每次版本发布 checklist。
2. 重大功能上线时，同步更新 `Highlights` 与截图。
3. 每月做一次“链接健康检查 + 徽章状态检查”。
4. 对高频误解点，在顶部 TIP/FAQ 快速修正。

## 9. 参考来源

1. 仓库 README：<https://github.com/code-yeongyu/oh-my-openagent/blob/dev/README.md>
2. 素材目录：<https://github.com/code-yeongyu/oh-my-openagent/tree/dev/.github/assets>
3. 关键提交（加入 hero 与 badges）：<https://github.com/code-yeongyu/oh-my-openagent/commit/bc20853d8331ecd93817c37cff3132aa4295eb3a>
4. README 历史：<https://github.com/code-yeongyu/oh-my-openagent/commits/dev/README.md>
5. GitHub Markdown 语法：<https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax>
6. Shields endpoint 文档：<https://raw.githubusercontent.com/badges/shields/master/doc/endpoints.md>
7. 动态徽章接口示例：<https://ohmyopenagent.com/api/npm-downloads>
