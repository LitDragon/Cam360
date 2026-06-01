---
depends_on: [device-session, ui-components]
hardware_required: true
---

# 设置组件规格

本文件记录设置相关已落地范围和维护规则，不再维护冗长的“页面 x 组件”实现矩阵。

## 已落地范围

- 已接入页面：
  - `SettingsView`
  - `SettingsOverviewView`
  - `StatisticsView`
  - `SystemPreferencesView`
  - `RecordingSettingsView`
  - `StoragePolicyView`
  - `WatermarkConfigurationView`
  - `SafetySettingsView`
  - `DeviceSettingsDetailView`
  - `RenameDeviceView`
  - `HelpCenterView`（内含 private `FAQView`、`ContactSupportView` 本地子页面）
  - `NotificationSettingsView`
  - `SystemPermissionsView`
- 已接入路由：
  - `systemPreferences`
  - `statistics`
  - `recordingSettings`
  - `storagePolicy`
  - `watermarkConfiguration`
  - `deviceSettings`
  - `safetySettings`
  - `renameDevice`
  - `helpCenter`
  - `notificationSettings`
  - `systemPermissions`
- `Privacy Policy`、`Terms of Service` 可从 `SystemPreferencesView` 进入占位详情页；真实 legal copy 未提供前只展示待提供状态，不补完整法律正文。
- `HelpCenterView` 内补齐新手引导、使用教程、FAQ 和 `Contact Support` 本地子页面；使用教程只说明当前已定义的离线路径和硬件保留边界，Contact Support 按 UI 清单保留电话、邮箱、在线客服、工作时间和 FAQ 快捷入口，真实联系方式未在业务资料中给出前，联系通道保持禁用占位，不触发拨号、邮件或外链。
- `SettingsStore` 已从 `DeviceSession` 只读消费设备身份、固件版本、能力集、`FORMAT_PROGRESS` 和 `UPGRADE_PROGRESS`；`Device Settings` 主页初始化优先消费 `STATE_SYNC(scope=settings_home)`，并按已映射 `categories` 控制设置入口可用态；设备设置详情优先消费 `STATE_SYNC(scope=system_preferences)` 的系统偏好字段，`Network Identity` 初始化优先消费 `STATE_SYNC(scope=wifi)`，保存仍走 `AP_SSID_INFO`。
- `StatisticsView` 从 `Device Settings` 主页进入，统计值优先消费 `STATE_SYNC(scope=statistics)`，设备基础信息由 `DEVICE_INFO` 对齐；真实设备统计响应仍待硬件或可信模拟器联调。

## 当前可复用组件

- `AppTopBar`
- `SettingsSectionHeader`
- `SettingsGroupCard`
- `SettingsNavigationRow`
- `SettingsToggleRow`
- `SettingsStatusRow`
- `SettingsActionRow`
- `SettingsSearchBar`
- `SettingsTimeField`
- `SettingsFootnote`
- `SettingsValueRow`
- `SettingsInputRow`
- `SettingsSegmentedRow`
- `SettingsMetricCard`
- `SettingsNoticeCard`
- `PrimaryButton`
- `DestructiveButton`
- `StatusTag`

## 仍属于设计参考、未在代码中接完整页面

