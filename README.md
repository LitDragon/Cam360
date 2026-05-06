# Cam360

Cam360 是一个 iOS 行车记录仪 App。

Cam360 采用文档优先的开发方式：当前状态、已实现能力、下一步计划、架构边界、UI 流程与组件关系默认以仓库文档为准；AI 接手时先读文档，再读代码。

## 文档入口

默认从本文件开始，其他文档按职责读取：

| 文件 | 用途 |
| --- | --- |
| `docs/PROJECT_CONTEXT.md` | 长期有效事实、技术基线、目录边界 |
| `docs/TASKS.md` | 当前任务、下一步、待决事项 |
| `docs/CHANGELOG.md` | 实际改动历史 |

补充文档按需读取：

- [docs/specs/README.md](docs/specs/README.md)：能力规格索引，按需进入具体规格

## 自动化

- `.github/workflows/ci.yml`：push / PR 时执行 Simulator build/test。
- `.github/workflows/refactor-agent.yml`：手动或定时扫描 Swift 架构债；配置在 `.github/refactor-agent.json`，脚本为 `scripts/refactor_agent.py`，产物写入被忽略的 `build/refactor-agent/`。
