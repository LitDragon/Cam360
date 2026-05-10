## 任务：修改 UI 布局或样式

### 前置读取
1. 目标页面的 View 文件
2. `Cam360/Core/DesignSystem/` — 现有 token 和组件
3. `docs/specs/ui-components/README.md` — 公共组件清单和使用关系
4. `UI/` 目录下的对应截图作为视觉参考

### 约束
- 优先使用 DesignSystem 中已有的 token（AppColor、AppTypography、AppSpacing、AppRadius 等）。
- 公共组件修改需确认所有使用方不受影响。
- UI 页面改动默认落在 `Cam360/Features/`；只有明确需要公共 token/组件时才改 `Cam360/Core/DesignSystem/`。
- 不修改 `Cam360/App/`，除非任务涉及根路由、生命周期或依赖装配。
- 不顺手重构或清理无关代码。

### 验证
```bash
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"
python3 scripts/session_verifier.py --scope unstaged --format text
```
