# PROJECT_CONTEXT

本文件只记录长期有效事实。短期任务写 `TASKS.md`，实际改动写 `CHANGELOG.md`。

项目默认以仓库文档作为主事实源；AI 跨会话接手时，应先通过文档恢复上下文，再进入代码实现。

## 项目定位

- 项目名称：`Cam360`
- 产品类型：行车记录仪 App
- 连接模型：设备热点 AP 模式 + 局域网通信

## 技术基线

- 开发语言：Swift
- 开发流程：非纯 UI/文档改动默认按 TDD 推进，具体例外以 `../AGENTS.md` 的实施原则为准。
- 最低支持版本：`iOS 13`
- 主路径风格：优先沿用 `iOS 15` 时代稳定写法
- UI：SwiftUI 为主，UIKit 生命周期桥接
- 测试：`Swift Testing`

## 目录边界

- `Cam360/App`：生命周期、根路由、依赖装配、根视图
- `Cam360/Core`：DesignSystem、Shared、Storage、Device
- `Cam360/Features`：按功能拆分的页面和 Store
- `Cam360Tests`：当前唯一测试 target

## Feature 模块命名规范

每个 Feature 目录的标准文件结构：

```
Features/{FeatureName}/
  {FeatureName}View.swift       — 页面视图（必须）
  {FeatureName}Store.swift      — 状态管理（必须）
  {FeatureName}Route.swift      — 本地路由枚举（如果页面有二级导航）
  {FeatureName}Models.swift     — 数据模型（如果模型较复杂）
  Components/                   — Feature 私有子组件（如果组件较多）
```

当前例外情况：
- `Dashboard` 和 `Gallery` 没有独立 Route，路由由 `AppRouter` 统一管理。
- `Events` 只有 View，状态和路由暂由 Dashboard Store 代管。
- `Settings` 因页面较多，拆分为多个 `{PageName}View.swift`。

新增 Feature 时按标准结构创建；不回溯重构已有例外。
