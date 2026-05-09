---
status: accepted
date: 2026-04-01
---

# ADR-002: 使用 Swift Testing 而非 XCTest

## 上下文

需要选择测试框架。Xcode 16 引入了 Swift Testing 框架。

## 决策

使用 Swift Testing（`import Testing`、`@Test`、`#expect`）作为唯一测试框架，不使用 XCTest。

## 备选方案

1. **XCTest**：成熟但 API 较旧，`XCTAssert` 系列可读性不如 `#expect`。
2. **混合使用**：增加认知负担，统一更简洁。

## 后果

- 正面：更现代的 API，更好的参数化测试支持，与 Swift 生态一致。
- 负面：部分高级功能（如 UI 测试）仍需 XCTest，但当前项目不做 UI 测试。
