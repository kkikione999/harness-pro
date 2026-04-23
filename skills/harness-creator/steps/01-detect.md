# Step 1: 检测模式与语言

> 门控: 无前置条件。运行 `{skill-dir}/scripts/creator-pipeline gate 1` 确认。

## 检测模式

检查项目根目录是否存在 `AGENTS.md`。

- **存在** → `mode=improve`，后续步骤只更新缺失/过时项
- **不存在** → `mode=initial`，后续步骤全新生成

## 检测语言

按优先级检查项目根目录的特征文件:

| 文件 | 语言 |
|------|------|
| `go.mod` | go |
| `Package.swift` | swift |
| `package.json` | typescript |
| `requirements.txt` 或 `pyproject.toml` | python |
| 都没有 | unknown |

## 完成后

```bash
{skill-dir}/scripts/creator-pipeline advance 1 mode={initial|improve} language={go|swift|typescript|python|unknown}
```
