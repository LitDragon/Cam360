# UI 页面缺口清单

更新时间：2026-05-06

依据：仓库 `UI/` 截图、`docs/specs/ui-flow/README.md`、`docs/specs/ui-components/README.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`。本清单只记录离线可确认的 UI 缺口，不把外部资料当作已验证设备行为。

| 页面 | 可达性 | 状态核对 | 本轮处理 |
| --- | --- | --- | --- |
| 启动页 | 系统启动资源 | 仅 LaunchScreen | 暂不改 |
| 设备发现 / 连接 / 结果 | Dashboard Add Device 可达 | 搜索、连接、成功、失败由 onboarding 承载 | 暂不改 |
| Dashboard | 主 tab 可达 | 已有空态、连接态、抽屉、首次引导 | 拆出首启功能引导 View |
| Gallery / 视频列表 | 主 tab 可达 | 已有空态、筛选、搜索、选择态、操作面板 | 暂不改 |
| Events | 未接主路由 | 原页面只有标题，缺空态和占位说明 | 补事件类型、占位说明、空态 |
| DeviceList | 未接主路由 | 只展示本地 known devices，缺独立页面 chrome 和入口说明 | 补 TopBar、主流程未接入说明、空态文案 |
| LivePreview | 未接主路由 | 无真实流，原页面只有错误态 | 补预览占位、禁用控制区、错误态 |
| Playback | 未接主路由 | Store 有加载/错误/资源态，原 View 未区分渲染 | 补加载、错误、空态和资源摘要 |
| Downloads | 未接主路由 | 原空队列误用加载态 | 改为空态，补队列和保存位置占位 |
| Settings | 主 tab 可达 | 已有设置二级页；隐私和条款仍是外部/占位入口 | 拆出固件升级 View |

## 入口结论

- `DeviceListView`、`LivePreviewView`、`PlaybackView`、`DownloadsView`、`EventsView` 本轮继续标记为未接主路由。
- 首页最近事件的 `View all` 继续进入 `GalleryView`，不新增 `EventsView` 路由。
- 实时预览、回放播放器和下载管理只补 UI 占位，不接真实设备、播放器或下载任务控制权。
