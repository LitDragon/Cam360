## 任务：修改设备协议层代码

### 前置读取
1. `docs/specs/device-protocol/README.md` — 协议规格
2. `Cam360/Core/DeviceProtocol/` 下所有文件
3. `Cam360Tests/DeviceProtocolTests.swift` — 现有协议测试
4. `Cam360Tests/DeviceSessionProtocolTests.swift` — 现有会话测试

### 约束
- 协议 JSON、分帧、请求队列和 Topic 解析必须封装在 Core 侧。
- Feature 不直接拼接原始 JSON。
- 新增 Topic 或修改消息结构时，同步更新 `device-protocol` spec。
- 遵循 TDD：先写失败测试，再实现。

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
xcodebuild test -project Cam360.xcodeproj -scheme Cam360 -destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
```
