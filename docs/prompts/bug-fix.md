## 任务：修复 Bug 并补回归测试

### 前置读取
1. 相关源文件
2. 现有测试文件（`Cam360Tests/`）
3. `AGENTS.md` 的实施原则

### 约束
- 遵循 TDD：先写一个能复现 bug 的失败测试，再修复，再验证通过。
- 改动必须手术刀：只改修复所必需的代码。
- 不顺手重构或清理无关代码。
- 如果 bug 涉及协议层，补协议回放测试而非集成测试。

### 步骤
1. 写一个最小失败测试，描述预期行为
2. 运行测试确认失败
3. 修复代码
4. 运行测试确认通过
5. 运行全量测试确认无回归

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
xcodebuild test -project Cam360.xcodeproj -scheme Cam360 -destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
```
