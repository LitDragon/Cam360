# 设备接入规格

本文件只记录当前 onboarding 骨架和后续真实接入时必须保持的契约。

## 当前代码对齐结果

- 根路由仍保留 `onboarding` 和 `main(MainTab)`；`AppBootstrap` 当前默认进入 `main(MainTab)`。
- 首次启动提示由首页根据 `AppPreferenceStore.hasCompletedOnboarding` 展示底部功能推荐 Sheet。
- 首页空设备态和设备抽屉中的 `Add Device` 都通过根路由进入 `DeviceOnboarding`。
- `DeviceOnboardingRoute` 当前包含 `introduction`、`searching`、`wifiDetails`、`connecting`、`success` 五步。
- `DeviceOnboardingStore` 负责分步状态、临时 Wi‑Fi 输入、自动推进和成功落库；`DeviceOnboardingView` 只渲染 UI 并转发用户动作。
- 成功闭环会向 `KnownDeviceRepository` 写入 1 条本地占位设备，将 `hasCompletedOnboarding` 置为 `true`，再返回首页。

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
