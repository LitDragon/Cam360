---
depends_on: []
hardware_required: true
---

# 设备协议规格

本文件只沉淀 Cam360 iOS 后续接入真实设备时可直接使用的协议事实。原始资料中包含 Android 实现建议，本文件不继承 Android 技术栈和工程分层。

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
- `param` 必须显式存在且为 Object；`topic`、`msg_id`、`NOTIFY` 消息的 `notify_type` 和响应消息的 `reply_to` 不能为空白。
- 设备 `NOTIFY` 响应和事件必须携带 `errno`，并按 Int 解析；Boolean `errno` 视为协议帧解码失败，不按 `1/0` 兼容。
- 新实现发送时应使用标准 JSON 类型；`HEARTBEAT.seq` 只在正整数时发送，`client_time` 只发送有效 `yyyyMMddHHmmss`，`CTP_CMD_OPENAPP.page` 和 `CTP_CMD_EXITAPP.reason` 发送前会 trim，空白值按未提供处理。

## 握手流程

最小连接闭环：

1. APP 完成设备 AP 连接。
2. APP 建立 TCP 连接。
3. APP 发送 `APP_ACCESS`，`param.type` 使用 `1` 表示 iOS，`ver` 使用当前 App 版本，`protocol_ver` 使用当前客户端协议基线 `1.2`。
4. 设备响应 `APP_ACCESS`，可能返回 `heartbeat_interval` 和 `heartbeat_timeout`。
5. APP 发送 `CTP_CMD_OPENAPP`，告知设备前台会话已打开。
6. APP 发送 `PROTOCOL_VERSION` 检查协议版本；若 `min_supported_ver` 高于当前 App 版本，停止握手并进入失败态。
7. APP 按 `heartbeat_interval` 周期发送 `HEARTBEAT`；任一 APP 合法请求可刷新设备会话活跃时间，但设备事件和长任务进度不替代心跳 ACK。
8. 设备开始推送 `SD_STATUS`、`BAT_STATUS`、`VIDEO_CTRL` 等状态事件。
9. APP 拉取首页和设置页所需基础信息，例如 `UUID`、`FW_VERSION`、`TF_CAP`、`CAMERA_CAPABILITY`。

断开流程：

- 用户主动断开或 APP 退出设备会话时，优先发送 `CTP_CMD_EXITAPP(reason=user_leave)`，再关闭 TCP 连接。
- 用户主动断开不应触发自动重连。

## 超时与重连

- 默认单请求超时按 `10s` 处理。
- `HEARTBEAT` 为正式会话保活 Topic；默认间隔 `30s`、超时 `90s`，以 `APP_ACCESS` 返回值为准。
- 长任务期间仍需继续发送 `HEARTBEAT`；连续两次无 ACK 或超过 `heartbeat_timeout` 时，APP 应断开并进入重连策略。
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

`FILE_DELETE` 返回 `errno=-6` 时按锁定文件处理，提示“文件已加锁，无法删除”。

## P0 Topic

首批真实链路优先覆盖：

