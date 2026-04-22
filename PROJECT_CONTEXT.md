# PROJECT_CONTEXT

本文件只记录长期有效、适合跨会话复用的信息。短期任务和临时结论不要写在这里。

## 1. 项目定位

- 项目名称：`Cam360`
- 平台：iOS
- 产品类型：行车记录仪 App
- 连接模型：以设备热点 AP 模式为前提，后续通过局域网与设备通信
- 协作模型：默认由 AI 持续编写和维护代码，用户主要下达目标和约束

## 2. 当前阶段

- 当前阶段仍以 `M0 骨架` 为主。
- 已落地的是启动分流、主路由、基础页面骨架、最小 DesignSystem、本地偏好存储、部分设置页。
- 未落地真实链路：AP onboarding、真实 `DeviceSession` 接入、实时预览、回放、下载导出、真实设备设置读写。

重要：
- 规划文档里的目标态不等于仓库现状。
- 如果文档和代码冲突，以当前代码事实为准，再补同步文档。

## 3. 技术基线

- 开发语言：Swift
- 最低支持版本：`iOS 13`
- 主路径风格：优先沿用 `iOS 15` 时代稳定写法
- UI：SwiftUI 为主，UIKit 生命周期桥接
- 状态模型：`ObservableObject`、`@Published`、`@ObservedObject`、`@State`
- 持久化：`UserDefaults` + App Sandbox
- 测试：`Swift Testing`
- 依赖策略：保持最小化；当前已见第三方依赖为 `Lottie`

## 4. 当前架构事实

- 根级入口：
  - `Cam360/App/AppBootstrap.swift`
  - `Cam360/App/AppRouter.swift`
  - `Cam360/App/AppContainer.swift`
  - `Cam360/App/AppRootView.swift`
- 目录组织：
  - `Cam360/App`：生命周期、路由、依赖装配、根视图
  - `Cam360/Core`：DesignSystem、Shared、Storage、Device
  - `Cam360/Features`：按功能拆分的页面与 Store
  - `Cam360Tests`：当前唯一测试 target
- 当前导航事实：
  - 启动分流由 `AppBootstrap` 根据 `hasCompletedOnboarding` 决定
  - 当前主界面代码只有 3 个 tab：`dashboard`、`gallery`、`settings`
  - `events` 页存在文件，但没有接入当前主 tab
- 当前依赖注入事实：
  - `AppContainer` 已组合 `KnownDeviceRepository`、`AppPreferenceStore`
  - 已注入的 Feature Store 包括 `DeviceOnboardingStore`、`DeviceListStore`、`LivePreviewStore`、`PlaybackStore`、`DownloadsStore`、`SettingsStore`

## 5. 当前功能完成度

- 相对完整：
  - 启动分流
  - Onboarding 到主界面的切换
  - Settings 页及其部分子页面
  - `UserDefaults` 驱动的设备/偏好读写
- 占位或骨架态：
  - `LivePreview`
  - `Playback`
  - `Downloads`
  - 设备真实连接与控制
- 预留但未接真实能力：
  - `Core/Device/DeviceSession.swift`

## 6. 当前已知事实差异

以下差异已经通过代码和仓库结构确认，后续 AI 不应继续沿用旧说法：

- 旧文档有“4-tab 主界面”的描述，但当前代码实际是 3-tab。
- 旧文档有“最小 UI 冒烟测试 / Cam360UITests”的描述，但当前仓库只有 `Cam360Tests`。
- 旧文档把 `DeviceSession` 归为 M1+ 规划能力，但仓库里已经存在一个本地状态机骨架文件；它不代表真实设备链路已接通。

## 7. 当前重要文档

- 根目录：
  - `README.md`
  - `PROJECT_CONTEXT.md`
  - `TASKS.md`
  - `CHANGELOG.md`
- 仓库规范：
  - `.monkeycode/docs/README.md`
  - `.monkeycode/docs/AGENTS.md`
  - `.monkeycode/docs/Cam360技术架构文档.md`
- 当前可见规格：
  - `.monkeycode/specs/settings-components/README.md`

## 8. 文档维护约定

- 修改项目定位、技术基线、目录边界、阶段定义时，更新本文件。
- 修改当前任务、优先级、下一步计划时，更新 `TASKS.md`。
- 完成实际改动时，更新 `CHANGELOG.md`。
- 若新增 Feature spec，补到本文件“当前重要文档”部分。
- 延续仓库现有约束：默认不做模拟器验证，验证优先选择最窄的非模拟器方式。
