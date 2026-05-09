# Cam360

Cam360 是一个 iOS 行车记录仪 App。

Cam360 采用文档优先的开发方式：阶段状态、已实现能力、硬件联调队列、架构边界、UI 流程与组件关系默认以仓库文档为准；AI 接手时先读文档，再读代码。

## 文档入口

默认从本文件开始，其他文档按职责读取：

| 文件 | 用途 |
| --- | --- |
| `docs/PROJECT_CONTEXT.md` | 长期有效事实、技术基线、目录边界 |
| `docs/TASKS.md` | 当前阶段状态、交接入口、硬件联调队列 |
| `docs/CHANGELOG.md` | 实际改动历史 |

补充文档按需读取：

- [docs/specs/README.md](docs/specs/README.md)：能力规格索引，按需进入具体规格

## 自动化

- `.github/workflows/ci.yml`：push / PR 时执行 Simulator build/test。
- `.github/workflows/build-fix-agent.yml`：CI push 失败后或手动运行语法/构建修复；配置在 `.github/build-fix-agent.json`，产物写入被忽略的 `build/build-fix-agent/`。
- `.github/workflows/refactor-agent.yml`：手动或定时扫描 Swift 技术债；配置在 `.github/refactor-agent.json`，产物写入被忽略的 `build/refactor-agent/`。
- `.github/workflows/docs-agent.yml`：push、手动或定时对齐文档与代码；配置在 `.github/docs-agent.json`，产物写入被忽略的 `build/docs-agent/`。
- 三类 agent 复用 `scripts/refactor_agent.py`，默认读取 repository secret `OPENAI_API_KEY` 和 repository variables `OPENAI_MODEL`、`OPENAI_BASE_URL`；`OPENAI_BASE_URL` 留空时使用 OpenAI 官方地址，非官方地址默认按 `chat_completions` 调用，可用 `OPENAI_API_MODE=responses` 覆盖。
