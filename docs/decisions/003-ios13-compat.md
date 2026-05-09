---
status: accepted
date: 2026-04-01
---

# ADR-003: iOS 13 最低兼容策略

## 上下文

需要确定最低支持的 iOS 版本。SwiftUI 在 iOS 13 首次引入，iOS 15 有显著改进。

## 决策

- 最低支持 iOS 13。
- 主路径使用 iOS 15 语法糖。
- 如果引入 iOS 17+ 能力（如 `@Observable`、`NavigationStack`），必须隔离在 `#available` 分支外，不得影响主路径启动、路由和测试。

## 备选方案

1. **最低 iOS 15**：可以用更多 SwiftUI 特性，但排除旧设备用户。
2. **最低 iOS 17**：可以用 `@Observable`、`NavigationStack`，但排除大量用户。

## 后果

- 正面：覆盖更广设备范围。
- 负面：不能直接使用 `@Observable`、`NavigationStack`、`NavigationPath` 等新 API，需要兼容写法。
