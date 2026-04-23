# 设备接入规格

本文件只记录当前 onboarding 骨架和后续真实接入时必须保持的契约。

## 当前代码对齐结果

- 根路由只在 `onboarding` 和 `main(MainTab)` 之间切换；`AppBootstrap` 通过 `AppPreferenceStore.hasCompletedOnboarding` 决定初始入口。
- `DeviceOnboardingView` 已拆成多步引导骨架，当前步骤为：
  - `preparation`
  - `hotspotGuide`
  - `verification`
  - `recovery`
  - `ready`
- 当前 UI 已显式区分“已连设备热点”和“已确认设备可控”两个状态。
- `DeviceOnboardingStore.finishOnboarding()` 会将 `hasCompletedOnboarding` 置为 `true` 并跳到 `dashboard`。
- `DeviceOnboardingStore.clearPlaceholderData()` 会清空 `KnownDeviceRepository` 和 `AppPreferenceStore`，重置流程并回到 onboarding。
- 当前失败路径已收敛到显式恢复页，提供重新校验、返回热点步骤和清空本地状态入口。

## 当前范围外

- 真实热点发现
- `NEHotspotConfiguration` 接入
- Wi-Fi 连接
- 局域网握手
- 设备能力探测
- 失败重试与恢复

## 后续接入约束

- onboarding 完成态仍由统一状态决定，不能把入口分流散落到多个 Feature 中。
- UI 必须继续区分“已连设备热点”和“设备已经可控”，不能把两者重新压扁成一个完成态。
- 真实连接、握手和超时控制不直接写在 View 内。
- 后续接入真实 AP 能力时，优先把错误映射到热点连接失败、连接后校验失败、需手动恢复这几类显式分流。
- 新增步骤时，优先扩展 Store、Route、Session 契约，不回退到临时布尔值堆砌。
