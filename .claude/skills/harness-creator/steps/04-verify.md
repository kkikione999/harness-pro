# Step 4: 验证与修复

## 验证循环 (最多 2 轮)

第 1 轮:
1. `chmod +x scripts/lint-deps scripts/lint-quality`（如存在）
2. 运行 lint-deps → 失败则修复脚本，进入第 2 轮
3. 运行 lint-quality（如存在）
4. 运行 validate.py（如项目可构建）

第 2 轮:
- 重新运行失败的脚本 → 仍失败则报告用户，不阻塞后续

修复只改生成的脚本，不改项目源代码。
