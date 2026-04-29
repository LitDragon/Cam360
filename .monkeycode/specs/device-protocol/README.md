# 设备协议规格

本文件只沉淀 Cam360 iOS 后续接入真实设备时可直接使用的协议事实。原始资料中包含 Android 实现建议，本文件不继承 Android 技术栈和工程分层。

## 当前代码对齐结果

- `Core/DeviceProtocol` 已实现控制协议基础层，覆盖 JSON message/value、`\n` 分帧、请求响应匹配、事件路由、握手命令计划和 Network.framework transport。
- 当前 iOS 工程仍未实现真实 AP 连接、HTTP 资源下载或媒体预览链路。
- `DeviceProtocolClient` 已通过 `DeviceSession` 的可注入协议客户端入口进入握手编排；当前尚未由 `AppContainer` 组合下发，也未接入 `DeviceOnboarding` 或页面状态。
- `DeviceSession` 已有状态机骨架和控制协议握手编排，后续真实连接、恢复和失败语义仍应先收敛到 `DeviceSession`。
- `LivePreview`、`Playback`、`Downloads`、`Settings` 当前仍按 M0 占位或本地状态闭环，不直接持有底层连接。

## 控制通道

- 设备连接模型为手机连接设备 Wi-Fi AP 后，通过局域网访问设备。
- 控制通道使用 TCP，默认端口 `8765`。
- 控制消息为 UTF-8 JSON，单条消息以换行符 `\n` 结尾。
- 接收端必须按 `\n` 做流式分帧，缓存半包并逐帧解析；非法 JSON 只记录并丢弃当前帧，不阻塞后续帧。
- `param` 内如需文本换行，必须使用 JSON 转义，不能插入原始换行。

## 消息结构

请求消息由 APP 发往设备：

```json
{
  "topic": "UUID",
  "op": "GET",
  "msg_id": "app-0001",
  "param": {}
}
```

响应消息由设备发回 APP：

```json
{
  "topic": "UUID",
  "op": "NOTIFY",
  "notify_type": "response",
  "msg_id": "dev-0001",
  "reply_to": "app-0001",
  "errno": 0,
  "param": {
    "uuid": "112233445566778899"
  }
}
```

主动事件由设备推送：

```json
{
  "topic": "SD_STATUS",
  "op": "NOTIFY",
  "notify_type": "event",
  "msg_id": "evt-0001",
  "errno": 0,
  "param": {
    "online": 1
  }
}
```

字段约束：

- `topic`：命令主题，必须与协议 Topic 一致。
- `op`：`GET`、`POST`、`NOTIFY`。
- `msg_id`：当前消息唯一标识。
- `notify_type`：`response` 表示请求响应，`event` 表示设备主动事件。
- `reply_to`：响应消息必须指向原请求 `msg_id`。
- `errno`：设备消息必须携带，`0` 表示成功。
- `param`：参数或返回值；无内容时使用 `{}`。

## 兼容解析

- APP 不得仅凭 `op=NOTIFY` 判断语义，必须联合 `topic`、`notify_type`、`reply_to` 处理。
- 请求响应优先按 `reply_to` 匹配，不能只按到达顺序匹配。
- 主动事件不得结束请求生命周期，应独立路由到设备状态 Store 或 `DeviceSession`。
- 历史固件可能返回 `"0"`、`"1"` 这类数字字符串；iOS 解析层需要兼容字符串和数字两种形态。
- 新实现发送时应使用标准 JSON 类型。

## 握手流程

最小连接闭环：

1. APP 完成设备 AP 连接。
2. APP 建立 TCP 连接。
3. APP 发送 `APP_ACCESS`，`param.type` 使用 `1` 表示 iOS，`ver` 使用当前 App 版本。
4. 设备响应 `APP_ACCESS`，可能返回 `heartbeat_interval` 和 `heartbeat_timeout`。
5. APP 可发送 `PROTOCOL_VERSION` 检查协议版本。
6. APP 发送 `CTP_CMD_OPENAPP`，告知设备前台会话已打开。
7. 设备开始推送 `SD_STATUS`、`BAT_STATUS`、`VIDEO_CTRL` 等状态事件。
8. APP 拉取首页和设置页所需基础信息，例如 `UUID`、`FW_VERSION`、`TF_CAP`、`CAMERA_CAPABILITY`。

断开流程：

- 用户主动断开或 APP 退出设备会话时，优先发送 `CTP_CMD_EXITAPP`，再关闭 TCP 连接。
- 用户主动断开不应触发自动重连。

## 超时与重连

- 默认单请求超时按 `10s` 处理。
- 心跳参考值为间隔 `30s`、超时 `90s`。
- 协议未定义独立心跳命令时，优先用被动保活；若一段时间无任何响应或事件，可用只读 Topic 做主动探活。
- 重连退避可按 `1s -> 2s -> 4s -> 8s -> 16s -> 30s`，并限制最大间隔。
- Wi-Fi 已切走、版本不兼容、用户主动退出等场景不应无限重连。
- 重连成功后必须重新执行握手和状态同步。

## 错误码

| errno | 语义 | iOS 处理口径 |
| --- | --- | --- |
| `0` | 成功 | 正常更新状态 |
| `-1` | 未知错误 | 提示或允许重试 |
| `-2` | 参数错误 | 记录协议错误，检查请求构造 |
| `-3` | 操作失败 | 展示操作失败态 |
| `-4` | 设备忙 | 提示稍后重试 |
| `-5` | 不支持此功能 | 隐藏或禁用能力入口 |
| `-6` | 权限或资源受保护 | 提示资源受保护，例如文件已加锁 |
| `-7` | 资源不足 | 提示存储或资源不足 |

## P0 Topic

首批真实链路优先覆盖：

- 会话与设备信息：`APP_ACCESS`、`CTP_CMD_OPENAPP`、`CTP_CMD_EXITAPP`、`PROTOCOL_VERSION`、`UUID`、`FW_VERSION`、`DATE_TIME`、`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`CAMERA_CAPABILITY`
- 录像与常用设置：`VIDEO_CTRL`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`VIDEO_DATE`、`MOVE_CHECK`、`GRA_SEN`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`MIRROR_HOR`、`FLIP_VER`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`AP_SSID_INFO`、`SYSTEM_DEFAULT`
- 文件与截图：`FILE_LIST`、`FILE_INFO`、`FILE_DELETE`、`FILE_DOWNLOAD_URL`、`THUMB_LIST`、`THUMB_GET`、`FILE_LOCK`、`SNAPSHOT_CTRL`、`SNAPSHOT_DATA`、`FORMAT`
- 主动推送：`SD_STATUS`、`BAT_STATUS`、`VIDEO_CTRL`、`FORMAT_PROGRESS`、`UPGRADE_PROGRESS`、`DOWNLOAD_PROGRESS`

## 后续接入约束

- 协议 JSON、分帧、请求队列和 Topic 解析必须封装在 Core 侧，Feature 不直接拼接原始 JSON。
- `DeviceSession` 负责连接生命周期和状态流，Feature 只消费状态和能力。
- 设置类操作优先采用提交成功后再更新最终状态的悲观更新策略。
- HTTP 资源、预览流和下载任务应作为独立能力接入，不混入 TCP 控制通道。
- 真实预览协议仍需硬件确认；在确认前只保留抽象入口和占位链路。

## 原始资料来源

- `/Users/naxclow/camera-360-secives/carcam360设备通信协议文档.md`
- `/Users/naxclow/camera-360-secives/行车记录仪APP产品需求文档(PRD).md`
- `/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`
- `/Users/naxclow/camera-360-secives/src/camera360_device_simulator`
