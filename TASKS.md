# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 按单页设计图继续细化 `Settings`，优先 `Storage Policy`、`Safety`、`Device Settings`、`Watermark`、`Firmware Update`。
2. 收敛 `SystemPreferences` 和 `DeviceSettings` 的二级返回栈，避免当前全局 route 直接回根页。
3. 明确下一个真实能力切片，决定哪些页面继续保留本地占位，哪些开始接 `DeviceSession` 或真实能力。

## 下一步计划

1. 先按单页图修正 `Settings` 高歧义页面的文案、间距、状态和控件细节。
2. 再处理设置二级返回栈，确认子页面返回路径和 tab 可见性一致。
3. 最后只选一个真实能力切片继续推进，避免同时展开 onboarding、session 和预览链路。

## 最近完成

- `2026-04-25`：首页首次安装提示改成 3 页全屏引导 flow，展示期间隐藏底部 tab，成功进入首页时补本地占位设备。
- `2026-04-24`：`Settings` 扩成设备设置 M0 骨架，`Dashboard` 改成设备聚合页样式，两个 Store 补齐本地占位状态和 tab 闭环。
- `2026-04-23`：首页接入 `DeviceOnboarding` 5 步静态流程；相册页完成首版静态 UI 和 feature 内拆分；设置子页隐藏 tab，`Help Center` 可达。

## 待决事项

- 主界面最终目标到底是 3-tab 还是 4-tab。
- 是否需要恢复独立的 UI 冒烟测试 target。
- M1 第一优先级到底是 onboarding、session，还是预览链路。

## 更新规则

- 做完一轮改动后：
  - 把新的短期目标写回“当前任务”或“下一步计划”
  - “最近完成”只保留最近 3 条结果记录，不复述 `CHANGELOG`
  - 不记录编译、测试等直观验证信息
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
