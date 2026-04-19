# Harness Executor Tester

用于测试 harness-executor skill 的脚本。

## 文件结构

```
output-4/
├── harness-executor-tester.sh  # 主测试脚本
├── parse-results.py            # JSON stream 解析器
└── README.md                   # 本文件
```

## 使用方法

### 基本用法

```bash
cd /Users/josh_folder/harness-simple/creator-test/output-4

# 运行测试
./harness-executor-tester.sh "<test_name>" "<prompt>" [project_path]
```

### 示例

```bash
# Test 1: AGENTS.md 缺失检测
./harness-executor-tester.sh \
  "test-1-missing-agents" \
  "修复 MarkdownFileType.swift 中的拼写错误" \
  /Users/josh_folder/harness-simple/creator-test/markdown-tool-bare

# Test 2: Simple task
./harness-executor-tester.sh \
  "test-2-simple-task" \
  "修复 README.md 中的 typo" \
  /Users/josh_folder/harness-simple/creator-test/markdown-tool-bare
```

## 输出

每个测试会在 `output-4/{test_name}/` 目录下生成：

| 文件 | 内容 |
|------|------|
| `execution.log` | 执行日志 |
| `stream_raw.jsonl` | 原始流数据 |
| `thinking.txt` | 思考过程 |
| `tool_calls.json` | 工具调用统计 |
| `metrics.json` | token/duration/cost |
| `final_output.txt` | 最终输出 |
| `parse_status.json` | 解析状态 |

## 测试场景

### Test 1: AGENTS.md 缺失
- **目的**: 验证 Executor 自动调用 harness-creator
- **Setup**: 删除 AGENTS.md 和 scripts
- **Prompt**: 修复拼写错误
- **验收**: AGENTS.md 和 scripts 被创建

### Test 2: Simple Task
- **目的**: 验证 Executor 直接执行
- **Setup**: 已有 harness 基础设施
- **Prompt**: 修复 typo
- **验收**: 无计划文件，直接执行

### Test 3: Medium Task
- **目的**: 验证 Executor 创建计划 + 委派
- **Prompt**: 添加 CLI 命令
- **验收**: 计划文件存在，等待批准，委派子代理

### Test 4: Complex Task
- **目的**: 验证 Executor 使用 worktree + Opus
- **Prompt**: 架构重构
- **验收**: worktree 创建，Opus 模型，验证通过

## 注意事项

1. 测试脚本会在项目目录中执行 Claude Code
2. 需要先确保项目路径正确
3. 某些测试需要预先设置（如删除 AGENTS.md）
4. 查看 `execution.log` 了解详细执行过程
