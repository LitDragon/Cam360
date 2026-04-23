# DeviceSession 规格

本文件只记录当前状态机骨架和未来真实接入时的边界。

## 当前代码对齐结果

- `DeviceSession` 是 `ObservableObject`，当前对外发布 `state` 和 `currentOperation`。
- 当前状态枚举为 `idle`、`apConnecting`、`handshaking`、`ready`、`busy`、`recovering`、`failed`、`disconnected`。
- 当前事件枚举覆盖 AP 连接、握手、操作开始/结束、恢复、断开和重置。
- 当前操作枚举覆盖 `livePreview`、`playback(recordingId:)`、`download(recordingId:)`、`updateSettings`。
- 现有 transition 已定义 AP 连接成功/失败、握手成功/失败、操作完成/失败、恢复成功/失败、断开和重置语义。

## 当前范围外

- 真实 AP、局域网或媒体传输实现
- 自动重试与超时调度
- 多设备并发会话
- 会话持久化和跨启动恢复

## 后续接入约束

- `DeviceSession` 应作为统一设备状态源，Feature 只消费状态，不各自维护连接生命周期。
- 新事件或新能力先补 `State`、`Event`、transition，再接底层实现。
- 失败、恢复、断开语义继续保持显式枚举，避免退回到松散字符串状态。
