# TASKS

本文件记录当前任务、下一步计划和待决事项。每次 AI 完成一轮实际改动后，都应同步更新。

## 当前任务

1. 继续确认真设备 `DeviceProtocolEndpoint` 自动发现规则；当前只确认调试 host/port 和模拟器可达 IP 方案。
2. 再处理截图和录像控制：`SNAPSHOT_CTRL`、`SNAPSHOT_DATA`、`VIDEO_CTRL`。
3. 实时预览正式流协议未定义，等硬件补充协议后再接预览流。

## 下一步计划

1. 用设备模拟器或真设备确认文件 Topic 字段与缩略图体积口径。
2. 在 `DeviceSession` 下补截图/录像控制入口，Feature 仍不直接拼协议 JSON。
3. 预览流等硬件补充协议后再接。

## 完成记录

- `2026-04-29`：`DeviceSession` 已提供会话安全的文件只读命令入口；Gallery 会从 `FILE_LIST`/`THUMB_LIST` 读设备文件和缩略图，Playback 会从 `FILE_INFO`/`FILE_DOWNLOAD_URL` 读首个录像的回放资源。
- `2026-04-29`：Dashboard/Settings 已消费共享 `DeviceSession` 的只读设备状态；Settings 会读取握手设备名、固件和能力，Dashboard 会按 ready/failed/disconnected 派生已知设备连接态。
- `2026-04-29`：`AppContainer` 已组合共享 `DeviceSession` 和真实 TCP 协议客户端 factory；`DeviceOnboarding` 的 connecting 阶段已改为消费握手成功/失败态，成功后写入协议设备信息，未配置 endpoint 时不再假成功。

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