- `Firmware Update` 的 `UPGRADE_CHECK`、`UPGRADE_CTRL` 命令模型和会话封装已离线接入，升级模型会拒绝空白目标版本、非法 `checksum`、非正 `package_size` / `rollback_index`、非法 Base64 `signature` 和不带 host 的非 HTTP(S) `package_url`，并拒绝空白响应版本 / 任务 ID 和 Boolean 形态的升级响应开关字段；页面默认停在“候选版本源未接入”状态，只消费 `UPGRADE_PROGRESS` 展示设备侧进度，不再用本地按钮伪造升级启动、失败或重试。
- `Device Settings` 主页打开时消费 `STATE_SYNC(scope=settings_home).device_info` 初始化设备名和固件版本，并使用 `categories` 中已映射的 `recording`、`safety`、`storage`、`watermark`、`system_preferences` 控制对应入口可用态；设备设置详情复用 `STATE_SYNC(scope=system_preferences).connectivity.status` 展示连接状态，并用 `software.update_entry_enabled` 控制是否展示检查更新入口。
- `Statistics` 数据统计页只消费正式文档已定义的聚合统计字段，不通过 `FILE_LIST` 或 `TF_CAP` 自行拼实时统计。
- `Recording`、`Storage Policy`、`Safety`、`System Preferences` 和 `Watermark` 页面打开时优先消费 `STATE_SYNC(scope=recording/storage/safety/system_preferences/watermark)`，缺少有效 section 或读取失败时再回退对应聚合配置 Topic；`Recording` 消费 `resolution.options`、`quality_priority.options`、`loop_recording.options` 和只读 `estimated_storage_per_hour_mb` 控制可选项与每小时占用估算展示；`Recording` 与 `Storage Policy` 的 `auto_overwrite` 读取或提交成功后保持同值；`Safety` 消费 `g_sensor_sensitivity.options`、`clip_duration_sec.options` 和 `reset_defaults=1` 控制安全设置可选项与重置最终状态；`System Preferences` 消费 `software.firmware_version`、`localization.time_zone`、`localization.language`、`localization.date_time_auto_sync`、`audio.speaker_volume.options`、`audio.status_sounds`、`device_identity.device_name_editable` 与 `maintenance.factory_reset_supported` 控制固件版本、时区、语言展示、自动时间同步、音量选项、状态提示音、改名和恢复出厂入口可用态；`RECORDING_CONFIG`、`STORAGE_POLICY_CONFIG`、`SAFETY_CONFIG`、`SYSTEM_PREFERENCES_CONFIG` 空 POST 会在会话层按参数错误拒绝，避免触发设备侧事务失败；`Watermark` 保留并提交 `WATERMARK_CONFIG.position`，并在保存前将 `plate_number` trim 后限制为最多 8 个字符；真实设备响应和设备写入仍待硬件或可信模拟器联调。
- `Network Identity` 打开时消费 `STATE_SYNC(scope=wifi).ssid` / `status` 初始化 WiFi 名称并保留协议状态值；保存前按文档限制 SSID 非空且不超过 32 字节、密码为 8...63 位可打印 ASCII，`AP_SSID_INFO` 成功后主动断开控制会话并引导重连；`status` 不作为连接状态展示，真实设备响应、重启生效和系统 WiFi 重连仍待硬件或可信模拟器联调。
- `Storage Policy` 的 no-card / ready / error 基线仍可本地切换；聚合响应中的 `sd.online`、`sd.error_code` / `sd.error_message`、`tf.usage_percent`、`sd.policy_editable`、`sd.format_required`、`maintenance.format_supported` 和 `auto_cleanup.retention_days` 会控制无卡态、错误态本地文案、容量进度、策略项、格式化入口可用态与自动清理保留天数文案，`sd.policy_editable=0` 时策略编辑控件保持禁用且 Store 不提交策略修改；提交前会将 `auto_cleanup.retention_days` 限制为 `7/15/30/60`，并将 `reserved_space_for_events_percent` 压到 `0...50`；`FORMAT_PROGRESS` 只负责离线可测的格式化进度/完成/失败状态消费，`FORMAT` 成功后会刷新 `SD_STATUS`、`TF_CAP` 和 `FILE_LIST`，但不代表真实格式化链路已联调。
- `New User Guide`、教程文章、`FAQ` 和 `Contact Support` 是 `HelpCenterView` 内的本地子页面，只补 UI 清单与 PRD 明确要求的离线支持内容；真实电话、邮箱和在线客服地址缺失时不接外部网页、电话或邮件动作。

## 维护规则

- 涉及设备写操作时采用悲观更新策略：提交成功后再更新最终状态；真实设备写入仍未联调。
- 只有在仓库里存在实际 `View` 或可达 `Route` 时，才能标记为“已落地”。
- 设计参考和代码现状必须分开写。
- 文档保持精简，不回到大表格罗列。
