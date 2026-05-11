## 任务：修改设置页面或设置 Store

### 前置读取
1. `Cam360/Features/Settings/SettingsStore.swift`
2. `Cam360/Features/Settings/SettingsModels.swift`
3. `Cam360/Features/Settings/SettingsRoute.swift`
4. `docs/specs/settings-components/README.md` — 设置组件规格
5. 目标页面的 View 文件

### 约束
- 设置写操作采用悲观更新策略，详见 `docs/specs/settings-components/README.md`。
- 设置组件族已在 `Core/DesignSystem/SettingsComponents.swift`，优先复用。
- `SettingsStore` 从 `DeviceSession` 只读消费设备状态；不直接操作连接。
- 新增设置项时，在 `SettingsModels.swift` 中定义模型，在 `SettingsRoute.swift` 中注册路由。

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
python3 scripts/session_verifier.py --scope unstaged --format text
```
