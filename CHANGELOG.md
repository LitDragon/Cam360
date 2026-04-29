# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。按日期保留结果和边界，不展开过程细节或验证信息。

## 2026-04-29

- `DeviceSession` 新增文件只读命令入口，封装 `FILE_LIST`、`FILE_INFO`、`FILE_DOWNLOAD_URL`、`THUMB_LIST`、`THUMB_GET`，并按 ready 会话守卫和过期会话失效处理；Gallery/Playback 开始通过共享会话读取设备文件、缩略图和回放资源。
- `DashboardStore` 和 `SettingsStore` 开始消费共享 `DeviceSession` 的只读派生状态；Dashboard 会按会话 ready/failed/disconnected 更新已知设备连接态，Settings 会读取握手返回的设备名、固件版本和能力集。
- 依据外部真实资料确认 endpoint 边界：联调模拟器当前采用手动热点和可达 IP / host-port 配置，真设备自动发现规则仍未确认，App 不写死固定 host。
- `AppContainer` 增加共享 `DeviceSession` 和 `DeviceProtocolEndpoint` 组合边界，控制通道 endpoint 可通过启动参数传入后创建真实 `NetworkDeviceProtocolTransport`。
- `DeviceOnboardingStore` 的连接阶段从本地定时假成功切到 `DeviceSession` 握手成功/失败态；成功后写入协议 `DeviceInfo` 派生设备，取消或失败不落库。
- 新增 GitHub `Refactor Agent` workflow、配置和标准库 Python CLI：按仓库文档扫描 Swift 架构债，受限生成小范围补丁，验证通过后自动创建重构 PR；当前默认仅允许 P1/P2 架构边界问题触发自动补丁。
- 同步 `DeviceProtocol` 与 `DeviceSession` 文档口径：控制协议握手已进入 `DeviceSession` 内部编排。
- 精简项目文档体系，删除过期 `.monkeycode/docs` 补充入口和架构文档，并移除协议、会话、接入和预览规格中的代码状态追踪。

## 2026-04-28

- 新增 `.monkeycode/specs/device-protocol/README.md`，从外部资料中收敛 iOS 可用的设备控制协议、握手流程、错误码、P0 Topic 和原始资料入口。
- 根 `README.md` 增加设备协议规格入口，`DeviceSession` 规格改为引用 `device-protocol` 作为真实协议事实源。
- 新增 `Core/DeviceProtocol` 基础层，包含协议值模型、消息模型、JSON 编解码、`\n` 分帧、请求响应匹配、事件路由、握手命令计划和 Network.framework transport。
- 新增 `DeviceProtocolTests`，覆盖兼容解析、半包/粘包、非法帧后续处理、`reply_to` 匹配、事件路由和 iOS 握手命令顺序。
- `DeviceSession` 新增协议客户端依赖入口和握手编排，成功后从协议响应生成 `DeviceInfo`，设备 errno、请求超时和握手中断开会回落到显式失败态；UI、`DeviceOnboarding`、Dashboard 和 Settings 仍未接入真实链路。
- 新增 `DeviceSessionProtocolTests`，覆盖握手成功、设备 errno、响应超时和握手中断开。
- 补充接入真实握手前的测试护栏，覆盖 `DeviceOnboardingStore` 密码校验、取消连接后的旧完成回调忽略，以及 `DeviceSession` reset 后过期握手结果忽略。

## 2026-04-27

- `Gallery` 状态从 View 本地 `@State` 收敛到 `GalleryStore`，并由 `AppContainer` 下发，避免切 tab 后删除、搜索和选择态被重置。
- `SettingsStore` 在刷新时补齐新增设备 seed，并在重命名时回写 `KnownDeviceRepository`，保证设置页、首页和设备抽屉读取同一设备名。
- `SystemPermissionsView` 的照片权限查询从 read/write 调整为 add-only 口径，继续匹配当前导出写入权限说明。

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
