---
depends_on: [device-session, device-protocol]
hardware_required: true
---

# 实时预览规格

本文件只记录实时预览最小可用链路的边界。

## 当前已接入

- `LivePreviewView` 和 `LivePreviewStore` 提供不可用占位、重试检查反馈、控制区状态和错误态。
- `LivePreviewView` 可从录像页（`RecordingView`）的预览卡或拍照按钮进入，关闭后回到录像页本地路由。
- `DeviceSession` 已有 `VIDEO_CTRL` 录像状态/开关和 `SNAPSHOT_CTRL -> SNAPSHOT_DATA` 截图命令入口。
- 控制通道 ready 后，截图按钮只触发 `SNAPSHOT_CTRL -> SNAPSHOT_DATA`，保留 `image_base64` 并在本页预览可解码图片；不保存到本地相册。
- 自动化启动参数读取设备端模拟器 ready-file 时，会保留 `asset_host` / `asset_port` 与 `asset.preview.base_url` / 预览 URL，并在 LivePreview 中展示本地占位可用态；该状态只用于无真机前置联调，不代表真实预览流协议已确认。

## 当前范围外

- 真实视频流订阅
- 播放器控制和音频处理
- 截图保存、录制按钮的页面接线和本地资源保存
- 码流切换等扩展能力
- 沉浸式页面的真实导航流程

## 后续接入约束

- 真实预览状态优先来自 `DeviceSession` 和设备能力判断，不在 View 层拼接临时连接状态。
- 页面不直接持有底层连接或播放器控制权。
- 如果后续启用 `immersive` route，继续通过 Store 和 Route 协调，不把导航状态散落到 View 内部。
