# Cam360

Cam360 是一个 iOS 行车记录仪 App。当前仓库以 M0 骨架为主，已经有启动分流、主路由、基础 DesignSystem、设置页和本地存储；真实设备接入、实时预览、回放、下载等链路仍处于后续阶段。

这个项目默认由 AI 持续接手维护，用户主要提供目标和指令，不手写代码。为了让后续 AI 会话能快速接续，根目录固定维护以下四份文档：

| 文件 | 用途 |
| --- | --- |
| `README.md` | 项目简介、文档入口、当前快照 |
| `PROJECT_CONTEXT.md` | 长期有效的信息、边界、代码事实 |
| `TASKS.md` | 当前任务、下一步计划、待决事项 |
| `CHANGELOG.md` | 已实际发生的改动历史 |

## AI 进入仓库后的阅读顺序

1. 读本文件，确认项目定位和当前文档入口。
2. 读 `PROJECT_CONTEXT.md`，确认长期有效事实。
3. 读 `TASKS.md`，确认当前目标、下一步和待决事项。
4. 读 `CHANGELOG.md` 最近一节，确认最近一次实际改动。
5. 再进入 `.monkeycode/docs/README.md`、`.monkeycode/docs/AGENTS.md` 和相关规格文档补细节。

## 当前代码快照

- App 入口为 UIKit 生命周期桥接 + SwiftUI 根视图。
- 根级结构由 `AppBootstrap`、`AppRouter`、`AppContainer` 驱动。
- 当前主界面代码事实是 3 个 tab：`dashboard`、`gallery`、`settings`。
- `DeviceOnboarding`、`Settings` 已有可运行骨架和本地偏好读写。
- `LivePreview`、`Playback`、`Downloads` 仍是占位态 Store / View。
- 当前仓库只有 `Cam360Tests`，没有 `Cam360UITests`。

## 现有项目文档

- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)
- [TASKS.md](TASKS.md)
- [CHANGELOG.md](CHANGELOG.md)
- [.monkeycode/docs/README.md](.monkeycode/docs/README.md)
- [.monkeycode/docs/AGENTS.md](.monkeycode/docs/AGENTS.md)
- [.monkeycode/docs/Cam360技术架构文档.md](.monkeycode/docs/Cam360技术架构文档.md)
- [.monkeycode/specs/settings-components/README.md](.monkeycode/specs/settings-components/README.md)

## 维护规则

- 长期稳定事实只写进 `PROJECT_CONTEXT.md`，不要把短期任务塞进去。
- 当前任务、下一步、阻塞项只写进 `TASKS.md`。
- 任何已经落地的实际改动，都要追加到 `CHANGELOG.md`。
- 如果代码事实和旧文档冲突，以已检查过的代码为准，并尽快同步文档。
- 继续沿用仓库既有约束：不做模拟器验证，优先选择最窄的非模拟器校验方式。
