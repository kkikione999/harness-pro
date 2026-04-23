# Step 8: 完成

> 门控: Step 7 必须完成，且验证全通过。运行 `./scripts/harness-gate {task} 8` 确认。

每项产生一个具体产出物。全部完成 — 不可省略:

1. **Git**: Stage 具体文件 (禁止 `git add -A`)，conventional commit 格式
   - 产出: git log 中的 commit
2. **Trace**: 追加总结到已有的 `harness/state/{task}.trace.md` (步骤 3-7 已逐步追加)
   - 产出: 完整的 `harness/state/{task}.trace.md`
3. **Memory**: 写入 `harness/memory/INDEX.md` — 如果本任务揭示了模式/反模式/教训
   - 产出: 更新的 `harness/memory/INDEX.md` (不存在则创建)
4. **轨迹检查**: 如果同类任务成功 ≥ 3 次且步骤一致，建议编译为确定性脚本
5. **总结**: 报告做了什么、哪些验证通过、哪些产出物已创建

读取 `references/completion.md` 了解 git 工作流、轨迹编译和上下文预算感知修复。

完成后:
```
./scripts/harness-state advance {task} 8
```
