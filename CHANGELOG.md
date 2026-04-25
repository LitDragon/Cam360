# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。按日期保留结果和边界，不展开过程细节或验证信息。

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

## 2026-04-22

- 建立根目录维护文档体系，明确 `README.md`、`PROJECT_CONTEXT.md`、`TASKS.md`、`CHANGELOG.md` 的职责边界。
- 清理 `.monkeycode/docs/` 中重复和过时的描述，重写 `settings-components` 规格，并统一“文档保持精简、避免重复维护”的规则。
- 固化当前代码事实：主界面当前为 3-tab、当前只有 `Cam360Tests`、`DeviceSession` 仅有骨架未接真实链路。

## 2026-04-21

- 完成设置页补全，扩展 Settings 设计系统组件。
- 新增通知设置页和系统权限页。
- 扩展 `SettingsStore` 与相关测试覆盖。

## 2026-04-20

- 继续推进设置页相关 UI。

## 2026-04-16

- 建立并整理 `.monkeycode` 文档体系，统一项目文档入口，并增加 GitHub Actions 的 iOS build/test workflow。
- 增加 `DeviceSession` 状态机、部分 Feature Store 测试、深色模式与设计系统颜色能力，同时清理不适用的 UI tests / snapshot testing 内容并收敛 tab 与占位 UI。
- 通过 SPM 引入 `Lottie`。

## 2026-04-15

- Initial commit。
