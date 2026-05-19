---
status: accepted
date: 2026-04-01
---

# ADR-001: AppContainer 组合模式

## 上下文

项目有多个 Feature Store（Recording、Settings、Playback 等），它们共享底层依赖（DeviceSession、KnownDeviceRepository、AppPreferenceStore）。需要决定依赖注入的方式。

## 决策

使用 `AppContainer` 作为组合根（Composition Root），在 `AppBootstrap` 中组装所有依赖，然后通过构造函数注入到各 Feature Store。

- Feature Store 不自己创建 DeviceSession 或 protocol client。
- `AppContainer` 持有所有 Feature Store 的共享实例。
- `AppRootView` 从 `AppBootstrap.container` 获取 Store 并传给 View。

## 备选方案

1. **全局单例**：简单但难以测试，违反依赖反转。
2. **Environment / DI 框架**：过度工程，项目规模不需要。
3. **每个 Feature 自己组装**：会导致 DeviceSession 被多次创建，状态不一致。

## 后果

- 正面：测试可用 Fake 实现替换依赖；Feature 之间共享同一 DeviceSession 实例。
- 负面：新增 Feature 时需在 AppContainer 中注册，有一定样板代码。
