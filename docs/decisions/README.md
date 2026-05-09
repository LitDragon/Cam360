# Architecture Decision Records

本目录记录 Cam360 的架构决策。每条 ADR 说明一个决策的上下文、选项和结果，避免 AI 在后续会话中重复纠结或遗忘已有选择。

## 索引

| ADR | 标题 | 状态 | 日期 |
| --- | --- | --- | --- |
| [001](001-appcontainer-composition.md) | AppContainer 组合模式 | accepted | 2026-04-01 |
| [002](002-swift-testing.md) | 使用 Swift Testing 而非 XCTest | accepted | 2026-04-01 |
| [003](003-ios13-compat.md) | iOS 13 最低兼容策略 | accepted | 2026-04-01 |
| [004](004-docs-first.md) | 文档先行开发模式 | accepted | 2026-04-01 |
| [005](005-offline-first.md) | 离线优先集成策略 | accepted | 2026-04-01 |

## 维护规则

- 新做架构决策时，写一条 ADR 并加入索引。
- ADR 只记录已经做出的决策，不记录计划或讨论中的方案。
- 如果决策被推翻，旧 ADR 标记为 `superseded`，新 ADR 引用旧编号。
