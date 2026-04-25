# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 按单页设计图继续细化 `Settings`，优先 `Storage Policy`、`Safety`、`Device Settings`、`Watermark`、`Firmware Update`。
2. 保持根目录 `README.md` 作为单一入口，长期事实只在 `PROJECT_CONTEXT.md` 维护。
3. 继续按最小增量推进下一个真实能力切片。

## 下一步计划

1. 先按单页图修正 `Settings` 高歧义页面的文案、间距、状态和控件细节。
2. 再收敛 `SystemPreferences` 和 `DeviceSettings` 的二级返回栈，避免当前全局 route 直接回根页。
3. 最后再决定哪些设备设置继续保留本地占位，哪些开始接 `DeviceSession` 或真实能力。

## 最近完成

- `2026-04-24`：按总图扩展 `Settings` 为设备设置 M0 骨架，新增设置首页、`Recording / Storage / Watermark / Safety / Device Settings / Rename Device` 一级页面，以及 `Network Identity / Firmware Update` 的本地内嵌流转。
- `2026-04-24`：`SettingsStore` 新增设备设置本地占位状态和更新/恢复默认值动作，并为该状态流补充 1 条测试，通过一次 `xcodebuild test`。
- `2026-04-24`：首页已连接设备态已改成设备聚合页样式，包含预览卡、录制操作、存储摘要、无 SD 卡态、完整相册入口和事件列表 / 空态。
- `2026-04-24`：首页设备聚合页已接现有 tab 跳转，`Open Full Gallery` 切到 `gallery`，右上齿轮切到 `settings`。
- `2026-04-24`：为设备聚合页补充 `DashboardStore` 本地占位状态和对应测试，并通过一次 `xcodebuild test`。
- `2026-04-23`：首页 `Add Device` 已接入 `DeviceOnboarding` 的 5 步静态流程，成功页会回写本地占位设备并返回首页。
- `2026-04-23`：完成首页首版静态 UI，包含已添加设备态、侧边设备抽屉、无设备态和首次启动底部推荐 Sheet。
- `2026-04-23`：完成相册页首版静态 UI，包含筛选、搜索、多选和底部操作面板。
- `2026-04-23`：完成相册页 feature 内瘦身，拆分 `GalleryView`、模型、页面框架、列表组件和操作面板文件。
- `2026-04-23`：收敛根目录和 `.monkeycode/docs/` 的入口职责，移除重复事实。
- `2026-04-23`：补充 `MEMORY.md` 实际条目，并新增 `device-onboarding`、`device-session`、`live-preview` 三份规格。
- `2026-04-22`：补齐根目录 AI 维护文档体系。
- `2026-04-22`：将当前已确认的代码事实、文档偏差和下一步计划固化到仓库根目录。
- `2026-04-22`：清理 `.monkeycode/docs/` 和 `.monkeycode/specs/` 中重复、过时的描述，并新增“文档必须精简”的统一标准。

## 待决事项

- 主界面最终目标到底是 3-tab 还是 4-tab。
- 是否需要恢复独立的 UI 冒烟测试 target。
- M1 第一优先级到底是 onboarding、session，还是预览链路。

## 更新规则

- 做完一轮改动后：
  - 把已完成事项移到“最近完成”
  - 把新的短期目标写回“当前任务”或“下一步计划”
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
