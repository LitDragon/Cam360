# TASKS

本文件记录当前阶段状态、交接入口和硬件联调队列。

## 阶段状态

1. 外部业务/协议文档已新增协议 `1.2`、正式心跳、聚合状态/索引/配置 Topic；无设备期间可继续做协议模型、聚合消费和模拟器兼容层。
2. 已接入主流程 UI、onboarding/AP 连接边界、Home/录像页（`RecordingView`）/Gallery/已存设备列表离线页面导航、控制通道基础层、`DeviceSession` 命令级契约和聚合命令封装；不把外部资料当作已验证硬件行为。
3. 不恢复独立 UI 冒烟或截图测试 target；后续 UI/交互微调另行推进。

## 无设备期间

- 只处理外部文档已正式定义且不依赖真机响应的协议模型、Store 接入、模拟器兼容、离线回归、文档漂移和用户后续明确提出的 UI/交互微调。
- 控制帧/媒体扩展帧长度上限、通用包头 `param` 必填 Object、`topic` / `msg_id` / `notify_type` / 响应 `reply_to` 必填与非空校验、设备 `NOTIFY` 响应/事件 `errno` 必填与 Boolean 解码拒绝、按 `CAMERA_CAPABILITY.protocol` 声明的更小帧长收紧请求和接收、Boolean 帧长能力值忽略、半包 `5s` 未闭合关闭连接、连续 `3` 次解析失败断连、`HEARTBEAT` 自动调度与 ACK `ack` Boolean / `seq` Int 回显校验、`HEARTBEAT.seq` / `client_time`、`CTP_CMD_OPENAPP.page` 和 `CTP_CMD_EXITAPP.reason` 可选字段发送前归一化、`PROTOCOL_VERSION.min_supported_ver` 握手中断和低版本/能力集降级门禁已接入，含 Base64 缩略图/截图、文件加/解锁、WiFi 参数、恢复出厂、自动关机、屏幕保护、12/24 小时制、录像设置、拍照设置、音频设置、图像设置、停车设置和实时 GPS 数据能力声明检查。
- `AppBootstrap` 支持通过 `-device-protocol-ready-file` 读取设备端模拟器 ready-file 的 `host` / `port` 作为控制通道 endpoint，并保留 `control_host` / `control_port`、`asset_host` / `asset_port` 与 `asset.preview.base_url` / 预览 URL 作为本地自动化/Mock 预览元数据；`-device-protocol-host` / `-device-protocol-port` 仍可显式覆盖控制通道 endpoint。这只用于本地自动化/模拟器兼容，不代表真设备 endpoint 自动发现已完成。
- `scripts/device_simulator_smoke.py` 可启动 `/Users/naxclow/camera-360-secives` 的 `profiles/default-strict.json`，等待 ready-file 后按其中 `host` / `port` 跑模拟器 `client smoke`，用于离线验证 strict 生命周期、`uuid_read` 绑定和基础业务 Topic 前置顺序；该脚本不启动 iOS App，不代表真设备、真实 AP、真实预览流或下载链路已验证。
- `DeviceSession` 握手顺序已对齐外部 strict 模拟器生命周期：`APP_ACCESS` 会带 `type`、`ver` 和客户端协议基线 `protocol_ver=1.2`，随后立即发送 `CTP_CMD_OPENAPP`，再读取协议版本、设备身份、状态和能力集；`UUID.uuid` 或 `FW_VERSION.ver` 缺失/空白会中断握手，不再生成 `unknown-device` 设备 ID 或 `unknown` 固件版本的 ready 会话。
- `STATE_SYNC` 聚合快照已保留正式文档顶层元信息：`schema_version`、`generated_at`、`cache_ttl_ms`、`truncated` 和 `omitted_sections`；`cache_ttl_ms` 只接受非负整数，`truncated` 只接受 Boolean 或 `0/1` 兼容值，`omitted_sections` 只接受字符串数组，避免裁剪补拉依据被静默吞掉。
- `STATE_SYNC(scope=initial)` 已在控制通道 ready 后通过 `DeviceInitialStateCoordinator` 一次性分发给 `RecordingStore`、`SettingsStore` 和 `StatisticsStore`，用于首屏聚合快照消费；不替代后续页面独立刷新。
- `DEVICE_INFO`、`VI_GPS_RTDATA` 已按只读命令离线接入，且会拒绝空白基础信息字段和空白 GPS 原始字符串；`HOUR_TYPE`、`VIDEO_SIZE`、`VIDEO_LOOP`、`VIDEO_MIC`、`VIDEO_WDR`、`VIDEO_EXP`、`GRA_SEN`、`MOVE_CHECK`、`MONITOR_MODE`、`MONITOR_TIME`、`VOLTAGE_PRO`、`VIDEO_DATE`、`MIRROR_HOR`、`FLIP_VER`、`AUTO_SHUTDOWN`、`SCREEN_PRO`、`VIDEO_PARAM`、`PHOTO_RESO`、`PHOTO_QUALITY`、`PHOTO_DATE`、`TV_MODE`、`VIDEO_PAR_CAR`、`VIDEO_PAR_VSIX`、`VIDEO_INV`、`VIDEO_SYNC`、`VIDEO_RDER`、`LIGHT_FRE`、`SPEAKER_VOLUME`、`SPEECH`、`KEY_VOICE`、`ANTI_TREMOR`、`EDOG_VOICE`、`IR_SWITCH` 已按 GET/POST 设置命令离线接入；`SD_STATUS`、`BAT_STATUS`、`TF_CAP`、`VIDEO_CTRL` 和进度类主动事件已在 `DeviceSession` 沉淀为离线可测状态源；不符合正式字段范围、`type` 或枚举的 `FORMAT_PROGRESS`、`UPGRADE_PROGRESS`、`DOWNLOAD_PROGRESS` 会被忽略，合法进度按 `topic + task_id` 保留；SD/电量/容量查询响应和 `VIDEO_CTRL` 查询/控制成功响应也会同步状态；设备时间同步、固件升级检测/启动命令模型已按 `DATE_TIME`、`UPGRADE_CHECK`、`UPGRADE_CTRL` 离线接入；`RecordingStore` 已消费 `VIDEO_CTRL` 录制状态、`SD_STATUS` 存储异常态和 `TF_CAP` 容量展示，`DownloadsStore` 已按最新 `DOWNLOAD_PROGRESS` 事件消费传输进度、速度反馈和 `completed` 完成记录列表，下载页已补进度条、速度、暂停/继续/取消和完成项打开/删除的禁用态离线壳，`SettingsStore` 已消费 `FORMAT_PROGRESS` 格式化进度和 `UPGRADE_PROGRESS` 固件升级状态，且 `FORMAT` 成功后会刷新 `SD_STATUS`、`TF_CAP` 和 `FILE_LIST`，`FORMAT frm=0` 或命令失败会退出格式化中状态并展示失败入口。
- 状态事件与查询响应共用字段边界：`SD_STATUS.online` 拒绝 Boolean 与负数，其他非负整数按未知异常码保留；`BAT_STATUS.level` 只接受 `0...4` 且拒绝 Boolean；`TF_CAP.left` / `total` 拒绝 Boolean 和负数，且剩余容量不得大于总容量；`VIDEO_CTRL.status` 按正式 `0/1` 数值标志解析并拒绝 Boolean / 非 `0/1` 值；`DATE_TIME.date` 发送前和响应解析时必须是有效 `yyyyMMddHHmmss` 时间串，`DATE_TIME.tz_offset_min` 拒绝 Boolean。
- 设置响应字段边界：`HOUR_TYPE.type`、`VIDEO_SIZE.val` 拒绝 Boolean 且必须落在返回分辨率列表范围内；`VIDEO_LOOP.cyc`、`VIDEO_EXP.exp`、`GRA_SEN.gra`、`MONITOR_MODE.mode`、`MONITOR_TIME.gaplen`、`VOLTAGE_PRO.vpr`、`VIDEO_PAR_VSIX.level`、`AUTO_SHUTDOWN.aff` 和 `SCREEN_PRO.pro` 拒绝 Boolean 并只接受已知枚举；`VIDEO_PARAM.w` / `h` / `format` 拒绝 Boolean，`format` 只接受已知编码枚举，`w/h` 只接受模拟器支持的分辨率映射；`VIDEO_MIC.mic`、`VIDEO_WDR.wdr`、`MOVE_CHECK.mot`、`VIDEO_DATE.dat`、`MIRROR_HOR.status`、`FLIP_VER.status`、`PHOTO_DATE.date`、`VIDEO_PAR_CAR.status`、`VIDEO_INV.status`、`VIDEO_SYNC.sync`、`VIDEO_RDER.status`、`SPEECH.speech`、`KEY_VOICE.voice`、`ANTI_TREMOR.status`、`EDOG_VOICE.status`、`IR_SWITCH.status` 和 `AP_SSID_INFO.status` 按正式 `0/1` 数值标志解析并拒绝 Boolean / 非 `0/1` 值；`SPEAKER_VOLUME.volume` 只接受 `0...10` 且拒绝 Boolean；`PHOTO_RESO.reso`、`PHOTO_QUALITY.quality`、`LIGHT_FRE.freq` 和 `TV_MODE.mode` 会按模拟器规则 trim，空白值按缺失处理。
- `UPGRADE_CHECK` / `UPGRADE_CTRL` 的升级模型会在发送前拒绝空白目标版本、非 `sha256:<64位hex>` 格式的 `checksum`、非正 `package_size` / `rollback_index`、非法 Base64 `signature` 和不带 host 的非 HTTP(S) `package_url`，响应中的 `current_version`、`latest_version`、`task_id` 和 `target_version` 不能为空白，响应开关字段 `has_update`、`upgrade_allowed` 和 `accepted` 拒绝 Boolean，`UPGRADE_CTRL.status` 只接受 `queued/processing/failed`；签名真实性、反回滚和真实设备写入仍由设备或可信模拟器联调确认。
- `SettingsStore` 打开设备设置或系统偏好页时优先消费 `STATE_SYNC(scope=system_preferences)`，打开录像、存储、安全和水印设置页时优先消费对应 `STATE_SYNC` section，缺少有效 section 或读取失败时回退对应聚合配置 Topic；`Recording` 已消费 `resolution.options`、`quality_priority.options`、`loop_recording.options` 和只读 `estimated_storage_per_hour_mb` 控制可选项与每小时占用估算展示；`Safety` 已消费 `g_sensor_sensitivity.options`、`clip_duration_sec.options` 和 `reset_defaults=1` 控制安全设置可选项与重置为设备返回的最终配置；系统偏好已消费 `connectivity.status`、`software.firmware_version`、`software.update_entry_enabled`、`localization.time_zone`、`localization.language`、`localization.date_time_auto_sync`、`audio.speaker_volume.options`、`audio.status_sounds`、`device_identity.device_name_editable` 和 `maintenance.factory_reset_supported` 控制连接状态展示、固件版本、固件更新、时区、自动时间同步、音量选项、状态提示音、改名和恢复出厂入口显示/可用态，`Storage Policy` 已消费 `sd.online`、`sd.error_code` / `sd.error_message`、`tf.usage_percent`、`sd.policy_editable`、`sd.format_required`、`maintenance.format_supported`、`maintenance.estimated_remaining_recording_hours`、`maintenance.estimate_profile` 和 `auto_cleanup.retention_days` 控制无卡态、错误态本地文案、容量进度、策略项、格式化入口可用态、剩余可录制时长与自动清理保留天数文案，且 `tf.usage_percent` 拒绝 Boolean 和 `0...100` 以外的值，非法 storage section 会走聚合配置回退；提交前将 `auto_cleanup.retention_days` 限制为 `7/15/30/60`、将 `reserved_space_for_events_percent` 压到 `0...50`，并在 `sd.policy_editable=0` 时不提交策略项修改；`RECORDING_CONFIG`、`STORAGE_POLICY_CONFIG`、`SAFETY_CONFIG`、`SYSTEM_PREFERENCES_CONFIG` 空 POST 发送前会按 `errno=-2` 本地拒绝；`Recording` 与 `Storage Policy` 的 `auto_overwrite` 会在读取或提交成功后保持同值，`Watermark` 已保留并提交 `position` 水印位置，并在保存前 trim `plate_number` 且限制最多 8 个字符。
- `RECENT_EVENTS` / `MEDIA_INDEX` 聚合事件解析已兼容正式文档字段 `media_type`、`title_key`、`start_time`、`duration_sec`、`size` 和 `thumb_ready`，同时保留旧字段别名；`RECENT_EVENTS.event_id` / `path`、`MEDIA_INDEX.group_key` / `items[].path` 会按正式稳定标识拒绝空白值；`media_type` 存在时只接受 `video/photo`，`RECENT_EVENTS.limit` 只接受 `1...20`，`total_recent_count` 只接受非负整数，`duration_sec`、`size`、`locked` 和 `thumb_ready` 会按正式数值字段收口，拒绝 Boolean、负数时长/大小和非 `0/1` 标志位；`FILE_LIST.type` 存在时只接受 `video/photo`，`FILE_LIST.files[].type` 存在时只接受 `normal/impact/motion/manual/parking/emergency/photo`，`FILE_LIST.files[].size` / `duration` 同样拒绝 Boolean 和负数，`locked` 按正式 `0/1` 数值标志解析并拒绝 Boolean，`has_thumbnail` 保持 Boolean；事件标题优先按客户端 `title_key` / `event_type` 映射，并覆盖 `normal` / `photo` 等稳定枚举，设备 `title` 只作兜底；`FILE_LIST` / `MEDIA_INDEX` / `RECENT_EVENTS` 的分页参数会在发送前按正式协议范围归一化，`FILE_LIST.sort_by` / `sort_order` 会归一化到 `time/size` 与 `asc/desc`。
- `GalleryStore` 已按媒体列表页协议分别消费 `MEDIA_INDEX(media_type=video/photo)`，媒体卡类型优先使用 `media_type`，并在 `thumb_ready=1` 时按单批最多 `20` 个路径调用 `THUMB_LIST` 将 Base64 缩略图写回媒体卡；`THUMB_LIST` 命令层也会在发送前限制单次最多 `20` 个路径，并拒绝空数组或空白路径；解析层已拒绝非 `JPEG`、非法尺寸、不可解码 Base64、单张超过 `64KB` 或批量超过 `512KB` 的缩略图，批量响应遗漏单项时再用 `THUMB_GET` 补拉，`THUMB_LIST` 返回 `errno=-7` 且当前批次大于 1 时按更小 `paths` 降批重试；命令层已将 `FILE_DELETE errno=-6` 映射为锁定文件提示，`FILE_DELETE.deleted`、`FILE_LOCK.status`、`FORMAT.frm` 和 `SYSTEM_DEFAULT.def` 按正式 `0/1` 数值标志解析并拒绝 Boolean / 非 `0/1` 值；`FILE_INFO.path`、`FILE_DELETE.path`、`FILE_DOWNLOAD_URL.path`、`THUMB_GET.path` 和 `FILE_LOCK.file` 发送前会拒绝空白路径，真实文件下载、删除和加锁 UI 仍待联调边界确认。
- `RecordingStore` 首页首屏已消费 `STATE_SYNC(scope=home).preview` 和 `storage_summary` 更新预览入口状态与存储摘要，并优先复用 `recent_events`；聚合快照缺少最近事件或失败时再回退到 `RECENT_EVENTS(limit=4)`，`RECENT_EVENTS.event_type` 发送前归一化为 `all` 或稳定事件枚举，`errno=-7` 时按更小 `limit` 重试。
- `EventsStore` 已按事件型相册列表态消费 `MEDIA_INDEX(event_only=1)` 渲染事件列表，并按安全、停车、手动筛选实际事件项；事件列表已补缩略图占位、当前项高亮和禁用态更多操作入口；`RECENT_EVENTS` 继续只作为首页最近事件摘要使用。
- `Device Settings` 主页初始化已优先消费 `STATE_SYNC(scope=settings_home).device_info` 更新设备名和固件版本，并按 `categories` 中已映射的 `recording`、`safety`、`storage`、`watermark`、`system_preferences` 控制对应入口可用态。
- `Network Identity` 初始化已优先消费 `STATE_SYNC(scope=wifi).ssid` / `status`；`status` 仅保留为协议状态值，不作为连接状态展示，保存修改仍走 `AP_SSID_INFO`，成功后主动断开控制会话并引导重连，并按 `system.wifi_config` / `system.wifi_ssid_editable` / `system.wifi_pwd_editable` 门禁，发送前会拒绝空 SSID、超过 32 字节的 SSID、非 8...63 位或非可打印 ASCII 的密码。
- `Statistics` 数据统计页已接入设备设置路由，优先消费 `STATE_SYNC(scope=statistics)` 的 `storage_counts`、`locked_counts`、`device_totals`，设备基础信息由 `DEVICE_INFO` 对齐；真实统计响应仍待硬件或可信模拟器确认。
- `Firmware Update` 默认显示候选版本源未接入，不再通过本地按钮伪造升级启动、失败或重试；只保留 `UPGRADE_PROGRESS` 事件驱动的进度/完成/失败展示。
- `LivePreview` 截图按钮已按正式 `SNAPSHOT_CTRL -> SNAPSHOT_DATA` 命令链路保留 Base64 截图并在本页预览可解码图片，且对齐本地模拟器截图失败、数据超限、超时 fault、空白 `snapshot_id`、`SNAPSHOT_CTRL.status` 非 `ok/failed`、非法格式/尺寸、不可解码 Base64 和超过 `512KB` 的截图响应提示；本地相册保存、真实预览流、录制和全屏仍不接入。
- `Local Videos` 已按 APP 本地存储页接入下载页入口、离线空态、已确认保存记录的视频/截图索引、存储占用展示、已确认本地视频的系统分享入口和删除前确认后的索引移除；不伪造本地视频或截图记录，播放、真实文件删除、真实文件存在性和本地保存写入仍等待下载服务与本地资源链路。
- `DeviceList` 已接入 Home 设备抽屉的管理入口，只读取本地已保存设备并在出现时刷新；扫描、Wi-Fi 详情和真实连接结果仍由添加设备流程承载。
- `Help Center` 已按 UI 清单补齐新手引导、使用教程、FAQ 和 Contact Support 本地子页面；教程内容只覆盖当前离线可确认的入口与硬件保留边界。
- 真正首页已按 `UI/Home.png` 新建为 `HomeView`；当前 `RecordingView` 继续按设备录像页交接。
- 回放 `Drive Log` 页面按 `UI/回放.png` 完成离线展示，并展示 `PlaybackStore` 从 `FILE_LIST`、`FILE_INFO` 和 `FILE_DOWNLOAD_URL` 读取到的首个回放资源摘要；视频播放页离线壳已补播放器区域、进度条、信息卡片和禁用态播放/全屏/下载/分享/删除入口；`FILE_DOWNLOAD_URL` 模型已保留 RTSP 认证、并发、seek 精度和保活元数据，并拒绝非 RTSP 地址、非法认证方式和非法回放元数据，摘要仅展示 `auth_type`、`max_sessions`、`seek_granularity_ms` 和 `keepalive_interval` 等非敏感字段；真实文件、时间轴、播放器、下载、分享和删除链路仍等硬件或可信模拟器联调。
- 不新增依赖真实设备响应或尚未定义正式协议的运行时代码路径。

