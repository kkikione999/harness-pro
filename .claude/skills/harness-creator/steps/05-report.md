# Step 5: 输出报告

输出最终报告:

```markdown
# Harness Creator 报告

## 模式
{initial/improve}

## 审计得分
{得分}/100

## 生成的文件
- AGENTS.md ✓/✗
- docs/ARCHITECTURE.md ✓/✗
- docs/DEVELOPMENT.md ✓/✗
- scripts/lint-deps ✓/✗
- scripts/lint-quality ✓/✗
- scripts/validate.py ✓/✗
- E2E 验证 ✓/✗
- harness/ ✓/✗

## 验证结果
- lint-deps: {PASS/FAIL/SKIP}
- lint-quality: {PASS/FAIL/SKIP}
- validate.py: {PASS/FAIL/SKIP}

## 层级映射
{layer_map 可读形式}

## 下一步建议
- {根据缺失项给出具体建议}
```
