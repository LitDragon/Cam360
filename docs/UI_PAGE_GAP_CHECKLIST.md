# UI 页面覆盖清单

更新时间：2026-05-30

依据：仓库 `UI/` 截图、`docs/specs/ui-flow/README.md`、`docs/specs/ui-components/README.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP产品需求文档(PRD).md`。本清单只记录离线可确认的 UI 覆盖状态，不把外部资料当作已验证设备行为。

## 已覆盖

- 主流程：Home、录像页（`RecordingView`）、Gallery、Settings、DeviceOnboarding、DeviceList。
- 设置：已覆盖设置首页、系统偏好、录像/安全/存储/水印/设备详情、通知、权限、Help Center 新手引导/教程、FAQ、Contact Support、Privacy Policy 和 Terms of Service 占位页；法律正文和真实联系方式仍缺业务正文，Contact Support 联系通道保持禁用占位。
- 离线页面导航：离线页面已可从 Home、录像页（`RecordingView`）或 Gallery 进入，清单见 `docs/specs/ui-flow/README.md`。
- 离线状态：LivePreview 截图命令可在控制通道 ready 后触发，并预览可解码的 Base64 截图，截图保存/录制/全屏保持禁用；Downloads 选择文件/暂停/继续/取消和完成项打开/删除保持禁用，可展示 `DOWNLOAD_PROGRESS` 进度条、速度和 completed 完成记录，并可进入 Local Videos；Local Videos 读取 App 已确认保存的视频/截图索引、展示存储占用并支持删除前确认后移除索引，无索引时保持空态；Events 在控制通道 ready 后消费 `MEDIA_INDEX(event_only=1)`，事件项展示缩略图占位、当前项高亮和禁用态更多操作入口，无 session 时保持空态或不可用；Playback 以 `Drive Log` 本地网格展示并透出首个回放资源摘要，视频播放控制只保留禁用态离线壳；Firmware Update 显示候选版本源未接入且不伪造启动；DeviceList 从 Home 设备抽屉进入，只展示本地已保存设备。

## 保持硬件队列

- 真实热点自动连接、真实预览流、播放器、下载任务、本地保存/播放/分享/真实文件删除、事件推送、真实设备设置写入结果和错误码不在无设备阶段继续接入。
- 不恢复独立 UI 冒烟测试 target，也不做模拟器逐页截图对比。
