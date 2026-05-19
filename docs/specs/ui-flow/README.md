---
depends_on: [ui-components]
hardware_required: false
---

# UI 流程规格

本文件记录当前已落地页面、路由归属和页面跳转关系。只写代码里可确认的长期关系；短期任务写 `../../TASKS.md`。

## 导航归属

- `AppRootView` 维护 onboarding 是否展示；主流程显示 `MainTabView`。
- 主 tab 由 `MainTabView` 本地状态维护当前展示页：
  - `home` -> `HomeView`
  - `gallery` -> `GalleryView`
  - `settings` -> `SettingsView(root: .more)`
- Home、录像页（`RecordingView`）和 Gallery 的跨页面跳转由各自的 `NavigationView` + `NavigationLink` 承载；跳转页展示时隐藏自定义底部 tab。
- 设备设置页由录像页（`RecordingView`）的 `NavigationLink` 承载，root 为 `SettingsView(root: .deviceSettings, embedsNavigationView: false)`。
- 设备设置二级页由 `SettingsStore.route` 维护，复用外层 `NavigationView`。
- 页面内临时 UI 状态保留在页面或对应 Store 内，不升级为 App 根路由。

## 当前主流程

```mermaid
flowchart TD
    Root["AppRootView"]
    Root --> Onboarding["DeviceOnboardingView"]
    Root --> Main["MainTabView"]
    Main --> Home["HomeView"]
    Main --> Gallery["GalleryView"]
    Main --> Settings["SettingsView(root: .more)"]
    Home -->|Menu| Drawer["RecordingDrawerOverlay"]
    Home -->|Preview card| Recording["RecordingView (Recording)"]
    Home -->|View all events| Events["EventsView"]
    Recording -->|Add Device| Onboarding
    Recording -->|System back| Home
    Recording -->|Preview card / Photo| LivePreview["LivePreviewView"]
    Recording -->|Playback| Playback["PlaybackView"]
    Recording -->|Downloads| Downloads["DownloadsView"]
    Recording -->|View all events| Events["EventsView"]
    Recording -->|Open Full Gallery / View all| Gallery
    Recording -->|Settings icon| DeviceSettings["SettingsView(root: .deviceSettings)"]
    Gallery -->|Media item| Playback
    Gallery -->|Download action| Downloads
```

## Onboarding 流程

- `DeviceOnboardingStore.route` 当前状态：
  - `introduction`
  - `searching`
  - `wifiDetails`
  - `connecting`
  - `success`
- 正向流程：
  - `introduction` -> `searching` -> `wifiDetails` -> `connecting`
  - `connecting` 内由 `DeviceOnboardingStore.connectionStage` 区分热点连接、控制通道校验和失败重试提示
  - `connecting` 在 `DeviceSession` ready 后进入 `success`
  - `success` 的 `Go to Home` 关闭 onboarding，回到主 tab 容器
- 返回和取消：
  - `introduction` 或 `success` 关闭 onboarding，回到主 tab 容器
  - `searching`、`wifiDetails` 返回 `introduction`
  - `connecting` 返回或取消时 reset `DeviceSession`，回到 `wifiDetails`

## Home 流程

- `HomeView` 是当前第一 tab 的真正首页，按 `UI/Home.png` 实现离线展示。
- 顶部菜单展示设备抽屉 `RecordingDrawerOverlay`。
- 主预览卡进入录像页（`RecordingView`）。
- `Recent Events` 的 `View all` 进入 `EventsView`。
- 首页复用 `RecordingStore` 的设备名称、连接状态和首次功能引导状态；不直接持有 `DeviceSession`。

## 录像页（RecordingView）流程

- `RecordingView` 是设备录像页。
- 从 Home 进入时使用系统 `NavigationLink` 返回按钮回到 Home。
- `Add Device` 通过 `AppRootView` 的 onboarding 状态进入 onboarding。
- `Open Full Gallery` 切到 `main(.gallery)`。
- 预览卡、拍照按钮、回放、下载管理、最近事件 `View all` 通过录像页（`RecordingView`）的 `NavigationLink` 进入对应页面。
- 设置图标通过录像页（`RecordingView`）的 `NavigationLink` 进入 `SettingsView(root: .deviceSettings, embedsNavigationView: false)`。
- 录像页左上角不再承载设备抽屉入口。
- 首次功能引导 `RecordingFeatureSheet` 是 Recording Store 状态；展示时隐藏底部 tab。

## Gallery 流程

- `GalleryView` 当前没有 App 级全局路由。
- 搜索、筛选、选择模式、批量操作栏和媒体操作面板都由 `GalleryStore` 状态驱动。
- 媒体项点击通过 Gallery 的 `NavigationLink` 进入 `PlaybackView`；下载到本机进入 `DownloadsView`。

## Settings 流程

- 第三个 tab `settings` 显示 `SettingsView(root: .more)`，root 内容为标题 `More` 的 `SystemPreferencesView`，不显示返回按钮。
- 录像页设置图标进入 `SettingsView(root: .deviceSettings, embedsNavigationView: false)`，root 内容为 `SettingsOverviewView`，显示返回按钮并 pop 回录像页。
- `SettingsOverviewView` 可进入：
  - `recordingSettings` -> `RecordingSettingsView`
  - `safetySettings` -> `SafetySettingsView`
  - `storagePolicy` -> `StoragePolicyView`
  - `watermarkConfiguration` -> `WatermarkConfigurationView`
  - `deviceSettings` -> `DeviceSettingsDetailView`
  - `firmwareUpdate` -> `FirmwareUpdateView`
  - `systemPreferences` -> `SystemPreferencesView`
  - `renameDevice` -> `RenameDeviceView`
  - `helpCenter` -> `HelpCenterView`
  - `notificationSettings` -> `NotificationSettingsView`
  - `systemPermissions` -> `SystemPermissionsView`
- `SystemPreferencesView` 还有本地子路由：
  - `notificationSettings`
  - `systemPermissions`
  - `helpCenter`
- `HelpCenterView` 还有本地子路由：
  - `faq`
  - `contactSupport`
- `DeviceSettingsDetailView` 还有本地子路由：
  - `networkIdentity`
  - `firmwareUpdate`
  - `renameDevice`
- Home、录像页（`RecordingView`）/ Gallery 的 NavigationLink 目标页不显示底部 tab；录像页保留系统返回按钮；More tab 内的 `SystemPreferencesView` 本地子路由保留在主 tab 容器内。
- 返回通过 `SettingsStore.dismissRoute()`、本地 nested route 置空或 NavigationLink selection 置空完成。

## Home / 录像页（RecordingView）/ Gallery 导航目标

- `SettingsView(root: .deviceSettings)`
- `LivePreviewView`
- `PlaybackView`
- `DownloadsView`
- `EventsView`

这些页面已可从 Home、录像页（`RecordingView`）或 Gallery 进入，但仍保持离线状态；不得在其中创建播放器、下载服务或底层设备连接。

`DeviceListView` 当前标记为未使用页面，保留旧离线占位实现但不接导航入口。

## 维护规则

- 新增可达页面或导航目标时，同步更新本文件。
- 只有代码中存在实际跳转入口时，才写入“当前主流程”。
- 临时 sheet、drawer、search、selection 等局部状态只记录归属，不画成 App 路由。
