# DeviceSession 规格

本文件只记录 `DeviceSession` 真实接入边界。真实设备协议事实以 [`device-protocol`](../device-protocol/README.md) 为准。

## 当前已接入

- `DeviceSession` 可通过注入的控制通道 endpoint 建立 TCP 协议会话；真实 AP 连接成功仍由 onboarding 事件推进。
- 握手链路已编排 `APP_ACCESS`、`PROTOCOL_VERSION`、`CTP_CMD_OPENAPP`、`UUID`、`FW_VERSION`、`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`CAMERA_CAPABILITY`。
- ready 会话可发送文件列表、文件信息、回放资源、缩略图、录像状态/开关、截图、文件删除、文件加锁、热点信息、格式化和恢复出厂命令；命令结果带 ready 守卫和过期会话失效处理。
- `ready` / `busy` 会话主动断开或重置时，先发送 `CTP_CMD_EXITAPP`，再关闭控制连接；握手未完成或失败态只关闭本地连接。
- 设备返回的已知 `errno` 按 `device-protocol` 错误码口径映射为可读失败原因；未知错误码保留原始 `errno` 和 Topic。

## 当前范围外

- 真实 AP 连接、endpoint 自动发现、Dashboard/Settings 写操作和完整业务状态同步
- 真实预览流、播放器控制、下载任务、本地文件保存和截图保存
- 文件删除、文件加锁、格式化、恢复出厂设置等危险操作的 UI 触发和真机结果确认
- 自动重试与会话级超时调度
- 多设备并发会话
- 会话持久化和跨启动恢复

## 后续接入约束

- `DeviceSession` 应作为统一设备状态源，Feature 只消费状态，不各自维护连接生命周期。
- 真实握手、错误码、重连和 Topic 路由先按 `device-protocol` 收敛到会话层，再接具体 Feature。
- 新事件或新能力先补 `State`、`Event`、transition，再接底层实现。
- 失败、恢复、断开语义继续保持显式枚举，避免退回到松散字符串状态。
