# CHANGELOG

本文件记录仓库中已经实际发生的改动历史。旧记录基于当前 `git log` 做了首次整理，后续按日期持续追加。

## 2026-04-23

- 确定当前主界面继续保持 3-tab，不恢复独立 `events` 主入口。
- 将 `DeviceOnboarding` 从单页权限占位改为多步引导闭环：
  - 新增准备、热点连接、连接后校验、失败恢复、完成确认 5 个步骤
  - 在 UI 上显式区分“已连设备热点”和“已确认设备可控”
  - 为失败路径补充重试、回退热点步骤和清空本地状态入口
- 为 `DeviceOnboardingStore` 补充 happy path / failure path 测试覆盖。
- 同步更新 `PROJECT_CONTEXT.md`、`TASKS.md` 和设备接入规格，反映本轮落地结果和下一步优先级。
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
