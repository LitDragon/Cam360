# Cam360 AI 操作手册

本文件是 AI 进入仓库时的短入口，不重复维护长期事实。

## 1. 阅读顺序

1. 根目录 `README.md`
2. 根目录 `PROJECT_CONTEXT.md`
3. 根目录 `TASKS.md`
4. 根目录 `CHANGELOG.md` 最近一节
5. 本文件
6. [AGENTS.md](AGENTS.md)
7. 需要时再读 [Cam360技术架构文档.md](Cam360技术架构文档.md) 和规格文档

## 2. 文档标准

- 精简：默认短段落、短列表，只写当前必要信息。
- 去重：同一事实只保留一个主维护位置。
- 事实优先：代码事实和规划目标必须分开写。
- 冲突处理：文档和代码冲突时，以已检查代码为准。

## 3. 当前项目状态

- 当前阶段仍是 `M0 骨架`。
- 已落地：UIKit 生命周期桥接、SwiftUI 根视图、`AppBootstrap`、`AppRouter`、`AppContainer`、最小 DesignSystem、部分设置页、本地偏好存储。
- 当前主界面只有 3 个 tab：`dashboard`、`gallery`、`settings`。
- 当前测试 target 只有 `Cam360Tests`。
- 尚未落地真实链路：AP onboarding、真实 `DeviceSession`、实时预览、回放、下载导出、真实设备设置读写。

## 4. 工作约束

- 最低兼容：`iOS 13`
- 主路径实现：优先沿用 `iOS 15` 时代稳定写法
- `iOS 17+` 能力必须放在 `#available` 分支内
- Feature 不直接持有底层连接、播放器或下载任务控制权
- UI 优先用原生 SwiftUI 和最小设计系统，不扩张成重型组件库

## 5. 验证口径

- 默认做最窄的非模拟器验证。
- 不声明成功，除非实际完成了对应验证。
- CI 当前会跑基于 iOS Simulator 的 build/test，但本地文档默认不要求手动模拟器验证。

## 6. 何时更新文档

改动涉及以下内容时，需要同步文档：

- 目录结构或模块边界
- 启动分流、路由、主 tab 信息架构
- 存储策略
- 测试口径
- M0 / M1+ 阶段定义
- 设计系统的硬约束
