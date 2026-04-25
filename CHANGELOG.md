# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。按日期保留结果和边界，不展开过程细节或验证信息。

## 2026-04-25

- 首页首次安装提示从底部推荐 Sheet 改为 3 页全屏引导 flow，按品牌启动页、Wi‑Fi 连接说明、连接成功页顺序展示。
- 首次安装引导展示期间会隐藏底部 tab；跳过引导仍沿用 `hasCompletedOnboarding` 作为统一完成态。
- 引导成功页进入首页时会补当前本地占位设备，避免成功态返回后仍停留在空设备首页。

## 2026-04-24

- `Settings` 扩展为设备设置 M0 骨架，补齐首页、`Recording Settings`、`Storage Policy`、`Watermark Configuration`、`Safety`、`Device Settings`、`Rename Device`，并在 `Device Settings` 内加入 `Network Identity`、`Firmware Update` 本地流转。
- `SettingsStore` 补齐上述页面所需本地占位状态；当前仍未接 `DeviceSession`、真实固件检查、真实存储状态或系统权限读数。
- `Dashboard` 已连接设备态改为设备聚合页样式，加入预览卡、拍照/录制操作、存储摘要、完整相册入口和事件列表；入口继续落在现有 tab 闭环内。
- `DashboardStore` 补齐设备聚合页本地占位状态；当前仍为 UI / mock 闭环，未接 `DeviceSession`。

## 2026-04-23

- 首页完成首版静态 UI，包含有设备态、空设备态、侧边设备抽屉和首次启动推荐 Sheet；首次启动默认直接进入首页。
- 首页 `Add Device` 接入 `DeviceOnboarding` 的 5 步静态流程，成功后回写本地占位设备；搜索、Wi‑Fi 连接和连接进度仍是 UI 闭环，未接真实 AP onboarding 或 `DeviceSession`。
- 相册页完成首版静态 UI，并在 feature 内按职责拆分为视图、模型、页面框架、列表组件和操作面板。
- 主 tab 容器在设置二级及更深子页面时隐藏底部 tab，并移除对应底部占位。
- 设置页 `Help Center` 可达，并补齐对应路由和页面实现。
- 收敛根目录和 `.monkeycode/docs/` 文档入口，清理重复事实，补充 `MEMORY.md` 条目，并新增 `device-onboarding`、`device-session`、`live-preview` 三份规格。

## 2026-04-22 及更早

- 完成项目初始化，并逐步搭出当前 M0 早期骨架，包含设置页首版、占位 UI 和 `DeviceSession` 骨架。
- 建立根目录与 `.monkeycode` 文档体系，明确维护文档职责，并统一“文档保持精简”的规则。