## 硬件恢复后联调队列

- 真设备 `DeviceProtocolEndpoint` 自动发现规则需要硬件或固件侧确认。
- 截图、录像、设备基础信息读取、实时 GPS 读取、12/24 小时制读写、旧录像/拍照/显示/语音/安全/停车/辅助设置读写、设备时间同步、固件升级检测/启动和聚合配置命令模型已接入；本地资源保存、真实预览画面、真实设备信息/GPS 读取、真实 12/24 小时制读写、真实旧录像/拍照/显示/语音/安全/停车/辅助设置读写、真实时间同步和真实升级任务仍需真设备或可信设备端模拟器确认。
- 下载任务、本地视频保存/播放/真实文件删除、播放器、危险操作 UI 触发和主动推送 UI/真设备闭环仍需真设备或可信设备端模拟器确认。
- 实时预览取流与下载任务控制仍缺正式协议；补齐前不进入真机运行路径。
- recoverySucceeded 会重新进入 `handshaking` 并在存在协议客户端时自动重跑 `APP_ACCESS` 握手；真实重连退避和状态同步完整策略仍待硬件或可信模拟器联调。

## 资料缺口

- Settings 的 Privacy Policy、Terms of Service 和真实联系方式仍缺业务正文或真实联系方式；Privacy/Terms 已保留占位详情页，Contact Support 联系通道保持禁用占位。

## 更新规则

- 做完一轮改动后：
  - 把新的短期目标写回“阶段状态”或“无设备期间”
  - 不记录编译、测试等直观验证信息
  - 如果有用户新指令，优先覆盖旧计划
  - 文档内容保持精简，不重复复述长期事实
