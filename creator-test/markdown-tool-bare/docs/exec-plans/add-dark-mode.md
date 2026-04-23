# Execution Plan: add-dark-mode

## Objective
添加白天/夜晚/系统跟随主题切换

## Invariants
- L0 无内部 import
- L4 可 import 任何低层
- 依赖方向: 高层 → 低层, 不反向
- Swift 6.2, strict concurrency
- 测试覆盖率 ≥ 80% (改动文件)

## Scope
### DO
- 新建 `Sources/MarkdownPreview/AppTheme.swift` (L0) — 主题枚举
- 修改 `Sources/MarkdownPreview/AppState.swift` (L4) — 添加 theme 属性
- 修改 `Sources/MarkdownPreview/ContentView.swift` (L4) — header 添加主题切换按钮, 应用 .preferredColorScheme

### DON'T
- 不改 MarkdownRenderMode.swift
- 不改 MarkdownPreviewView.swift (color scheme 由父级传递)
- 不改 FileWatcher, MarkdownInteractions 等非 UI 文件
- 不改 Package.swift

## Done-when
### Acceptance Criteria
- Given 用户打开 app, When 点击主题切换按钮, Then 界面在 light/dark/system 间切换
- Given 主题设为 dark, When 重新打开 app, Then 保持 dark 模式

### Technical Checks
- [ ] `swift build` 通过
- [ ] `./scripts/lint-deps` 通过 (无层级违规)
- [ ] `./scripts/lint-quality` 通过
- [ ] `swift test` 通过

## Phases

### Phase 1: 新建 AppTheme — Layer 0 (Types)
**Pre:** clean working tree
**Actions:**
- 创建 `Sources/MarkdownPreview/AppTheme.swift`
- 定义 enum AppTheme: String, CaseIterable, Identifiable { case light, dark, system }
- 提供 colorScheme: ColorScheme? 计算属性
**Forbidden:** 不改任何现有文件
**Post:** `swift build` 通过

### Phase 2: 接入 AppState — Layer 4 (UI)
**Pre:** Phase 1 Post
**Actions:**
- 修改 `AppState.swift` — 添加 `@Published var theme: AppTheme = .system`
- 使用 @AppStorage 或直接属性存储偏好
**Forbidden:** 不改 ContentView, 不改 MarkdownPreviewView
**Post:** `swift build` 通过

### Phase 3: UI 切换控件 — Layer 4 (UI)
**Pre:** Phase 2 Post
**Actions:**
- 修改 `ContentView.swift` header — 添加主题 Picker (light/dark/system 图标)
- 在最外层 VStack 添加 `.preferredColorScheme(appState.theme.colorScheme)`
**Forbidden:** 不改 L0-L3 文件, 不改 MarkdownPreviewView
**Post:** `swift build` 通过, 手动可切换主题

### Phase 4: Validate
**Pre:** Phase 3 Post
**Actions:** 无 — 仅运行验证
**Forbidden:** 不改代码
**Post:** build ✓, lint-deps ✓, lint-quality ✓, test ✓

## Rollback Plan
- 分支: `feature/add-dark-mode`
- 回滚: `git checkout -- Sources/ && rm Sources/MarkdownPreview/AppTheme.swift`
