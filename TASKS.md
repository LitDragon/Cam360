# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 明确真实设备或联调模拟器的 `DeviceProtocolEndpoint` 来源，避免写死未确认 host。
2. 将 Dashboard/Settings 的只读设备状态切到 `DeviceSession` 派生状态。
3. 再继续评估预览、回放和下载链路的真实协议入口。

## 下一步计划

1. 先确定 endpoint provider：设备网关、调试 host 参数或后续 AP 探测结果。
2. 再让 Dashboard 以 `DeviceSession.ready/failed/disconnected` 派生连接状态。
3. 最后让 Settings 读取会话设备信息和能力，暂不接写操作。

## 完成记录

- `2026-04-29`：`AppContainer` 已组合共享 `DeviceSession` 和真实 TCP 协议客户端 factory；`DeviceOnboarding` 的 connecting 阶段已改为消费握手成功/失败态，成功后写入协议设备信息，未配置 endpoint 时不再假成功。
- `2026-04-29`：新增 GitHub Refactor Agent workflow、配置和 Python CLI，支持按仓库文档扫描 Swift 架构债、受限生成小范围补丁、跑 CI 验证后创建 PR；P3 当前仅进报告。
- `2026-04-28`：`DeviceSession` 已接入 `DeviceProtocolClient` 握手编排，并补充 onboarding/session 最小测试护栏。

## 待决事项

- 是否需要恢复独立的 UI 冒烟测试 target。
- M1 第一优先级到底是 onboarding、session，还是预览链路。

## 更新规则

- 做完一轮改动后：
  - 把新的短期目标写回“当前任务”或“下一步计划”
  - “完成记录”只保留 3 条结果记录，不复述 `CHANGELOG`
  - 不记录编译、测试等直观验证信息
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
