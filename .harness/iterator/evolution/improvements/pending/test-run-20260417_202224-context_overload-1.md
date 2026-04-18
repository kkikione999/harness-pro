# 改进提案 #test-run-20260417_202224-context_overload-1

**Iteration**: test-run-20260417_202224
**时间**: 2026-04-18T18:59:37.050519
**状态**: pending
**影响 Skill**: execute-task
**类型**: prompt_tweak

## 诊断来源

- 上下文严重衰减：tokens_per_tool_call = 0.0 < 300

## 问题描述

上下文严重衰减：tokens_per_tool_call = 0.0 < 300

## 改进方案

在 execute-task 的 SKILL.md 中增加以下内容：

### 上下文保护措施

当 tool_calls 超过 30 次时：
1. 暂停执行，输出当前进度摘要
2. 评估是否需要拆分为 sub-task
3. 如果需要，继续执行；如果不需要，注明原因后继续

增加 milestone review 的触发频率：
- 每完成一个 milestone 必须 review
- review 时检查上下文消耗，如果消耗过大则拆分后续任务

## 预期效果

解决 context_overload 问题，提升 Skill 链路的质量和可靠性。

## 风险评估

**风险等级**: medium
**风险说明**: 修改 prompt 可能影响其他场景
**回滚计划**: 保留原 prompt 内容，可快速回滚

## 验证方式

**验证方法**: 在下一次迭代中观察是否仍有 context_overload 类型的诊断。
**建议测试**: 使用与本次迭代相似的 case，观察改进是否生效。
