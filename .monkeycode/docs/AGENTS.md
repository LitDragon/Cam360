## 元规则
- 子目录同名规则文件优先。

## 项目地图
- `Cam360/App`: UIKit 生命周期桥接、`AppBootstrap`、`AppRouter`、根视图与主 Tab。
- `Cam360/Core`: 仅放跨 Feature 复用的薄能力，M0 只允许设计系统、仓储接口和共享常量。
- `Cam360/Features`: 按功能拆目录；每个功能默认保留 `View + Store + Route + Components(可选)`。
- `Cam360/Resources`: `Info.plist`、启动页等资源。
- `Cam360Tests` / `Cam360UITests`: 单元测试与 UI 冒烟测试。
- `.monkeycode/`: 项目文档与规范存储。
  - `.monkeycode/docs/`: 整体项目文档。
  - `.monkeycode/specs/*/`: Feature 需求与设计规格，每一版需求对应一个子目录。


## 工作规则
- 前期优先做UI，核心模块后面加
- M0 阶段优先搭框架，不落地真实 AP onboarding、DeviceSession、预览/回放/下载链路。
- 主用 `iOS 15` 语法糖，最低兼容 `iOS 13` ；如果引入 `iOS 17+` 能力，必须隔离在 #available 分支外，不得影响主路径启动、路由和测试
- Feature 不直接持有底层连接、播放器或下载任务控制权；共享依赖统一从 `AppContainer` 组合后下发。

## 验证口径
- 默认先跑最窄验证：`build_sim` 或目标 scheme 的最小编译。
- 涉及启动分流、Tab 或页面骨架时，补一条对应的 UI 冒烟测试。
- 不声明成功，除非实际编译或测试已通过。
