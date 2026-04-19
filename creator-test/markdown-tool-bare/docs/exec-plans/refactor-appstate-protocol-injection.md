# Execution Plan: AppState 协议注入重构

## 目标
消除 `AppState` 与 `AppWindowManager`、`PreviewWindowController`、`ContentView` 之间的直接耦合，使用协议注入替代。

## 影响范围
- `AppState.swift` - 添加协议
- `AppWindowManager.swift` - 改用工厂模式
- `PreviewWindowController.swift` - 使用协议类型
- `ContentView.swift` - 使用协议类型

## 步骤

### 1. 创建 AppState 协议
在 `AppState.swift` 中添加 `AppStateProtocol` 协议，包含：
- `document: Document?` (只读)
- `errorMessage: String?`
- `windowTitle: String` (只读)
- `renderMode: MarkdownRenderMode`
- `reload()` 方法
- `open(url:)` 方法
- `save(text:)` 方法

### 2. 让 AppState 遵循协议
`AppState` 声明遵循 `AppStateProtocol`

### 3. 重构 PreviewWindowController
- 将 `let appState: AppState` 改为 `let appState: any AppStateProtocol`
- 初始化时接收 `any AppStateProtocol`

### 4. 重构 ContentView
- 将 `@ObservedObject var appState: AppState` 改为 `var appState: any AppStateProtocol`
- 注意：`@ObservedObject` 需要具体类型，改用 `Observable` 协议或移除

### 5. 更新 AppWindowManager
- 添加 `AppStateFactory` 协议
- 默认实现创建 `AppState`
- 注入工厂而非直接创建

### 6. 更新测试
确保测试仍能正常运行

## 验证
- [ ] `swift build` 通过
- [ ] `swift test` 通过
- [ ] 无编译警告

## 回滚计划
如有问题，使用 git 回滚：
```bash
git checkout HEAD -- Sources/MarkdownPreview/
```

## 检查点
- Phase 1: 协议定义完成
- Phase 2: 所有类型改为协议
- Phase 3: 验证通过