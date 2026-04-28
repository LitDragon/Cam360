# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 决定 `DeviceSession` 共享实例如何从 `AppContainer` 下发到接入、首页和设置页。
2. 将 `DeviceOnboarding` 的连接进度从本地自动推进切到真实握手结果，继续保持页面结构不变。
3. 握手接入稳定后，再把 Dashboard/Settings 的只读设备状态切到真实状态源。

## 下一步计划

1. 先在 `AppContainer` 明确 `DeviceSession` 与协议客户端工厂的组合边界。
2. 再让 `DeviceOnboardingStore` 的 connecting 阶段消费 `DeviceSession` 握手完成/失败态。
3. 最后再把 Dashboard/Settings 的只读状态改为订阅 `DeviceSession` 派生状态。

## 最近完成

- `2026-04-28`：补充接入真实握手前的测试护栏，覆盖 `DeviceOnboardingStore` 密码校验、取消连接后的旧完成回调忽略，以及 `DeviceSession` reset 后过期握手结果忽略。
- `2026-04-28`：`DeviceSession` 已接入 `DeviceProtocolClient` 握手编排，并补成功、设备 errno、请求超时和握手中断开测试。
- `2026-04-28`：新增 `Core/DeviceProtocol` 基础层和测试，覆盖 JSON 编解码、`\n` 分帧、`reply_to` 响应匹配、事件路由、iOS 握手命令顺序和 Network.framework transport。

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