- 会话与设备信息：`APP_ACCESS`、`CTP_CMD_OPENAPP`、`CTP_CMD_EXITAPP`、`HEARTBEAT`、`PROTOCOL_VERSION`、`UUID`、`FW_VERSION`、`DEVICE_INFO`、`DATE_TIME`、`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`CAMERA_CAPABILITY`
- 聚合状态与索引：`STATE_SYNC`、`MEDIA_INDEX`、`RECENT_EVENTS`
- 录像与常用设置：`VIDEO_CTRL`、`RECORDING_CONFIG`、`SAFETY_CONFIG`、`STORAGE_POLICY_CONFIG`、`SYSTEM_PREFERENCES_CONFIG`、`WATERMARK_CONFIG`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`VIDEO_DATE`、`VIDEO_PARAM`、`VIDEO_INV`、`VIDEO_SYNC`、`VIDEO_RDER`、`PHOTO_RESO`、`PHOTO_QUALITY`、`PHOTO_DATE`、`MOVE_CHECK`、`GRA_SEN`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`VIDEO_PAR_CAR`、`VIDEO_PAR_VSIX`、`MIRROR_HOR`、`FLIP_VER`、`LIGHT_FRE`、`TV_MODE`、`SPEAKER_VOLUME`、`SPEECH`、`KEY_VOICE`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`ANTI_TREMOR`、`EDOG_VOICE`、`IR_SWITCH`、`AP_SSID_INFO`、`SYSTEM_DEFAULT`
- 文件与截图：`FILE_LIST`、`FILE_INFO`、`FILE_DELETE`、`FILE_DOWNLOAD_URL`、`THUMB_LIST`、`THUMB_GET`、`FILE_LOCK`、`SNAPSHOT_CTRL`、`SNAPSHOT_DATA`、`FORMAT`
- 主动推送：`SD_STATUS`、`BAT_STATUS`、`VIDEO_CTRL`、`FORMAT_PROGRESS`、`UPGRADE_PROGRESS`、`DOWNLOAD_PROGRESS`
- 已补低优先级模型：`VI_GPS_RTDATA`、`HOUR_TYPE`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`GRA_SEN`、`MOVE_CHECK`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`VIDEO_DATE`、`MIRROR_HOR`、`FLIP_VER`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`VIDEO_PARAM`、`PHOTO_RESO`、`PHOTO_QUALITY`、`PHOTO_DATE`、`TV_MODE`、`VIDEO_PAR_CAR`、`VIDEO_PAR_VSIX`、`VIDEO_INV`、`VIDEO_SYNC`、`VIDEO_RDER`、`LIGHT_FRE`、`SPEAKER_VOLUME`、`SPEECH`、`KEY_VOICE`、`ANTI_TREMOR`、`EDOG_VOICE`、`IR_SWITCH`

当前 iOS 接入状态：

- 已接入控制通道基础层：JSON 编解码、`\n` 分帧、通用包头 `param` 必填 Object、`topic` / `msg_id` / `notify_type` / 响应 `reply_to` 必填与非空校验、帧长上限、Boolean 帧长能力值忽略、半包 `5s` 超时断连、连续 `3` 次解析失败断连、`reply_to` 响应匹配、主动事件分流、请求超时和 Network.framework TCP transport。
- 已接入会话与只读/控制命令模型：握手基础 Topic、`HEARTBEAT`、`STATE_SYNC`、`MEDIA_INDEX`、`RECENT_EVENTS`、聚合配置 Topic、`DEVICE_INFO`、`VI_GPS_RTDATA`、`FILE_LIST`、`FILE_INFO`、`FILE_DOWNLOAD_URL`、`THUMB_LIST`、`THUMB_GET`、`VIDEO_CTRL`、`SNAPSHOT_CTRL`、`SNAPSHOT_DATA`、`DATE_TIME`、`HOUR_TYPE`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`GRA_SEN`、`MOVE_CHECK`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`VIDEO_DATE`、`MIRROR_HOR`、`FLIP_VER`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`VIDEO_PARAM`、`PHOTO_RESO`、`PHOTO_QUALITY`、`PHOTO_DATE`、`TV_MODE`、`VIDEO_PAR_CAR`、`VIDEO_PAR_VSIX`、`VIDEO_INV`、`VIDEO_SYNC`、`VIDEO_RDER`、`LIGHT_FRE`、`SPEAKER_VOLUME`、`SPEECH`、`KEY_VOICE`、`ANTI_TREMOR`、`EDOG_VOICE`、`IR_SWITCH`、`FILE_DELETE`、`FILE_LOCK`、`AP_SSID_INFO`、`FORMAT`、`SYSTEM_DEFAULT`、`UPGRADE_CHECK`、`UPGRADE_CTRL`。
- `DeviceSession` 已提供聚合读取、聚合配置 GET/POST 封装、`HEARTBEAT` 自动调度、`PROTOCOL_VERSION.min_supported_ver` 握手中断和低版本/能力集降级门禁，Base64 缩略图/截图、文件加/解锁、WiFi 参数、恢复出厂、自动关机、屏幕保护、12/24 小时制、录像设置、拍照设置、音频设置、图像设置、停车设置和实时 GPS 数据命令仅在能力集声明对应能力时发送。
- 握手返回目前派生设备 ID、固件版本和能力集；`DEVICE_INFO`、`VI_GPS_RTDATA`、`HOUR_TYPE`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`GRA_SEN`、`MOVE_CHECK`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`VIDEO_DATE`、`MIRROR_HOR`、`FLIP_VER`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`VIDEO_PARAM`、`PHOTO_RESO`、`PHOTO_QUALITY`、`PHOTO_DATE`、`TV_MODE`、`VIDEO_PAR_CAR`、`VIDEO_PAR_VSIX`、`VIDEO_INV`、`VIDEO_SYNC`、`VIDEO_RDER`、`LIGHT_FRE`、`SPEAKER_VOLUME`、`SPEECH`、`KEY_VOICE`、`ANTI_TREMOR`、`EDOG_VOICE` 和 `IR_SWITCH` 已提供离线命令封装；`DEVICE_INFO` 的基础信息字段和 `VI_GPS_RTDATA.info` 会按文档必填字符串处理，空白值视为缺失；`DeviceSession` 已将 `SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`VIDEO_CTRL` 和进度类主动事件沉淀为会话状态源；进度事件只接受非空 `task_id`、`topic` 对应 `type`、`progress=0...100` 和 `processing/completed/failed` 状态，并按 `topic + task_id` 保留不同类型任务，`UPGRADE_PROGRESS.stage` 限制为 `downloading/installing/restarting`，`DOWNLOAD_PROGRESS` 还要求非空 `path` 与非负 `speed`；SD/电量/容量查询响应和 `VIDEO_CTRL` 查询/控制成功响应也会同步状态；`RecordingStore` 已消费 `VIDEO_CTRL` 录制状态、`SD_STATUS` 存储异常态、`TF_CAP` 容量展示以及 `STATE_SYNC(scope=home).preview` / `storage_summary` 首页摘要，`DownloadsStore` 已按最新 `DOWNLOAD_PROGRESS` 事件消费传输进度和速度反馈，`SettingsStore` 已消费 `STATE_SYNC(scope=system_preferences)` 的固件更新入口、连接状态、本地化和维护入口字段，且消费 `FORMAT_PROGRESS` 格式化进度和 `UPGRADE_PROGRESS` 固件升级状态。
- 状态事件与查询响应共用字段边界：`SD_STATUS.online` 拒绝 Boolean 与负数，其他非负整数按未知异常码保留；`BAT_STATUS.level` 只接受 `0...4` 且拒绝 Boolean；`TF_CAP.left` / `total` 拒绝 Boolean 和负数，且剩余容量不得大于总容量；`VIDEO_CTRL.status` 按正式 `0/1` 数值标志解析并拒绝 Boolean / 非 `0/1` 值；`DATE_TIME.date` 发送前和响应解析时必须是有效 `yyyyMMddHHmmss` 时间串，`DATE_TIME.tz_offset_min` 拒绝 Boolean。
- 设置响应字段边界：`HOUR_TYPE.type`、`VIDEO_SIZE.val` 拒绝 Boolean 且必须落在返回分辨率列表范围内；`VIDEO_LOOP.cyc`、`VIDEO_EXP.exp`、`GRA_SEN.gra`、`MONITOR_MODE.mode`、`MONITOR_TIME.gaplen`、`VOLTAGE_PRO.vpr`、`VIDEO_PAR_VSIX.level`、`AUTO_SHUTDOWN.aff` 和 `SCREEN_PRO.pro` 拒绝 Boolean 并只接受已知枚举；`VIDEO_PARAM.w` / `h` / `format` 拒绝 Boolean，`format` 只接受已知编码枚举，`w/h` 只接受模拟器支持的分辨率映射；`VIDEO_MIC.mic`、`VIDEO_WDR.wdr`、`MOVE_CHECK.mot`、`VIDEO_DATE.dat`、`MIRROR_HOR.status`、`FLIP_VER.status`、`PHOTO_DATE.date`、`VIDEO_PAR_CAR.status`、`VIDEO_INV.status`、`VIDEO_SYNC.sync`、`VIDEO_RDER.status`、`SPEECH.speech`、`KEY_VOICE.voice`、`ANTI_TREMOR.status`、`EDOG_VOICE.status`、`IR_SWITCH.status` 和 `AP_SSID_INFO.status` 按正式 `0/1` 数值标志解析并拒绝 Boolean / 非 `0/1` 值；`SPEAKER_VOLUME.volume` 只接受 `0...10` 且拒绝 Boolean；`PHOTO_RESO.reso`、`PHOTO_QUALITY.quality`、`LIGHT_FRE.freq` 和 `TV_MODE.mode` 会按模拟器规则 trim，空白值按缺失处理。
- 尚未接入真实下载任务、本地资源保存、真实设备信息/GPS 读取、真实 12/24 小时制读写、真实旧录像/拍照/显示/语音/安全/停车/辅助设置读写、真实设备时间同步、固件包下载、签名校验或设备写入；危险命令仅有模型和离线测试，不从 UI 直接触发。

