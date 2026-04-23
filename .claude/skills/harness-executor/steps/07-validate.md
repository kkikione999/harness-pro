# Step 7: 验证管道

> 门控: Step 5 完成 (Simple) 或 Step 6 完成 (Medium/Complex)。运行 `./scripts/harness-gate {task} 7` 确认。

审查通过后，运行全量验证管道确认代码在机械层面也正确。

按顺序运行，第一步失败即停。Medium/Complex 任务全部 5 步必须跑:

```
build → lint-deps → lint-quality → test → verify (E2E)
```

每步单独运行，记录结果。完成时应有 5 个结果。E2E 验证通过读 `docs/E2E.md` 并按指南操作（观测+控制），无 E2E 文档时记录 "SKIPPED — no E2E verification available"。

**验证清单** (全部填完才能继续):

| Step | Command | Result |
|------|---------|--------|
| Build | `{build command}` | ✓ PASSED / ✗ FAILED |
| Lint-deps | `./scripts/lint-deps` | ✓ PASSED / ✗ FAILED |
| Lint-quality | `./scripts/lint-quality` | ✓ PASSED / ✗ FAILED |
| Test | `{test command}` | ✓ PASSED / ✗ FAILED |
| Verify | `docs/E2E.md` (按指南操作) | ✓ PASSED / ✗ FAILED / SKIPPED — {reason} |

读取 `references/validation.md` 了解自修复循环和上下文预算。

**预验证习惯**: 在新位置创建文件或添加跨模块 import 前，先跑 `./scripts/lint-deps` 提前捕获层级违规。

验证失败时，最多修复 3 次，上下文预算 ~40 tool calls。仍失败: 保存到 `harness/trace/failures/` 并升级给人类。

完成后:
```
./scripts/harness-state advance {task} 7 validation_build=passed validation_lint_deps=passed validation_lint_quality=passed validation_test=passed validation_verify=passed
```
(把 passed/failed 和 N 替换为实际结果, 加 self_repair_attempts=N)
