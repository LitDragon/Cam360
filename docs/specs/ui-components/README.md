# UI 组件规格

本文件记录当前 UI 组件分层和页面使用关系。组件细节以代码为准；这里只维护能帮助接手和重构的最小清单。

## 分层原则

- `Core/DesignSystem` 放跨页面复用的展示组件和 token。
- `Features/*` 内的组件默认只服务本 Feature；重复 2-3 次且行为稳定后再上移到 DesignSystem。
- Feature 组件不直接持有底层连接、播放器或下载任务；共享依赖从 `AppContainer` 组合后下发给 Store。
- 公共组件保持纯展示或轻交互，不承担业务路由。

## DesignSystem 组件

- Tokens：
  - `AppColor`
  - `AppTypography`
  - `AppSpacing`
  - `AppRadius`
  - `AppLayout`
  - `AppShadow`
  - `AppArtworkPalette`
- 容器和样式：
  - `appSurface(...)`
  - `SectionCard`
  - `QuickActionCard`
  - `PermissionPageView`
  - `MediaListItem`
- 导航和 chrome：
  - `AppTopBar`
  - `MainTabBar`
- 按钮和操作：
  - `PrimaryButton`
  - `DestructiveButton`
- 反馈和状态：
  - `EmptyStateView`
  - `ErrorStateView`
  - `InlineLoadingView`
  - `ActivityIndicatorView`
  - `StatusTag`
  - `AppProgressBar`
- 设置页组件族：
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

## 页面到组件关系

| 页面 | 主要公共组件 | 主要 Feature 私有组件 |
| --- | --- | --- |
| `DashboardView` | `PrimaryButton`, `StatusTag`, `AppProgressBar`, `appSurface` | `DashboardHeaderView`, `DashboardPreviewCard`, `DashboardCaptureControls`, `DashboardStorageCard`, `DashboardGalleryRow`, `DashboardEventRow`, `DashboardDrawerOverlay`, `DashboardFeatureSheet` |
| `GalleryView` | `EmptyStateView`, `StatusTag` | `GalleryHeaderView`, `GalleryFilterBar`, `GallerySearchBar`, `GallerySectionsList`, `GalleryMediaCard`, `GalleryThumbnail`, `GalleryBatchActionBar`, `GalleryActionSheet` |
| `DeviceOnboardingView` | `PrimaryButton`, `AppProgressBar`, `appSurface` | `DeviceOnboardingNavigationBar`, `DeviceOnboardingSignalIllustration`, `DeviceOnboardingTipCard`, `DeviceOnboardingReadonlyField`, `DeviceOnboardingPasswordField` |
| `SettingsView` / `SettingsOverviewView` | `AppTopBar`, `StatusTag`, Settings 组件族 | 无独立私有组件 |
| `SystemPreferencesView` | `AppTopBar`, Settings 组件族 | 本地 `SystemPreferencesRoute` |
| `DeviceSettingsDetailView` | `AppTopBar`, `PrimaryButton`, `DestructiveButton`, `AppProgressBar`, Settings 组件族 | `NetworkIdentityView`, `FirmwareUpdateView`, 本地 `DeviceSettingsDetailRoute` |
| 设置二级页 | `AppTopBar`, `PrimaryButton`, `DestructiveButton`, Settings 组件族 | 页面内 binding 和局部状态 |
| `DeviceListView` | `SectionCard`, `EmptyStateView` | `DeviceCell` |
| `LivePreviewView` | `SectionCard`, `ErrorStateView` | 无 |
| `PlaybackView` | `SectionCard`, `EmptyStateView` | 无 |
| `DownloadsView` | `SectionCard`, `InlineLoadingView` | 无 |
| `EventsView` | `AppTopBar` | 无 |

## 当前抽取边界

- 已适合继续复用：
  - surface 边框和阴影统一用 `appSurface(...)`
  - 线性进度展示统一用 `AppProgressBar`
  - 主操作按钮统一用 `PrimaryButton`
  - 状态徽标统一用 `StatusTag`
  - 空、错、加载态优先用 `EmptyStateView`、`ErrorStateView`、`InlineLoadingView`
- 暂不建议上移：
  - Dashboard 首屏插画、预览卡、设备抽屉和首次功能引导
  - Gallery 缩略图、媒体卡和操作面板
  - Onboarding 信号插画、密码输入和连接流程 UI
- 设置组件族已经在 `Core/DesignSystem/SettingsComponents.swift`，继续服务设置域；跨域复用前先确认命名和交互不被设置语义绑定。

## 维护规则

- 新增公共组件时，同步加入 `DesignSystem 组件`。
- 新页面接入主流程时，同步补 `页面到组件关系`。
- 删除或下沉组件时，先更新本文件再改代码，避免后续按过期关系抽象。
- 不维护每个属性、颜色和 padding 的大表；这些细节以 Swift 源码为准。
