# DeviceSession 规格

本文件只记录当前状态机骨架和未来真实接入时的边界。真实设备协议事实以 [`device-protocol`](../device-protocol/README.md) 为准。

## 当前代码对齐结果

- `DeviceSession` 是 `ObservableObject`，当前对外发布 `state` 和 `currentOperation`。
- 当前状态枚举为 `idle`、`apConnecting`、`handshaking`、`ready`、`busy`、`recovering`、`failed`、`disconnected`。
- 当前事件枚举覆盖 AP 连接、握手、操作开始/结束、恢复、断开和重置。
- 当前操作枚举覆盖 `livePreview`、`playback(recordingId:)`、`download(recordingId:)`、`updateSettings`。
- 现有 transition 已定义 AP 连接成功/失败、握手成功/失败、操作完成/失败、恢复成功/失败、断开和重置语义。
- `DeviceSession` 可注入 `DeviceSessionProtocolClient`；`DeviceProtocolClient` 已适配该入口。
- `startProtocolHandshake()` 在 `handshaking` 状态下先建立控制通道，再执行 `DeviceProtocolHandshakePlan`；成功后从 `UUID`、`FW_VERSION`、`CAMERA_CAPABILITY` 响应派生 `DeviceInfo`。

## 当前范围外

- 真实 AP 连接、`AppContainer` 共享实例下发和 Feature 主路径消费
- 自动重试与会话级超时调度
- 多设备并发会话
- 会话持久化和跨启动恢复

## 后续接入约束

- `DeviceSession` 应作为统一设备状态源，Feature 只消费状态，不各自维护连接生命周期。
- 真实握手、错误码、重连和 Topic 路由先按 `device-protocol` 收敛到会话层，再接具体 Feature。
- 新事件或新能力先补 `State`、`Event`、transition，再接底层实现。
- 失败、恢复、断开语义继续保持显式枚举，避免退回到松散字符串状态。
