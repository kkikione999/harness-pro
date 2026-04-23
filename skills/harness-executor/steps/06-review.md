# Step 6: 快速编译检查 + 交叉审查 (Medium/Complex)

> 门控: Step 5 必须完成。运行 `./scripts/harness-gate {task} 6` 确认。
> Simple 任务会被 gate 脚本自动跳过 (退出码 2)。

### 快速编译检查

交叉审查前先确认代码能编译。审查编译不过的代码是浪费审查者的上下文。

```bash
{build command}  # 仅编译，不跑测试
```

- 编译失败 → Sub-agent 修复编译错误 → 重新编译 → 最多 2 次
- 编译失败 2 次仍不过 → 保存到 `harness/trace/failures/`，升级给人类

### 交叉审查

编译通过后，委派审查给**不同模型**。不同模型有不同盲点 — 这能捕获 linter 和测试遗漏的问题。

读取 `references/cross-review.md` 了解审查 prompt 模板和结果处理。

**跳过**: Simple 任务、< 20 行改动、自动生成代码、仅测试改动。

**审查维度**:
1. 逻辑正确性和边界情况
2. 与 AGENTS.md 架构的一致性
3. 命名清晰度和代码可读性
4. 性能影响
5. **过度设计检查**:
   - 是否有超出任务要求的抽象？
   - 是否有"顺便"重构/改进？
   - 错误处理是否覆盖了不可能发生的场景？
   - 文件数和改动行数是否与任务复杂度匹配？

审查结果 → 动作:

| 结果 | 动作 |
|------|------|
| PASS | 进入 Step 7 |
| MEDIUM | 记录，进入 Step 7 |
| HIGH | Sub-agent 修复，重新编译 + 重审受影响部分 |
| CRITICAL | Sub-agent 修复，重新编译 + 全量重审 |

完成后:
```
./scripts/harness-state advance {task} 6 review_result=pass review_model=模型名
```
