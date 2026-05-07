# UI 页面缺口清单

更新时间：2026-05-07

依据：仓库 `UI/` 截图、`docs/specs/ui-flow/README.md`、`docs/specs/ui-components/README.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP_UI页面清单.md`、`/Users/naxclow/camera-360-secives/行车记录仪APP产品需求文档(PRD).md`。本清单只记录离线可确认的 UI 缺口，不把外部资料当作已验证设备行为。

| 页面 | 证据来源 | 可达性 | 状态核对 | 处理 |
| --- | --- | --- | --- | --- |
| 启动页 | 外部 UI 清单 1.1；`LaunchScreen.storyboard` | 系统启动资源 | 仅 LaunchScreen | 暂不改 |
| 设备发现 / 连接 / 结果 | `UI/添加设备.png`；外部 UI 清单 1.2-1.4 | Dashboard Add Device 可达 | 搜索、连接、成功、失败由 onboarding 承载；已区分 AP 热点、控制通道校验和失败恢复动作 | 暂不接真实热点 |
| Dashboard | `UI/首页.png`、`UI/录制/Main.png`；外部 UI 清单 2.1 | 主 tab 可达 | 已有空态、连接态、抽屉、首次引导 | 已拆出首启功能引导 View |
| Gallery / 视频列表 | `UI/相册.png`；外部 UI 清单 4.1 | 主 tab 可达 | 已有空态、筛选、搜索、选择态、操作面板 | 暂不改 |
| Events | `UI/录制/Main.png` Recent Events；外部 UI 清单 4.1 事件筛选 | 未接主路由 | 原页面只有标题，缺空态和占位说明 | 已补事件类型、占位说明、空态 |
| DeviceList | `UI/首页.png` 设备抽屉；外部 UI 清单 1.2 | 未接主路由 | 只展示本地 known devices，缺独立页面 chrome 和入口说明 | 已补 TopBar、主流程未接入说明、空态文案 |
| LivePreview | `UI/录制/Main.png`；外部 UI 清单 3.1 | 未接主路由 | 无真实流，原页面只有错误态 | 已补预览占位、禁用控制区、错误态 |
| Playback | 外部 UI 清单 4.2；当前 `PlaybackStore` 状态 | 未接主路由 | Store 有加载/错误/资源态，原 View 未区分渲染 | 已补加载、错误、空态和资源摘要 |
| Downloads | 外部 UI 清单 4.3-4.4；PRD 离线功能 | 未接主路由 | 原空队列误用加载态 | 已改为空态，补队列和保存位置占位 |
| Settings | `UI/设置/设置页.png`；外部 UI 清单 5.x、8.x；PRD 3.1.4、3.2.3 | 主 tab 可达 | 已有设置二级页；FAQ/Contact 有入口证据；Privacy/Terms 只有截图入口，没有正文来源 | 本轮补 FAQ/Contact 子页面；Privacy/Terms 继续标记占位 |

## 入口结论

- `DeviceListView`、`LivePreviewView`、`PlaybackView`、`DownloadsView`、`EventsView` 本轮继续标记为未接主路由。
- 首页最近事件的 `View all` 继续进入 `GalleryView`，不新增 `EventsView` 路由。
- 实时预览、回放播放器和下载管理只补 UI 占位，不接真实设备、播放器或下载任务控制权。
