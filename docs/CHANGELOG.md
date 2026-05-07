# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。按日期保留结果和边界，不展开过程细节或验证信息。

## 2026-05-07

- Onboarding 新增离线连接阶段表达，区分 AP 热点连接、控制通道校验、成功和可重试失败，并同步更新接入规格与测试护栏。
- GitHub agent 模型调用支持 repository variable `OPENAI_BASE_URL`，非官方 OpenAI-compatible 网关默认走 `chat_completions`，保留 `OPENAI_API_MODE` 覆盖。
- 将 GitHub 自动修复拆为 Build Fix、Technical Debt、Docs Alignment 三类 agent，分别使用独立 workflow/config，并复用受限 Python CLI 生成补丁、校验和创建 PR。

## 2026-05-06

- UI 页面缺口清单补充证据来源列；Help Center 新增 FAQ 和 Contact Support 本地子页面，保持 Privacy Policy、Terms of Service 为占位入口。
- 新增 UI 页面缺口清单；补强 Events、DeviceList、LivePreview、Playback、Downloads 的离线占位和空/错/加载展示，并保持未接主路由页面不接入真实设备链路。
- Dashboard 首启功能引导和 Settings 固件升级页面拆出独立 View 文件，保持原路由、Store 和交互语义不变。
- 补回 `ui-flow` 与 `ui-components` 两份精简规格，记录当前页面跳转、路由归属、公共组件清单和页面组件关系。
- DesignSystem 新增通用 surface 和进度条展示组件，扩展主按钮、空态和状态标签样式；Dashboard、Gallery、Onboarding、Settings 替换重复的纯展示实现，不改变 Store、路由或设备会话边界。

## 2026-04-30

- 将项目正文文档收敛到 `docs/`，补充 `docs/specs/README.md` 作为规格总索引，并让根 README 只保留文档入口。

## 2026-04-29

- `DeviceSession` 新增截图与录像控制入口，封装 `SNAPSHOT_CTRL`、`SNAPSHOT_DATA`、`VIDEO_CTRL`；协议规格补充联调模拟器的缩略图批量限制和截图/录像字段口径。
- `DeviceSession` 新增文件只读命令入口，封装 `FILE_LIST`、`FILE_INFO`、`FILE_DOWNLOAD_URL`、`THUMB_LIST`、`THUMB_GET`，并按 ready 会话守卫和过期会话失效处理；Gallery/Playback 开始通过共享会话读取设备文件、缩略图和回放资源。
- `DashboardStore` 和 `SettingsStore` 开始消费共享 `DeviceSession` 的只读派生状态；Dashboard 会按会话 ready/failed/disconnected 更新已知设备连接态，Settings 会读取握手返回的设备名、固件版本和能力集。
- 依据外部真实资料确认 endpoint 边界：联调模拟器当前采用手动热点和可达 IP / host-port 配置，真设备自动发现规则仍未确认，App 不写死固定 host。
- `AppContainer` 增加共享 `DeviceSession` 和 `DeviceProtocolEndpoint` 组合边界，控制通道 endpoint 可通过启动参数传入后创建真实 `NetworkDeviceProtocolTransport`。
- `DeviceOnboardingStore` 的连接阶段从本地定时假成功切到 `DeviceSession` 握手成功/失败态；成功后写入协议 `DeviceInfo` 派生设备，取消或失败不落库。
- 新增 GitHub `Refactor Agent` workflow、配置和标准库 Python CLI：按仓库文档扫描 Swift 架构债，受限生成小范围补丁，验证通过后自动创建重构 PR；当前默认仅允许 P1/P2 架构边界问题触发自动补丁。
- 同步 `DeviceProtocol` 与 `DeviceSession` 文档口径：控制协议握手已进入 `DeviceSession` 内部编排。
- 精简项目文档体系，删除过期 `.monkeycode/docs` 补充入口和架构文档，并移除协议、会话、接入和预览规格中的代码状态追踪。

## 2026-04-28 及更早

- 完成项目初始化和 M0 骨架，建立文档优先的维护方式，并逐步搭出 Dashboard、Gallery、Settings、DeviceOnboarding、Help Center 与首次安装引导等主要 UI 闭环。
- 收敛 Feature 状态归属：Gallery 状态进入 `GalleryStore`，Settings 通过 `KnownDeviceRepository` 维护设备名，首页、引导、设置二级页和 tab 显隐保持现有路由闭环。
- 新增设备控制协议与会话基础层：`Core/DeviceProtocol` 支持 JSON 编解码、`\n` 分帧、请求响应匹配、事件路由和握手命令计划；`DeviceSession` 开始编排真实握手并从协议响应生成 `DeviceInfo`。
- 补充协议、会话和 onboarding 的最小测试护栏，覆盖分帧解析、响应匹配、握手成功/失败、取消连接和过期结果忽略等接入真实设备前的关键边界。
