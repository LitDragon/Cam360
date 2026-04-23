# PROJECT_CONTEXT

本文件只记录长期有效事实。短期任务写 `TASKS.md`，实际改动写 `CHANGELOG.md`。

## 项目定位

- 项目名称：`Cam360`
- 平台：iOS
- 产品类型：行车记录仪 App
- 连接模型：设备热点 AP 模式 + 局域网通信

## 当前代码事实

- 当前阶段仍以 `M0 骨架` 为主。
- App 入口为 UIKit 生命周期桥接 + SwiftUI 根视图。
- 根级结构由 `AppBootstrap`、`AppRouter`、`AppContainer`、`AppRootView` 驱动。
- `AppBootstrap` 根据 `AppPreferenceStore.hasCompletedOnboarding` 决定进入 `onboarding` 还是 `main(MainTab)`。
- 当前主界面继续保持 3 个 tab：`dashboard`、`gallery`、`settings`。
- `events` 页面文件仍存在，但当前不作为独立主 tab 恢复。
- `DeviceOnboarding` 已有“准备 -> 热点连接 -> 连接后校验 -> 失败恢复 -> 完成确认”的多步引导骨架。
- `Settings` 已有可用骨架与本地偏好读写。
- `LivePreview`、`Playback`、`Downloads` 仍是占位实现。
- `Core/Device/DeviceSession.swift` 已有本地状态机骨架，但未接真实设备链路。
- 当前测试 target 只有 `Cam360Tests`。

## 技术基线

- 开发语言：Swift
- 最低支持版本：`iOS 13`
- 主路径风格：优先沿用 `iOS 15` 时代稳定写法
- UI：SwiftUI 为主，UIKit 生命周期桥接
- 状态模型：`ObservableObject`、`@Published`、`@ObservedObject`、`@State`
- 持久化：`UserDefaults` + App Sandbox
- 测试：`Swift Testing`
- 第三方依赖：当前已见 `Lottie`

## 目录边界

- `Cam360/App`：生命周期、根路由、依赖装配、根视图
- `Cam360/Core`：DesignSystem、Shared、Storage、Device
- `Cam360/Features`：按功能拆分的页面和 Store
- `Cam360Tests`：当前唯一测试 target
