# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。旧记录基于当前 `git log` 做了首次整理，后续按日期持续追加。

## 2026-04-24

- 首页已连接设备态改为设备聚合页样式：
  - 新增预览卡、`Photo` / `Start Recording`、存储摘要 / 无 SD 卡态、`Open Full Gallery`、`Recent Events` 列表和空态
  - 页面仍落在 `Dashboard` 的 connected state，不新增根级 route 或独立 device detail 主入口
- 首页设备聚合页入口已接现有 tab：
  - `Open Full Gallery` 直接切到 `gallery`
  - 右上齿轮直接切到 `settings`
- `DashboardStore` 补充设备聚合页所需的本地占位状态：
  - 按设备切换录制态、存储态和事件列表
  - 保持当前仍为 UI / mock 闭环，未接 `DeviceSession`
- 新增 `DashboardStore` 对应测试，并通过一次 `xcodebuild test` 验证。

## 2026-04-23

- 首页完成首版静态 UI：
  - 支持有设备主态、空设备态、侧边设备抽屉和首次启动底部推荐 Sheet
  - 首次启动默认直接进入首页，不再走独立 onboarding 首屏
- 首页 `Add Device` 改为进入 `DeviceOnboarding` 的 M0 静态闭环：
  - 当前包含 `introduction -> searching -> wifiDetails -> connecting -> success` 五步
  - 成功页会写入 1 条本地占位设备并返回首页
  - 搜索、Wi‑Fi 连接和连接进度仍是 UI 状态闭环，未接真实 AP onboarding 或 `DeviceSession`
- 相册页完成首版静态 UI：
  - 支持顶部标题、搜索入口、筛选栏、按时间分组的媒体列表
  - 支持长按进入多选、底部批量操作栏、单项更多操作面板
  - 当前仍使用本地 mock 数据，`下载/分享` 仅为 UI 占位闭环
- 相册页完成 feature 内瘦身，按职责拆分为：
  - `Cam360/Features/Gallery/GalleryView.swift`
  - `Cam360/Features/Gallery/GalleryModels.swift`
  - `Cam360/Features/Gallery/GalleryChrome.swift`
  - `Cam360/Features/Gallery/GalleryListComponents.swift`
  - `Cam360/Features/Gallery/GalleryActionSheet.swift`
- 主 tab 容器在设置二级及更深子页面时隐藏底部 tab，并移除对应底部占位。
- 设置页 `Help Center` 已接成可达页面，新增 `helpCenter` 路由、页面实现和对应测试。
- 收敛文档入口职责：
  - `README.md` 只保留项目简介和文档索引
  - `.monkeycode/docs/README.md` 缩减为补充文档指引
- 清理 `PROJECT_CONTEXT.md`、`.monkeycode/docs/AGENTS.md`、`.monkeycode/docs/Cam360技术架构文档.md` 中重复的代码事实和规则描述。
- 补充 `.monkeycode/MEMORY.md` 的首批实际条目，记录用户长期偏好和验证口径。
- 新增以下核心规格文档：
  - `.monkeycode/specs/device-onboarding/README.md`
  - `.monkeycode/specs/device-session/README.md`
  - `.monkeycode/specs/live-preview/README.md`

## 2026-04-22

- 新增根目录维护文档：
  - `PROJECT_CONTEXT.md`
  - `TASKS.md`
  - `CHANGELOG.md`
- 重写 `README.md`，将其调整为项目简介和 AI 接手入口。
- 清理 `.monkeycode/docs/README.md`、`.monkeycode/docs/AGENTS.md`、`.monkeycode/docs/Cam360技术架构文档.md` 中重复和过时的描述。
- 重写 `.monkeycode/specs/settings-components/README.md`，将其从冗长的实现矩阵改为简洁的设计规格说明。
- 在根目录文档和 `.monkeycode` 文档中新增统一规则：未来文档默认必须精简，避免重复维护同一事实。
- 固化当前已确认的代码事实：
  - 主界面当前是 3-tab，不是 4-tab
  - 当前只有 `Cam360Tests`
  - `DeviceSession` 已有骨架，但未接真实设备链路
- 同步记录未来维护规则：长期事实写 `PROJECT_CONTEXT.md`，短期计划写 `TASKS.md`，实际改动写 `CHANGELOG.md`。

## 2026-04-21

- 完成设置页补全，扩展 Settings 设计系统组件。
- 新增通知设置页和系统权限页。
- 扩展 `SettingsStore` 与相关测试覆盖。

## 2026-04-20

- 继续推进设置页相关 UI。

## 2026-04-16

- 建立并整理 `.monkeycode` 文档体系，统一项目文档入口。
- 增加 GitHub Actions 的 iOS build/test workflow。
- 增加 `DeviceSession` 状态机和部分 Feature Store 单元测试。
- 清理不适用的 UI tests 和 snapshot testing 相关内容。
- 增加深色模式支持、颜色资产和设计系统颜色能力。
- 精简 tab 与占位 UI，逐步收敛到当前主界面结构。
- 通过 SPM 引入 `Lottie`。

## 2026-04-15

- Initial commit。
