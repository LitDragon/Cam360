# Cam360

Cam360 是一个 iOS 行车记录仪 App。当前仓库仍以 M0 骨架为主，真实设备接入、实时预览、回放和下载链路尚未落地。

## 文档入口

根目录四份文档是当前事实来源：

| 文件 | 用途 |
| --- | --- |
| `README.md` | 项目简介和文档入口 |
| `PROJECT_CONTEXT.md` | 长期有效事实、边界、技术基线 |
| `TASKS.md` | 当前任务、下一步、待决事项 |
| `CHANGELOG.md` | 实际改动历史 |

补充文档位于 `.monkeycode/`：

- [.monkeycode/docs/README.md](.monkeycode/docs/README.md)
- [.monkeycode/docs/AGENTS.md](.monkeycode/docs/AGENTS.md)
- [.monkeycode/docs/Cam360技术架构文档.md](.monkeycode/docs/Cam360技术架构文档.md)
- [.monkeycode/specs/settings-components/README.md](.monkeycode/specs/settings-components/README.md)

## 当前代码事实

- App 入口为 UIKit 生命周期桥接 + SwiftUI 根视图。
- 根级结构由 `AppBootstrap`、`AppRouter`、`AppContainer` 驱动。
- 当前主界面只有 3 个 tab：`dashboard`、`gallery`、`settings`。
- `DeviceOnboarding` 和 `Settings` 已有骨架；`LivePreview`、`Playback`、`Downloads` 仍是占位实现。
- 当前仓库只有 `Cam360Tests`；没有 `Cam360UITests`。

## 文档标准

- 精简：默认短段落、短列表，只写当前必要信息。
- 单一事实来源：同一事实只在一个主文档详细维护，其他文档引用即可。
- 事实与规划分离：长期事实写 `PROJECT_CONTEXT.md`，短期计划写 `TASKS.md`。
- 代码优先：文档和代码冲突时，以已检查代码为准，并立即同步文档。
- 默认不做模拟器验证；优先选择最窄的非模拟器校验方式。
