# 规格文档

本目录记录按能力拆分的长期规格。实现进度写 `../TASKS.md`，实际改动写 `../CHANGELOG.md`。

## 读取顺序

1. [device-protocol](device-protocol/README.md)：设备控制通道、消息结构、握手、Topic 与错误码口径。
2. [device-session](device-session/README.md)：`DeviceSession` 状态源、会话边界和 Feature 接入约束。
3. [device-onboarding](device-onboarding/README.md)：设备热点接入流程边界。
4. [live-preview](live-preview/README.md)：实时预览最小链路边界。
5. [settings-components](settings-components/README.md)：设置页已落地页面、路由和组件口径。

## 维护规则

- 规格只写契约、边界和长期约束。
- 不记录短期任务、验证过程或当前代码状态追踪。
- 同一事实只保留在最贴近职责的规格文件中。
