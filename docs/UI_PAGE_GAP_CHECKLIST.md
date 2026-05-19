# UI 页面覆盖清单

更新时间：2026-05-19

依据：仓库 `UI/` 截图、`docs/specs/ui-flow/README.md`、`docs/specs/ui-components/README.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP产品需求文档(PRD).md`。本清单只记录离线可确认的 UI 覆盖状态，不把外部资料当作已验证设备行为。

## 已覆盖

- 主流程：Home、录像页（`RecordingView`）、Gallery、Settings、DeviceOnboarding。
- 设置：已覆盖设置首页、系统偏好、录像/安全/存储/水印/设备详情、通知、权限、FAQ、Contact Support；Privacy Policy、Terms of Service 和真实联系方式仍缺业务正文。
- 离线页面导航：离线页面已可从 Home、录像页（`RecordingView`）或 Gallery 进入，清单见 `docs/specs/ui-flow/README.md`。
- 离线状态：LivePreview 截图/录制/全屏保持禁用，Downloads 选择文件/暂停队列保持禁用，Events 保持空态或错误态，Playback 以 `Drive Log` 本地网格展示；DeviceList 已标记为未使用页面。

## 保持硬件队列

- 真实热点自动连接、真实预览流、播放器、下载任务、本地保存、事件推送和设置写操作不在无设备阶段继续接入。
- 不恢复独立 UI 冒烟测试 target，也不做模拟器逐页截图对比。