## 文件、缩略图与截图

- `THUMB_LIST` 使用 `paths[]` 请求，命令层发送前会限制单次不超过 20 个路径，并拒绝空数组或空白路径；解析层会拒绝非 `JPEG` 格式、Boolean 或非正数的 `width` / `height` / `size`、不可解码或空白 `image_base64`、单张超过 `64KB` 或批量总原始字节超过 `512KB` 的缩略图；联调模拟器同时限制总原始缩略图大小不超过 `512KB`。
- 视频列表页使用 `MEDIA_INDEX` 读取媒体索引；当列表项标记 `thumb_ready=1` / `has_thumbnail=true` 时，`GalleryStore` 按单批最多 `20` 个路径通过 `THUMB_LIST` 获取 Base64 缩略图并写回媒体卡，批量响应遗漏单项时再通过 `THUMB_GET` 补拉，`THUMB_LIST` 返回 `errno=-7` 且当前批次大于 1 时按更小 `paths` 降批重试。
- `FILE_LIST.type` 存在时只接受 `video/photo`；`FILE_LIST.files[].type` 存在时只接受 `normal/impact/motion/manual/parking/emergency/photo`；`FILE_LIST.files[].size` / `duration` 拒绝 Boolean 和负数；`locked` 按正式文档的 `0/1` 数值标志解析，拒绝 Boolean 和非 `0/1` 值；`has_thumbnail` 仍按 Boolean 解析。
- `FILE_DELETE.deleted`、`FILE_LOCK.status`、`FORMAT.frm` 和 `SYSTEM_DEFAULT.def` 按正式文档的 `0/1` 数值标志解析，拒绝 Boolean 和非 `0/1` 值。
- `FILE_INFO.path`、`FILE_DELETE.path`、`FILE_DOWNLOAD_URL.path` 和 `THUMB_GET.path` 发送前必须是非空白字符串；非法路径按 `errno=-2` 在本地拒绝，不发送控制帧。
- `FILE_DOWNLOAD_URL` 按“文件回放连接信息”处理，模型保留 `auth_type`、`username`、`password`、`max_sessions`、`seek_granularity_ms` 和 `keepalive_interval`；解析层会拒绝非 RTSP 地址、非 `TCP` transport、非 `none/basic/digest` 认证方式，以及 Boolean 或非正数的回放元数据；`PlaybackStore` 摘要只展示 `auth_type`、`max_sessions`、`seek_granularity_ms` 和 `keepalive_interval` 等非敏感字段，不展示 `username` / `password`，且这些字段仅作为后续播放器/RTSP 会话输入，不代表真实播放或下载任务已闭环。
- `SNAPSHOT_CTRL` 使用 `POST mode=preview` 触发截图，响应非空 `snapshot_id` 后再用 `SNAPSHOT_DATA` 获取截图资源；空白 `snapshot_id`、`SNAPSHOT_CTRL.status` 非 `ok/failed`、非 `JPEG/PNG` 格式、Boolean 或非正数的 `width` / `height` / `size`、不可解码或空白 `image_base64`、原始字节超过 `512KB` 均按无效响应处理。
- `THUMB_LIST` / `THUMB_GET` 需 `protocol.inline_media_base64=true`、`file.thumbnail=true` 且 `file.thumbnail_transport` 包含 `base64`；`SNAPSHOT_CTRL` / `SNAPSHOT_DATA` 需 `protocol.inline_media_base64=true` 且 `image.snapshot_transport` 包含 `base64`。
- `FILE_LOCK status=1` 需 `file.lock=true`；`status=0` 仅在 `file.unlock=true` 时允许发送，当前外部文档默认只支持加锁不支持解锁；空白 `file` 在发送前按参数错误拒绝。
- `VIDEO_CTRL` 使用 `GET` 查询录像状态，使用 `POST status=0/1` 停止或开始录像，成功后以设备响应或推送作为最终状态；响应 `status` 只接受 `0/1` 数值标志。
- `FILE_LIST.page`、`MEDIA_INDEX.page_no` 和对应 `page_size` 在发送前归一化到设备可接受范围，其中 `page` / `page_no` 不小于 `1`，`page_size` 为 `1...100`；`FILE_LIST.sort_by` 归一化为 `time/size`，`sort_order` 归一化为 `asc/desc`；`RECENT_EVENTS.limit` 归一化为 `1...20`。
- 普通控制帧按 `64 KiB` 上限处理；允许 Base64 媒体文本的扩展响应帧按 `768 KiB` 上限处理。`CAMERA_CAPABILITY.protocol` 声明更小 `max_control_frame_bytes` / `max_media_frame_bytes` 时，APP 按更小值收紧请求和接收上限。接收端缓存超过上限或半包超过 `5s` 未闭合时，应关闭连接。
- `STATE_SYNC(scope=initial)` 只承载首屏必要快照；媒体长列表和完整事件列表必须通过 `MEDIA_INDEX` 分页读取，首页最近摘要才使用 `RECENT_EVENTS`。
- `STATE_SYNC` 响应顶层保留 `schema_version`、`generated_at`、`cache_ttl_ms`、`truncated` 和 `omitted_sections`，用于结构版本、缓存和裁剪状态判断；`cache_ttl_ms` 只接受非负整数，`truncated` 只接受 Boolean 或 `0/1` 兼容值，`omitted_sections` 只接受字符串数组。
- `UPGRADE_CHECK` / `UPGRADE_CTRL` 的客户端升级模型在形成命令前必须校验 `latest_version` / `target_version` 非空白、`checksum` 为 `sha256:<64位hex>`、`package_size` / `rollback_index` 为正数、`signature` 为可解码且非空 Base64；`UPGRADE_CTRL.package_url` 还必须是带 host 的 HTTP(S) URL；响应中的 `current_version`、`latest_version`、`task_id` 和 `target_version` 不能为空白，`has_update`、`upgrade_allowed` 和 `accepted` 只按 `0/1` 解析，拒绝 Boolean，`UPGRADE_CTRL.status` 只接受 `queued/processing/failed`。签名真实性、反回滚和固件包写入仍以设备响应为准。
- 首页首屏预览入口状态和存储摘要优先复用 `STATE_SYNC(scope=home).preview` / `storage_summary`；`preview.stream_source_type` 只作为入口状态标签，不代表真实预览流、RTSP 地址、会话或保活规则已接入。
- 首页首屏最近事件优先复用 `STATE_SYNC(scope=home).recent_events`；缺少该字段或读取失败时再单独调用 `RECENT_EVENTS(limit=4)`，`RECENT_EVENTS.event_type` 发送前归一化为 `all` 或稳定事件枚举，`RECENT_EVENTS` 返回 `errno=-7` 时按更小 `limit` 重试。
- 事件列表页优先使用 `MEDIA_INDEX(event_only=1,page_size=20)` 渲染事件媒体索引；`RECENT_EVENTS` 不作为完整事件列表来源。
- 事件标题优先由客户端按 `title_key` 或已知 `event_type` 映射；当前覆盖 `normal`、`impact`、`motion`、`manual`、`parking`、`emergency` 和 `photo`，设备返回的 `title` 仅作为未知类型兜底。
- 媒体列表页应分别读取 `MEDIA_INDEX(media_type=video/photo)`；媒体卡片类型优先使用 `media_type`，`media_type=photo` 且 `event_type=photo` 的照片不应归入事件筛选。
- 设备设置主页初始化优先复用 `STATE_SYNC(scope=settings_home).device_info`；`categories` 仅控制已有明确映射的设置入口可用态，未映射字段不得伪造。
- 设备设置详情优先复用 `STATE_SYNC(scope=system_preferences)`；`software.firmware_version` 仅作为当前固件版本展示，`software.update_entry_enabled` 只控制固件更新入口可见性，不代表升级候选版本源已接入，`connectivity.status`、`localization.time_zone`、`localization.language`、`localization.date_time_auto_sync`、`audio.speaker_volume.options` 和 `audio.status_sounds` 用于系统偏好页展示和聚合提交。
- 录像设置页优先复用 `STATE_SYNC(scope=recording)`；`resolution.options`、`quality_priority.options` 和 `loop_recording.options` 控制页面可选项，`estimated_storage_per_hour_mb` 仅展示为设备估算，不参与聚合配置 POST。
- 安全设置页优先复用 `STATE_SYNC(scope=safety)`；`g_sensor_sensitivity.options` 和 `clip_duration_sec.options` 控制页面可选项；`reset_defaults=1` 作为一次性 POST 动作，成功后按设备返回的完整最终配置刷新页面。
- WiFi 设置页初始化优先复用 `STATE_SYNC(scope=wifi).ssid` / `status`；`status` 仅保留为协议状态值，不作为连接状态展示，保存 WiFi 名称或密码仍使用 `AP_SSID_INFO`。
- `AP_SSID_INFO GET` 需 `system.wifi_config=true`；`POST` 还需 `system.wifi_ssid_editable=true` 和 `system.wifi_pwd_editable=true`，发送前要求 `ssid` 非空且 UTF-8 长度不超过 `32` 字节、`pwd` 为 `8...63` 位可打印 ASCII，`status` 固定为 `1`，响应 `status` 只接受 `0/1` 数值标志；`SYSTEM_DEFAULT` 需 `system.factory_reset=true`。
- `AUTO_SHUTDOWN` 需 `system.auto_shutdown=true`；`SCREEN_PRO` 需 `system.screen_protect=true`；`HOUR_TYPE GET` 需 `system.hour_type` 非空，`POST` 需请求值包含在 `system.hour_type` 中。
- `VI_GPS_RTDATA` 需 `gps.supported=true` 且 `gps.realtime_data=true`；`VIDEO_SYNC` 需 `gps.supported=true` 且 `gps.video_overlay=true`。
- `VIDEO_SIZE GET` 需 `video.supported=true` 且 `video.resolutions` 非空，`POST` 需选中分辨率包含在 `video.resolutions` 中；`VIDEO_LOOP GET` 需 `video.loop_modes` 非空，`POST` 需请求值包含在 `video.loop_modes` 中。
- `VIDEO_DATE`、`VIDEO_PARAM`、`VIDEO_INV` 和 `VIDEO_RDER` 需 `video.supported=true`。
- `PHOTO_RESO GET` 需 `photo.supported=true` 且 `photo.resolutions` 非空，`POST` 需请求值包含在 `photo.resolutions` 中；`PHOTO_QUALITY GET` 需 `photo.qualities` 非空，`POST` 需请求值包含在 `photo.qualities` 中。
- `PHOTO_DATE` 需 `photo.supported=true`。
- `VIDEO_MIC` 需 `audio.mic_switchable=true`；`SPEAKER_VOLUME` 需 `audio.speaker_volume=true`；`SPEECH` 需 `audio.speech=true`；`KEY_VOICE` 需 `audio.key_voice=true`。
- `VIDEO_WDR` 需 `image.wdr=true`；`VIDEO_EXP` 需 `image.exposure_options` 非空；`MIRROR_HOR` 需 `image.mirror=true`；`FLIP_VER` 需 `image.flip=true`；`LIGHT_FRE` / `TV_MODE` 需请求值包含在 `image.light_frequency` / `image.tv_mode` 中；`ANTI_TREMOR` 需 `image.anti_tremor=true`；`IR_SWITCH` 需 `image.ir_switch=true`。
- `MOVE_CHECK` 需 `parking.supported=true`；`MONITOR_MODE` / `MONITOR_TIME` 需请求值包含在 `parking.modes` / `parking.monitor_time_options` 中；`VOLTAGE_PRO` 需请求索引在 `parking.voltage_protection` 范围内；`VIDEO_PAR_CAR` 需 `parking.guard_switch=true`；`GRA_SEN` / `VIDEO_PAR_VSIX` 需 `parking.collision_sensitivity` 非空并支持请求值。
- `Storage Policy` 消费 `sd.online` 时按 `SD_STATUS.online` 兼容无卡态；消费 `sd.error_code` / `sd.error_message` 时按本地错误码映射生成错误说明，不把设备诊断摘要作为唯一展示文案；消费 `tf.usage_percent` 时优先作为容量进度来源，且拒绝 Boolean 和 `0...100` 以外的值，非法 storage section 应触发对应配置 GET 回退；消费 `maintenance.estimated_remaining_recording_hours` 时应同时保留 `maintenance.estimate_profile` 作为剩余可录制时长估算口径；未返回 `estimate_profile` 时按当前画质兜底展示；`sd.policy_editable=0` 时必须禁用策略编辑控件，且 Store 不提交 `auto_cleanup`、`auto_overwrite`、`locked_event_retention` 或 `reserved_space_for_events_percent` 修改；`auto_cleanup.retention_days` 应随自动清理策略一起展示和提交，且提交前限制为 `7/15/30/60`；`reserved_space_for_events_percent` 提交前压到 `0...50`；`STORAGE_POLICY_CONFIG.auto_overwrite` 与 `RECORDING_CONFIG.auto_overwrite` 读取或提交成功后必须刷新为同一状态。
- 数据统计页优先复用 `STATE_SYNC(scope=statistics)` 的 `storage_counts`、`locked_counts` 和 `device_totals`；设备基础信息可再由 `DEVICE_INFO` 对齐。
- `RECENT_EVENTS.items[]` 与 `MEDIA_INDEX.groups[].items[]` 保留 `media_type`、`title_key`、`size` 和缩略图就绪态，并兼容正式字段 `start_time`、`duration_sec`、`thumb_ready`；`RECENT_EVENTS.event_id` / `path`、`MEDIA_INDEX.group_key` / `items[].path` 不能为空白；`media_type` 存在时只接受 `video/photo`，`RECENT_EVENTS.limit` 只接受 `1...20`，`total_recent_count` 只接受非负整数，正式数值字段 `duration_sec`、`size`、`locked` 和 `thumb_ready` 会拒绝 Boolean，时长与大小还必须非负，标志位只接受 `0/1`。

