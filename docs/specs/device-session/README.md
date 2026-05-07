# DeviceSession 规格

本文件只记录 `DeviceSession` 真实接入边界。真实设备协议事实以 [`device-protocol`](../device-protocol/README.md) 为准。

## 当前范围外

- 真实 AP 连接、endpoint 自动发现、Dashboard/Settings 写操作和完整业务状态同步
- 自动重试与会话级超时调度
- 多设备并发会话
- 会话持久化和跨启动恢复

## 后续接入约束

- `DeviceSession` 应作为统一设备状态源，Feature 只消费状态，不各自维护连接生命周期。
- 真实握手、错误码、重连和 Topic 路由先按 `device-protocol` 收敛到会话层，再接具体 Feature。
- 新事件或新能力先补 `State`、`Event`、transition，再接底层实现。
- 失败、恢复、断开语义继续保持显式枚举，避免退回到松散字符串状态。
- `ready` / `busy` 会话主动断开或重置时，先发送 `CTP_CMD_EXITAPP`，再关闭控制连接；握手未完成或失败态只关闭本地连接。
