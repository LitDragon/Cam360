---
depends_on: [device-protocol]
hardware_required: true
---

# DeviceSession 规格

本文件只记录 `DeviceSession` 真实接入边界。真实设备协议事实以 [`device-protocol`](../device-protocol/README.md) 为准。

## 当前已接入

- `DeviceSession` 可通过注入的控制通道 endpoint 建立 TCP 协议会话；真实 AP 连接成功仍由 onboarding 事件推进。
- 本地自动化可通过 `AppBootstrap` 的 `-device-protocol-ready-file` 启动参数读取设备端模拟器 ready-file 中的 `host` / `port`，并保留 `control_host` / `control_port`、`asset_host` / `asset_port` 与 `asset.preview.base_url` / 预览 URL 元数据；显式 `-device-protocol-host` / `-device-protocol-port` 仍优先作为控制通道 endpoint。该入口只服务模拟器兼容，不承担真设备 endpoint 自动发现，也不代表 App 直接驱动模拟器 control API 或真实预览流。
- 本地 strict 生命周期验证入口为 `python3 scripts/device_simulator_smoke.py`：脚本启动外部设备端模拟器默认 strict profile，等待 ready-file 后用模拟器 `client smoke` 验证 `APP_ACCESS`、`CTP_CMD_OPENAPP`、`UUID` 绑定、初始化 Topic、`STATE_SYNC(scope=home)`、`VIDEO_CTRL POST` 和 `CTP_CMD_EXITAPP` 的前置流程；该入口不启动 iOS App，也不证明真实设备链路。
- 握手链路已按外部 strict 模拟器生命周期编排 `APP_ACCESS`、`CTP_CMD_OPENAPP`、`PROTOCOL_VERSION`、`UUID`、`FW_VERSION`、`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`CAMERA_CAPABILITY`；`UUID.uuid` 或 `FW_VERSION.ver` 缺失/空白会中断握手；能力集返回更小 `protocol.max_control_frame_bytes` / `protocol.max_media_frame_bytes` 后，后续请求和接收按更小帧长上限处理，Boolean 帧长能力值会被忽略。
- `PROTOCOL_VERSION` 响应若声明 `min_supported_ver` 高于当前 App 版本，握手会在版本检查阶段失败，不继续拉取后续基础信息。
- ready 会话可发送 `STATE_SYNC`、`MEDIA_INDEX`、`RECENT_EVENTS`、聚合配置 GET/POST、文件列表、文件信息、回放资源、缩略图、录像状态/开关、截图、文件删除、文件加锁、热点信息、格式化和恢复出厂命令；`FILE_LIST`、`MEDIA_INDEX` 和 `RECENT_EVENTS` 查询会先归一化分页范围；文件信息、回放资源、缩略图、文件删除和文件加锁在发送前拒绝空白路径；缩略图、截图、文件加/解锁、热点信息读写、恢复出厂、自动关机、屏幕保护、12/24 小时制、录像设置、拍照设置、音频设置、图像设置、停车设置和实时 GPS 数据命令会按能力集声明门禁，命令结果带 ready 守卫和过期会话失效处理。
- `FORMAT_PROGRESS`、`UPGRADE_PROGRESS`、`DOWNLOAD_PROGRESS` 事件写入会话状态前会按正式字段约束过滤：非空任务 ID、`0...100` 进度、`topic` 对应 `type` 枚举、稳定状态枚举、升级阶段枚举和下载路径/速度；缓存按 `topic + task_id` 区分，避免不同进度 Topic 的同名任务互相覆盖。
- `HEARTBEAT` 已接入 `DeviceSession` 自动调度；仅在协议版本和能力门禁允许后启动，ACK 必须包含 Boolean `ack=true` 且以 Int 回显当前 `seq`，连续两次 ACK 缺失、错序号、错类型或超时会断开控制通道并进入连接丢失态。
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

- 真实 AP 连接、endpoint 自动发现和完整主动推送状态源
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
