# Step 4: 验证与修复

> 门控: Step 3 完成 + files_written 非空。运行 `{skill-dir}/scripts/creator-pipeline gate 4` 确认。

## 验证循环 (最多 2 轮)

```
第 1 轮:
  1. chmod +x scripts/lint-deps scripts/lint-quality (如果存在)
  2. 运行 lint-deps
     ├─ 通过 → 继续
     └─ 失败 → 读取错误输出，修复生成的脚本，进入第 2 轮
  3. 运行 lint-quality (如果存在)
  4. 运行 validate.py (如果项目可构建)

第 2 轮 (仅在修复后):
  1. 重新运行失败的脚本
     ├─ 通过 → 继续
     └─ 仍然失败 → 报告错误，让用户介入，不阻塞后续
```

## 注意

- 修复只改生成的脚本本身，不改项目源代码
- 如果项目本身无法构建 (缺少依赖等)，跳过 build/test，只验证 lint 脚本可执行
- 验证结果作为报告的一部分，不写入状态

## 完成后

```bash
{skill-dir}/scripts/creator-pipeline advance 4
```
