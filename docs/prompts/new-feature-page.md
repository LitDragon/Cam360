## 任务：新增 Feature 页面

### 前置读取
1. `docs/specs/ui-flow/README.md` — 页面导航和路由规范
2. `docs/specs/ui-components/README.md` — 公共组件清单
3. `Cam360/Features/` 下最近一个 Feature 的代码结构作为参考
4. `Cam360/App/AppRouter.swift` — 现有路由枚举
5. `Cam360/App/AppContainer.swift` — 依赖注入方式

### 约束
- View 不直接持有 DeviceSession 或底层连接；共享依赖从 AppContainer 下发。
- Store 使用 `@Published` 驱动状态，不用 `@Observable`（需兼容 iOS 13）。
- 页面内临时 UI 状态保留在 Store 内，不升级为 App 根路由。
- 离线 feature route 通过 `AppRouter.showFeature(_:)` 进入，关闭后回到来源 tab。

### 文件创建规则
```
Cam360/Features/{FeatureName}/
  {FeatureName}View.swift
  {FeatureName}Store.swift
  {FeatureName}Route.swift  // 如果有独立路由
```

### 步骤
1. 创建 View + Store（+ Route）文件
2. 在 `AppRouter.swift` 的 `AppFeatureRoute` 中添加 case
3. 在 `AppContainer.swift` 中创建 Store 实例
4. 在 `AppRootView.swift` 的 `featureScreen(_:)` 中添加路由映射
5. 在触发入口的 View 中添加跳转调用
6. 跑 `xcodebuild build` 验证编译通过
7. 更新 `docs/specs/ui-flow/README.md` 的路由和主流程

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
xcodebuild build -project Cam360.xcodeproj -scheme Cam360 -destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
```
