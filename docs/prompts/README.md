# 会话模板

本目录存放常见任务的 AI 会话模板。使用方式：在新会话开头粘贴对应模板，AI 可直接进入执行而无需重新理解项目。

## 模板索引

| 模板 | 适用场景 |
| --- | --- |
| [new-feature-page.md](new-feature-page.md) | 新增 Feature 页面（View + Store + Route） |
| [modify-ui.md](modify-ui.md) | 修改现有页面的 UI 布局或样式 |
| [modify-protocol.md](modify-protocol.md) | 修改设备协议层代码 |
| [modify-settings.md](modify-settings.md) | 修改设置页面或设置 Store |
| [bug-fix.md](bug-fix.md) | 修复 bug 并补回归测试 |
| [add-test.md](add-test.md) | 为现有功能补测试 |
| [ai-maintenance.md](ai-maintenance.md) | 维护 AI 文档、脚本和自动化护栏 |

## 维护规则

- 每个模板必须包含：前置读取清单、约束提醒、验证步骤。
- App 相关模板的验证命令统一使用 `$SIMULATOR_DESTINATION` + `python3 scripts/session_verifier.py --scope unstaged --format text`。
- 模板命令格式由 `python3 scripts/prompt_validator.py --format text` 自动检查。
- 模板保持精简；不要在模板里重复 PROJECT_CONTEXT.md 已有的事实。
- 新增模板时同步更新本索引。
