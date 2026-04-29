# 设置组件规格

本文件记录设置相关已落地范围和维护规则，不再维护冗长的“页面 x 组件”实现矩阵。

## 已落地范围

- 已接入页面：
  - `SettingsView`
  - `SettingsOverviewView`
  - `SystemPreferencesView`
  - `RecordingSettingsView`
  - `StoragePolicyView`
  - `WatermarkConfigurationView`
  - `SafetySettingsView`
  - `DeviceSettingsDetailView`
  - `RenameDeviceView`
  - `HelpCenterView`
  - `NotificationSettingsView`
  - `SystemPermissionsView`
- 已接入路由：
  - `systemPreferences`
  - `recordingSettings`
  - `storagePolicy`
  - `watermarkConfiguration`
  - `deviceSettings`
  - `safetySettings`
  - `renameDevice`
  - `helpCenter`
  - `notificationSettings`
  - `systemPermissions`
- 当前 `Privacy Policy`、`Terms of Service` 只有列表入口或占位交互，还不是完整页面。
- `SettingsStore` 已从 `DeviceSession` 只读消费设备身份、固件版本和能力集；`Network Identity`、`Firmware Update` 写操作仍是本地内嵌流转。

## 当前可复用组件

- `AppTopBar`
- `SettingsSectionHeader`
- `SettingsGroupCard`
- `SettingsNavigationRow`
- `SettingsToggleRow`
- `SettingsStatusRow`
- `SettingsActionRow`
- `SettingsSearchBar`
- `SettingsTimeField`
- `SettingsFootnote`
- `SettingsValueRow`
- `SettingsInputRow`
- `SettingsSegmentedRow`
- `SettingsMetricCard`
- `SettingsNoticeCard`
- `PrimaryButton`
- `DestructiveButton`
- `StatusTag`

## 仍属于设计参考、未在代码中接完整页面

- `Firmware Update` 的下载、失败和成功反馈仍是本地占位流转，不是真实升级链路。
- `Storage Policy` 的 no-card / ready / error 仍是本地状态切换，不接真实存储事件。

## 维护规则

- 只有在仓库里存在实际 `View` 或可达 `Route` 时，才能标记为“已落地”。
- 设计参考和代码现状必须分开写。
- 文档保持精简，不回到大表格罗列。
