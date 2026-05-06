# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 当前无真设备和硬件联调条件，暂停依赖端到端设备验证的接入任务。
2. 现阶段只基于现有 UI 和 `/Users/naxclow/camera-360-secives` 的连接、协议、UI 文档推进，不把外部资料当作已验证硬件行为。
3. 继续完善可离线确认的 UI、onboarding/AP 连接流程边界和 `DeviceSession` 契约；预览、下载、截图、录像的真实端到端行为等硬件恢复后再接。

## 下一步计划

1. 对照 `/Users/naxclow/camera-360-secives` 的 UI 页面清单、PRD 和连接资料，补齐高确信的页面状态、路由和空/失败态。
2. 收敛 onboarding/AP 连接文档到项目规格，明确无硬件阶段能实现的 Store/Session 状态和不能验证的边界。
3. 只为协议解析、状态转换和会话契约补离线测试；不新增依赖真实设备响应的运行时代码路径。
4. 将 `DeviceProtocolEndpoint` 自动发现、`SNAPSHOT_CTRL -> SNAPSHOT_DATA`、`VIDEO_CTRL`、预览流和下载链路保留为硬件恢复后的联调队列。

## 完成记录

- `2026-05-06`：补回 `ui-flow` 与 `ui-components` 精简规格，记录当前页面跳转、路由归属、公共组件清单和页面组件关系。
- `2026-05-06`：DesignSystem 收敛通用 surface、进度条、主按钮、空态和状态标签样式；Dashboard、Gallery、Onboarding、Settings 只替换纯展示重复实现。
- `2026-04-29`：`DeviceSession` 已提供会话安全的文件只读命令入口；Gallery 会从 `FILE_LIST`/`THUMB_LIST` 读设备文件和缩略图，Playback 会从 `FILE_INFO`/`FILE_DOWNLOAD_URL` 读首个录像的回放资源。

## 待决事项

- 是否需要恢复独立的 UI 冒烟测试 target。
- 真设备 `DeviceProtocolEndpoint` 自动发现规则需要硬件或固件侧确认。
- 截图、录像、预览流和下载链路的真实端到端行为需要真设备或可信设备端模拟器确认。

## 更新规则

- 做完一轮改动后：
  - 把新的短期目标写回“当前任务”或“下一步计划”
  - “完成记录”只保留 3 条结果记录，不复述 `CHANGELOG.md`
  - 不记录编译、测试等直观验证信息
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
