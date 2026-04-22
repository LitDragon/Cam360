# PROJECT_CONTEXT

本文件只记录长期有效事实。短期任务、临时判断和执行过程不要写在这里。

## 文档标准

- 精简：默认短句、短段落、短列表。
- 单一事实来源：同一事实只保留一个主维护位置。
- 事实与规划分离：现状写这里，下一步写 `TASKS.md`。

## 项目定位

- 项目名称：`Cam360`
- 平台：iOS
- 产品类型：行车记录仪 App
- 连接模型：设备热点 AP 模式 + 局域网通信
- 协作模型：默认由 AI 持续维护代码，用户主要下达目标和约束

## 当前代码事实

- 当前阶段仍以 `M0 骨架` 为主。
- 根级结构由 `AppBootstrap`、`AppRouter`、`AppContainer`、`AppRootView` 驱动。
- 当前主界面只有 3 个 tab：`dashboard`、`gallery`、`settings`。
- `events` 页面文件存在，但没有接入当前主 tab。
- `DeviceOnboarding` 和 `Settings` 已有可用骨架与本地偏好读写。
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

## M1+ 待接入能力

- AP onboarding 真实接入
- `DeviceSession` 作为统一状态源
- 实时预览
- 回放
- 下载导出
- 真实设备设置读写

## 文档清单

- 根目录：
  - `README.md`
  - `PROJECT_CONTEXT.md`
  - `TASKS.md`
  - `CHANGELOG.md`
- 仓库规范：
  - `.monkeycode/docs/README.md`
  - `.monkeycode/docs/AGENTS.md`
  - `.monkeycode/docs/Cam360技术架构文档.md`
- 当前规格：
  - `.monkeycode/specs/settings-components/README.md`

## 维护约定

- 修改长期事实、技术基线、目录边界、阶段定义时，更新本文件。
- 修改短期任务和下一步计划时，更新 `TASKS.md`。
- 完成实际改动时，更新 `CHANGELOG.md`。
- 文档和代码冲突时，以已检查代码为准。
- 默认不做模拟器验证，优先选择最窄的非模拟器校验方式。
