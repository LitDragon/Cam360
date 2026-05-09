## 任务：为现有功能补测试

### 前置读取
1. 目标功能的源文件
2. `Cam360Tests/` 下现有测试作为参考风格
3. `AGENTS.md` 的实施原则

### 约束
- 使用 Swift Testing 框架（`import Testing`、`@Test`、`#expect`）。
- 测试风格与现有测试保持一致：`@MainActor`、`makeUserDefaults()` 辅助函数、`waitForOnboardingState` 等待异步状态。
- 协议层测试优先用 Fake Transport 做回放，不用真实网络。
- 不修改生产代码。

### 步骤
1. 确定要覆盖的场景（正常路径、边界、错误）
2. 写测试
3. 运行确认通过
4. 确认覆盖率有意义（不只是 happy path）

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
xcodebuild test -project Cam360.xcodeproj -scheme Cam360 -destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
```
