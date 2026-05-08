# 实时预览规格

本文件只记录实时预览最小可用链路的边界。

## 当前已接入

- `LivePreviewView` 和 `LivePreviewStore` 仅提供不可用占位、禁用控制区和错误态。
- `DeviceSession` 已有 `VIDEO_CTRL` 录像状态/开关和 `SNAPSHOT_CTRL -> SNAPSHOT_DATA` 截图命令入口。

## 当前范围外

- 真实视频流订阅
- 播放器控制和音频处理
- 截图、录制按钮的页面接线和本地资源保存
- 码流切换等扩展能力
- 沉浸式页面的真实导航流程

## 后续接入约束

- 真实预览状态优先来自 `DeviceSession` 和设备能力判断，不在 View 层拼接临时连接状态。
- 页面不直接持有底层连接或播放器控制权。
- 如果后续启用 `immersive` route，继续通过 Store 和 Route 协调，不把导航状态散落到 View 内部。
