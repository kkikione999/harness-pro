# Step 5: 输出报告

> 门控: Step 4 完成。运行 `{skill-dir}/scripts/creator-pipeline gate 5` 确认。

## 报告内容

```markdown
# Harness Creator 报告

## 模式
{initial/improve}

## 审计得分
{原始得分}/100

## 生成的文件
- AGENTS.md ✓/✗
- docs/ARCHITECTURE.md ✓/✗
- docs/DEVELOPMENT.md ✓/✗
- scripts/lint-deps ✓/✗
- scripts/lint-quality ✓/✗
- scripts/validate.py ✓/✗
- E2E 验证 ✓/✗ ({mode}: {路径})
- harness/ ✓/✗

## 验证结果
- lint-deps: {PASS/FAIL/SKIP}
- lint-quality: {PASS/FAIL/SKIP}
- validate.py: {PASS/FAIL/SKIP}

## 层级映射
{layer_map 的可读形式}

## 下一步建议
- {根据缺失项给出的具体建议}
```

## 完成后

```bash
{skill-dir}/scripts/creator-pipeline advance 5
```
