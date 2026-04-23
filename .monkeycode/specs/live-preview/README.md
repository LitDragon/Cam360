# 实时预览规格

本文件只记录当前占位实现和后续最小可用链路的边界。

## 当前代码对齐结果

- `LivePreviewView` 当前使用 `SectionCard` 和 `ErrorStateView` 展示占位内容，并暴露 `screen-livePreview` accessibility id。
- `LivePreviewStore` 目前只有占位标题和说明文案，没有真实流状态。
- `LivePreviewRoute` 当前只声明 `immersive`。
- 当前主界面仍是 3-tab，`LivePreview` Feature 已存在，但没有接入当前主导航。

## 当前范围外

- 真实视频流订阅
- 播放器控制和音频处理
- 截图、录制、码流切换等扩展能力
- 沉浸式页面的真实导航流程

## 后续接入约束

- 真实预览状态优先来自 `DeviceSession` 和设备能力判断，不在 View 层拼接临时连接状态。
- 页面不直接持有底层连接或播放器控制权。
- 如果后续启用 `immersive` route，继续通过 Store 和 Route 协调，不把导航状态散落到 View 内部。