## 聚合配置

- `RECORDING_CONFIG`、`SAFETY_CONFIG`、`STORAGE_POLICY_CONFIG`、`SYSTEM_PREFERENCES_CONFIG`、`WATERMARK_CONFIG` 使用 GET 读取完整快照，POST 提交变化字段。
- `RECORDING_CONFIG`、`SAFETY_CONFIG`、`STORAGE_POLICY_CONFIG`、`SYSTEM_PREFERENCES_CONFIG` 空 POST 在 `DeviceSession` 发送前按参数错误拒绝，不发送控制帧；`WATERMARK_CONFIG` 保持部分字段提交语义。
- 聚合配置 POST 必须按事务处理：未知字段、类型错误、枚举不支持、只读字段或任一字段失败时整体回滚并返回错误；成功响应返回应用后的完整最终配置。
- `WATERMARK_CONFIG.plate_number` 提交前按模拟器规则 trim，并限制最多 8 个字符。
- `STATE_SYNC(scope=recording/storage/safety/system_preferences/watermark)` 应与对应配置 GET 返回结构保持一致；设置子页打开时优先消费对应 `STATE_SYNC` section，缺少有效 section 或读取失败时再回退对应配置 GET。

## 后续接入约束

- 协议 JSON、分帧、请求队列和 Topic 解析必须封装在 Core 侧，Feature 不直接拼接原始 JSON。
- `DeviceSession` 负责连接生命周期和状态流，Feature 只消费状态和能力。
- 设置类操作优先采用提交成功后再更新最终状态的悲观更新策略。
- HTTP 资源、预览流、播放器、本地保存和下载任务应作为独立能力接入，不混入 TCP 控制通道。
- 真实预览取流仍缺正式流地址、会话参数、鉴权、保活与重连规则；下载管理仍缺开始、暂停、继续、取消控制 Topic。在协议补齐前不实现真机运行路径。

## 原始资料来源

- `/Users/naxclow/camera-360-secives/carcam360设备通信协议文档.md`
- `/Users/naxclow/camera-360-secives/行车记录仪APP产品需求文档(PRD).md`
- `/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`
- `/Users/naxclow/camera-360-secives/src/camera360_device_simulator`
