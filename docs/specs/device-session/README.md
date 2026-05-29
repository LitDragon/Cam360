---
depends_on: [device-protocol]
hardware_required: true
---

# DeviceSession 规格

本文件只记录 `DeviceSession` 真实接入边界。真实设备协议事实以 [`device-protocol`](../device-protocol/README.md) 为准。

## 当前已接入

- `DeviceSession` 可通过注入的控制通道 endpoint 建立 TCP 协议会话；真实 AP 连接成功仍由 onboarding 事件推进。
- 握手链路已编排 `APP_ACCESS`、`PROTOCOL_VERSION`、`CTP_CMD_OPENAPP`、`UUID`、`FW_VERSION`、`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`CAMERA_CAPABILITY`。
- ready 会话可发送 `STATE_SYNC`、`MEDIA_INDEX`、`RECENT_EVENTS`、聚合配置 GET/POST、文件列表、文件信息、回放资源、缩略图、录像状态/开关、截图、文件删除、文件加锁、热点信息、格式化和恢复出厂命令；命令结果带 ready 守卫和过期会话失效处理。
- `HEARTBEAT` 已有命令模型，自动心跳调度仍未接入 `DeviceSession`。
- `ready` / `busy` 会话主动断开或重置时，先发送 `CTP_CMD_EXITAPP`，再关闭控制连接；握手未完成或失败态只关闭本地连接。
- 设备返回的已知 `errno` 按 `device-protocol` 错误码口径映射为可读失败原因；未知错误码保留原始 `errno` 和 Topic。

## 状态机

`DeviceSessionState` 枚举（`Core/Device/DeviceSessionState.swift`）：

```
idle → apConnecting → handshaking → ready(DeviceInfo) → busy(Operation, DeviceInfo)
                                        ↑                    ↓ operationCompleted
                                        └────────────────────┘

apConnectionFailed / handshakeFailed / operationFailed / connectionLost
  → failed(DeviceError)
failed(DeviceError) --startRecovery--> recovering(previousState or idle)
recovering(previousState) --recoverySucceeded--> previousState
recovering(previousState) --recoveryFailed--> failed(DeviceError)
failed(DeviceError) --disconnect--> disconnected
```

- `idle`：初始态，未发起连接。
- `apConnecting`：等待热点连接结果。
- `handshaking`：TCP 已通，正在执行握手命令序列。
- `ready(DeviceInfo)`：握手完成，可接受命令。
- `busy(Operation, DeviceInfo)`：正在执行操作（livePreview / playback / download / updateSettings）。
- `failed(DeviceError)`：连接、握手、操作或连接丢失失败态；可由 `startRecovery` 进入恢复。
- `recovering(previousState)`：失败后尝试恢复；恢复成功回到可恢复前态，没有可恢复前态时回到 `idle`。
- `disconnected`：用户主动断开。

`DeviceSessionEvent` 枚举（`Core/Device/DeviceSessionEvent.swift`）驱动状态转换：

| 事件 | 触发时机 |
| --- | --- |
| `startAPConnection(ssid)` | 用户确认热点信息，开始连接 |
| `apConnectionSucceeded` | 热点连接成功 |
| `apConnectionFailed(reason)` | 热点连接失败 |
| `startHandshake` | 开始 TCP 握手 |
| `handshakeSucceeded(DeviceInfo)` | 握手完成，拿到设备信息 |
| `handshakeFailed(reason)` | 握手失败 |
| `startOperation(Operation)` | 开始执行操作 |
| `operationCompleted` | 操作完成 |
| `operationFailed(DeviceError)` | 操作失败 |
| `connectionLost` | 连接意外断开 |
| `startRecovery` | 开始恢复 |
| `recoverySucceeded` | 恢复成功 |
| `recoveryFailed(DeviceError)` | 恢复失败 |
| `disconnect` | 用户主动断开 |
| `reset` | 重置回 idle |

## 当前范围外

- 真实 AP 连接、endpoint 自动发现、自动心跳调度和完整主动推送状态源
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
