# Cam360

Cam360 是一个 iOS 行车记录仪 App。

Cam360 采用文档优先的开发方式：当前状态、已实现能力、下一步计划、架构边界、UI 流程与组件关系默认以仓库文档为准；AI 接手时先读文档，再读代码。

## 文档入口

默认从本文件开始，其他文档按职责读取：

| 文件 | 用途 |
| --- | --- |
| `PROJECT_CONTEXT.md` | 长期有效事实、技术基线、目录边界 |
| `TASKS.md` | 当前任务、下一步、待决事项 |
| `CHANGELOG.md` | 实际改动历史 |

补充文档按需读取：

- [.monkeycode/docs/Cam360技术架构文档.md](.monkeycode/docs/Cam360技术架构文档.md)：架构边界、路由与依赖注入、M1+ 演进顺序
- [.monkeycode/specs/settings-components/README.md](.monkeycode/specs/settings-components/README.md)：设置相关规格
- [.monkeycode/specs/device-protocol/README.md](.monkeycode/specs/device-protocol/README.md)：设备协议规格，收敛 iOS 可用的控制通道、握手、错误码与 Topic 口径
- [.monkeycode/specs/device-onboarding/README.md](.monkeycode/specs/device-onboarding/README.md)：设备接入规格
- [.monkeycode/specs/device-session/README.md](.monkeycode/specs/device-session/README.md)：`DeviceSession` 规格
- [.monkeycode/specs/live-preview/README.md](.monkeycode/specs/live-preview/README.md)：实时预览规格
- [.monkeycode/MEMORY.md](.monkeycode/MEMORY.md)：用户长期指令和项目记忆

## 自动化

- `.github/workflows/ci.yml`：push / PR 时执行 Simulator build/test。
- `.github/workflows/refactor-agent.yml`：手动或定时扫描 Swift 架构债；配置在 `.github/refactor-agent.json`，脚本为 `scripts/refactor_agent.py`，产物写入被忽略的 `build/refactor-agent/`。
