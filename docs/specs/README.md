# 规格文档

本目录记录按能力拆分的长期规格。实现进度写 `../TASKS.md`，实际改动写 `../CHANGELOG.md`。

## 读取顺序

1. [ui-flow](ui-flow/README.md)：当前已落地页面、路由归属和页面跳转关系。
2. [ui-components](ui-components/README.md)：UI 组件分层、公共组件清单和页面使用关系。
3. [device-protocol](device-protocol/README.md)：设备控制通道、消息结构、握手、Topic 与错误码口径。
4. [device-session](device-session/README.md)：`DeviceSession` 状态源、会话边界和 Feature 接入约束。
5. [device-onboarding](device-onboarding/README.md)：设备热点接入流程边界。
6. [live-preview](live-preview/README.md)：实时预览最小链路边界。
7. [settings-components](settings-components/README.md)：设置页已落地页面、路由和组件口径。

## Front Matter 约定

每个规格文件可在开头使用 YAML front matter 标注依赖和硬件门槛。该元数据不表示实现进度或验证结论，进度仍写 `../TASKS.md`。

```yaml
---
depends_on: [other-spec-name]
hardware_required: true | false
```

- `depends_on`：本规格依赖的其他规格。
- `hardware_required`：完整验证是否依赖真设备或可信设备端模拟器。

## 维护规则

- 规格只写契约、边界和长期约束。
- 不记录短期任务、验证过程或当前代码状态追踪。
- 同一事实只保留在最贴近职责的规格文件中。
