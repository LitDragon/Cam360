# 设备接入规格

本文件只记录当前 onboarding 骨架和后续真实接入时必须保持的契约。

## 当前代码对齐结果

- 根路由只在 `onboarding` 和 `main(MainTab)` 之间切换；`AppBootstrap` 通过 `AppPreferenceStore.hasCompletedOnboarding` 决定初始入口。
- `DeviceOnboardingView` 当前只承载 `PermissionPageView` 骨架，主按钮为“进入应用”，次按钮为“清空本地状态”。
- `DeviceOnboardingStore.enterScaffold()` 会将 `hasCompletedOnboarding` 置为 `true` 并跳到 `dashboard`。
- `DeviceOnboardingStore.clearPlaceholderData()` 会清空 `KnownDeviceRepository` 和 `AppPreferenceStore`，并回到 onboarding。
- 当前 route 只声明 `DeviceOnboardingRoute.permissionGuide`，还没有分步流程。

## 当前范围外

- 真实热点发现
- Wi-Fi 连接
- 局域网握手
- 设备能力探测
- 失败重试与恢复

## 后续接入约束

- onboarding 完成态仍由统一状态决定，不能把入口分流散落到多个 Feature 中。
- 真实连接、握手和超时控制不直接写在 View 内。
- 新增步骤时，优先扩展 Store、Route、Session 契约，不回退到临时布尔值堆砌。
