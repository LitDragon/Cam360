# CHANGELOG

本文件只记录阶段级结果和边界，不维护逐条过程记录。

## 2026-05

- 真机前无设备阶段已收口：主流程 UI、Home/录像页（`RecordingView`）/Gallery 原生 `NavigationLink` 页面导航、More/设备设置分流、onboarding/AP 边界、控制通道基础层和 `DeviceSession` 命令级契约已接入；真实预览、播放器、下载、本地保存、设置写操作和推送消费保留到硬件联调。
- 删除 App 根级 `AppRouter`，Home、录像页和相册页改由各自的 `NavigationView` 承载跳转，push 目标展示时隐藏自定义 tab bar。
- 文档体系收敛为根 README、`PROJECT_CONTEXT`、`TASKS`、阶段级 `CHANGELOG` 和 `docs/specs/`；不恢复 UI 冒烟或截图测试 target。

## 2026-04

- 完成项目初始化和 M0 骨架，建立文档优先维护方式。
- 搭出 Recording、Gallery、Settings、DeviceOnboarding、Help Center 与首次安装引导等主要 UI 闭环。
- 建立设备控制协议与会话基础层：JSON 编解码、`\n` 分帧、请求响应匹配、事件路由、握手命令计划、`DeviceSession` 状态机和最小测试护栏。
