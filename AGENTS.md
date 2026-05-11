## 元规则
- 子目录同名规则文件优先。
- 默认先读根目录 `README.md`，长期事实以 `docs/PROJECT_CONTEXT.md` 为准。

## 工作规则
- 前期优先做UI，核心模块后面加
- 真机前可离线推进的接入阶段已收口；真实 AP 自动连接、预览、回放、下载链路仍按 `docs/TASKS.md` 的硬件联调队列推进。
- 主用 `iOS 15` 语法糖，最低兼容 `iOS 13` ；如果引入 `iOS 17+` 能力，必须隔离在 #available 分支外，不得影响主路径启动、路由和测试
- Feature 不直接持有底层连接、播放器或下载任务控制权；共享依赖统一从 `AppContainer` 组合后下发。
- 文档默认必须精简；同一事实不要在多个文件里重复展开。

## 实施原则
- 先想清楚再动手：关键上下文不清、存在多种解释或方案权衡明显时，先显式说明假设或歧义，不要静默选一种。
- 默认按 TDD 推进非纯 UI/文档改动：先补最小失败测试或回归用例，再实现，再跑最窄验证；纯 UI 布局、视觉微调、脚手架占位或无法稳定自动化验证的改动，可先实现再做最窄可行验证，并在结果中说明原因。
- 默认选最简单可落地的方案：不预埋未请求的能力、抽象、配置项或“以后可能会用到”的扩展点。
- 改动必须足够手术刀：只改完成当前任务所必需的代码；不顺手重构、不清理无关格式或注释；只移除本次改动直接引入的无用代码。
- 多步骤任务先给最短计划，并为每一步指定可执行的验证点；实现完成后按验证结果汇报，不用“看起来可行”代替结果。

## AI Harness
- 新会话先运行 `./scripts/context.sh`，再按任务读取 `docs/prompts/`、`docs/specs/` 和目标代码；不要凭记忆补全事实。
- 写代码前先用 `rg` 或现有文件确认符号、API、路由和测试位置；没在仓库中找到的内容必须说明，不要捏造。
- 脚本只作为护栏：`context.sh`、`api_validator.py`、`context_snapshot.py`、`dependency_checker.py`、`impact_analyzer.py`、`knowledge_graph.py`、`project_docs.py`、`prompt_validator.py`、`refactor_agent.py`、`session_verifier.py`、`task_manager.py`、`test_coverage_checker.py` 提供线索，不能替代编译、测试或人工 review。
- 影响面按实际改动选择最窄验证；文档/脚本改动不默认要求 App 全量测试，源码行为改动才按风险扩大验证。
- 长期事实进 `PROJECT_CONTEXT.md`、`docs/specs/` 或 `docs/decisions/`；短期状态进 `TASKS.md`；避免同一事实多处重复。
- 每次代码、配置、脚本或自动化改动完成前，必须显式判断是否需要同步文档；需要则同步，不需要则在最终结果中说明原因。

## 场景：修改 UI
- 先看 `UI/` 目录下的参考截图。
- 遵循 `Cam360/Core/DesignSystem/` 的 token 和组件规范。
- UI 页面改动默认落在 `Cam360/Features/`；只有明确需要公共 token/组件时才改 `Cam360/Core/DesignSystem/`。
- 不要修改 `Cam360/App/`，除非任务涉及根路由、生命周期或依赖装配。
- 公共组件改动需确认所有使用方不受影响。

## 场景：修改协议
- 先读 `docs/specs/device-protocol/README.md`。
- 补协议回放测试（在 `Cam360Tests/` 中用 FakeTransport）。
- 不要修改 `Cam360/Features/` 下的代码。
- 同步更新 `device-protocol` spec。

## 场景：修改设置
- 先读 `Cam360/Features/Settings/SettingsStore.swift` 和 `SettingsModels.swift`。
- 设置写操作采用悲观更新策略，详见 `docs/specs/settings-components/README.md`。
- 不要直接操作 `DeviceSession` 连接。

## 场景：新增 Feature 页面
- 先读 `docs/prompts/new-feature-page.md` 获取完整步骤。
- View + Store + Route 文件结构保持一致。
- 在 `AppRouter`、`AppContainer`、`AppRootView` 中注册。

## 场景：修复 Bug
- 先写失败测试，再修复，再验证。
- 改动必须手术刀。
- 相关测试文件见 `Cam360Tests/`。

## 验证口径
- 默认先做最窄的非模拟器验证。
- CI 会跑基于 iOS Simulator 的 build/test，但本地默认不做手动模拟器验证。
- 不声明成功，除非实际编译或测试已通过。
