## 任务：新增 Feature 页面

### 前置读取
1. `docs/specs/ui-flow/README.md` — 页面导航和路由规范
2. `docs/specs/ui-components/README.md` — 公共组件清单
3. `Cam360/Features/` 下最近一个 Feature 的代码结构作为参考
4. `Cam360/App/MainTabView.swift` 或来源页面本地 route — NavigationLink 入口
5. `Cam360/App/AppContainer.swift` — 依赖注入方式

### 约束
- View 不直接持有 DeviceSession 或底层连接；共享依赖从 AppContainer 下发。
- Store 使用 `@Published` 驱动状态，不用 `@Observable`（需兼容 iOS 13）。
- 页面内临时 UI 状态保留在 Store 内，不升级为 App 根状态。
- Home / Gallery 的跨页面入口通过 `MainTabView` 内的 `NavigationLink` 进入；录像页（`RecordingView`）的二级页面入口保留在 `RecordingView` 本地 route。

### 文件创建规则
```
Cam360/Features/{FeatureName}/
  {FeatureName}View.swift
  {FeatureName}Store.swift
  {FeatureName}Route.swift  // 如果有独立路由
```

### 步骤
1. 创建 View + Store（+ Route）文件
2. 在 `AppContainer.swift` 中创建 Store 实例
3. 在 `MainTabView.swift` 或来源页面本地 route 中添加 NavigationLink 目标和触发入口
4. 在触发入口的 View 中添加跳转回调
5. 按需隐藏自定义底部 tab
6. 跑 `xcodebuild build` 验证编译通过
7. 更新 `docs/specs/ui-flow/README.md` 的路由和主流程

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
python3 scripts/session_verifier.py --scope unstaged --format text
```
