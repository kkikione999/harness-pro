# Step 1: 检测模式与语言

## 检测模式

检查项目根目录是否存在 `AGENTS.md`。

- **存在** → `mode=improve`，只更新缺失/过时项
- **不存在** → `mode=initial`，全新生成

## 检测语言

按优先级检查项目根目录的特征文件:

| 文件 | 语言 |
|------|------|
| `go.mod` | go |
| `Package.swift` | swift |
| `package.json` | typescript |
| `requirements.txt` 或 `pyproject.toml` | python |
| 都没有 | unknown |
