# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 将 `Core/DeviceProtocol` 接入 `DeviceSession` 握手流程，继续保持 UI 结构不变。
2. 为握手成功、设备错误、超时和断开补 `DeviceSession` 级测试。
3. 握手稳定后，只把 Dashboard/Settings 的只读设备状态切到真实状态源。

## 下一步计划

1. 先新增 `DeviceSession` 的协议客户端依赖入口和握手 orchestration。
2. 再用 fake transport 覆盖正常握手、`errno` 失败、响应超时和断开。
3. 最后再决定 `DeviceOnboarding` 何时从本地自动推进切到真实握手结果。

## 最近完成

- `2026-04-28`：新增 `Core/DeviceProtocol` 基础层和测试，覆盖 JSON 编解码、`\n` 分帧、`reply_to` 响应匹配、事件路由、iOS 握手命令顺序和 Network.framework transport。
- `2026-04-28`：新增 `device-protocol` 规格，收敛外部资料中 iOS 可用的控制通道、握手、错误码、Topic 和模拟器参考入口。
- `2026-04-27`：修复代码审查发现的 4 个状态同步/权限口径问题：Gallery 状态迁入共享 Store，设置设备态刷新与重命名回写仓库，Photos 权限改为 add-only 口径。

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
