# 设置组件规格

本文件记录设置相关设计参考和当前仓库已落地范围，不再维护冗长的“页面 x 组件”实现矩阵。

## 来源

- `/Users/naxclow/Cam360/UI/开关设置/总和.png`
- `/Users/naxclow/Desktop/UI/设置.png`

## 当前代码对齐结果

- 已接入页面：
  - `SettingsView`
  - `NotificationSettingsView`
  - `SystemPermissionsView`
- 已接入路由：
  - `notificationSettings`
  - `systemPermissions`
- 当前 `Help Center`、`Privacy Policy`、`Terms of Service` 只有列表入口或占位交互，还不是完整页面。

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

- Help Center
- Device Settings Overview / Detail
- Storage Policy
- Video Quality
- Watermark Configuration
- Network Identity
- Safety

## 维护规则

- 只有在仓库里存在实际 `View` 或可达 `Route` 时，才能标记为“已落地”。
- 设计参考和代码现状必须分开写。
- 文档保持精简，不回到大表格罗列。
