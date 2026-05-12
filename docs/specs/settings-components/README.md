---
depends_on: [device-session, ui-components]
hardware_required: true
---

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
  - `HelpCenterView`（内含 private `FAQView`、`ContactSupportView` 本地子页面）
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
- 当前 `Privacy Policy`、`Terms of Service` 只有列表入口或占位交互；真实 legal copy 未提供前不补完整页面。
- `HelpCenterView` 内 `Contact Support` 子页面的电话、邮箱和在线客服地址仍是占位展示；真实联系方式未在业务资料中给出。
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
- `FAQ` 和 `Contact Support` 是 `HelpCenterView` 内的本地子页面，只补 UI 清单与 PRD 明确要求的离线支持内容，不接外部网页、电话或邮件动作。

## 维护规则

- 涉及设备写操作时采用悲观更新策略：提交成功后再更新最终状态；当前已落地设置多为本地或占位流转，未接真实设备写入。
- 只有在仓库里存在实际 `View` 或可达 `Route` 时，才能标记为“已落地”。
- 设计参考和代码现状必须分开写。
- 文档保持精简，不回到大表格罗列。
