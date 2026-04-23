# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 保持根目录 `README.md` 作为单一入口，长期事实只在 `PROJECT_CONTEXT.md` 维护。
2. 基于已落地的 onboarding 多步闭环，推进 `DeviceSession` 作为下一个真实能力切片。
3. 继续在当前 3-tab 结构下推进 `dashboard` 和 `LivePreview` 的最小可用承接。

## 下一步计划

1. 把 `DeviceSession` 注入 `AppContainer`，收敛 onboarding、dashboard、live preview 要消费的统一状态。
2. 在保持 3-tab 不变的前提下，让 `dashboard` 承接设备入口、连接摘要和后续预览入口。
3. 让 `LivePreview` 从占位文案过渡到最小 session 驱动状态，而不是继续堆独立临时状态。

## 最近完成

- `2026-04-23`：确定主界面继续保持 3-tab，不恢复独立 `events` 主入口。
- `2026-04-23`：将 `DeviceOnboarding` 从单页占位扩展为“准备 -> 热点连接 -> 连接后校验 -> 失败恢复 -> 完成确认”的多步闭环，并补充 happy path / failure path 测试。
- `2026-04-23`：收敛根目录和 `.monkeycode/docs/` 的入口职责，移除重复事实。
- `2026-04-23`：补充 `MEMORY.md` 实际条目，并新增 `device-onboarding`、`device-session`、`live-preview` 三份规格。
- `2026-04-22`：补齐根目录 AI 维护文档体系。
- `2026-04-22`：将当前已确认的代码事实、文档偏差和下一步计划固化到仓库根目录。
- `2026-04-22`：清理 `.monkeycode/docs/` 和 `.monkeycode/specs/` 中重复、过时的描述，并新增“文档必须精简”的统一标准。

## 待决事项

- 是否需要恢复独立的 UI 冒烟测试 target。
- `DeviceSession` 的最小对外接口先暴露哪些状态给 `dashboard` 和 `LivePreview`。
- `dashboard` 是否承接 `events` 摘要卡片，还是只保留设备与预览入口。

## 更新规则

- 做完一轮改动后：
  - 把已完成事项移到“最近完成”
  - 把新的短期目标写回“当前任务”或“下一步计划”
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
