# AI Maintenance Harness

本文件只保留 AI 接手 Cam360 时的执行护栏：先找事实、少改、窄验。

## 会话启动

1. 运行 `./scripts/context.sh`。
2. 读 `README.md`、`docs/PROJECT_CONTEXT.md`、`docs/TASKS.md`。
3. 按任务读 `docs/prompts/` 或 `docs/specs/`。
4. 用 `rg` 确认目标符号；没查到就按未知处理。
5. 动手前先报目标文件、最小计划和验证点。

## 默认护栏

- 不凭记忆补 API、路由、target、业务正文或硬件行为。
- 优先复用现有 Store、Route、DesignSystem、测试 helper。
- 脚本是提示，不替代 `xcodebuild`、测试和人工 review。
- 长期事实写 `PROJECT_CONTEXT.md`、`docs/specs/` 或 `docs/decisions/`；短期状态写 `TASKS.md`。

## 常用检查

```bash
./scripts/context.sh
python3 scripts/session_verifier.py --scope unstaged --plan-only --format text
python3 scripts/api_validator.py --format text --check-hallucinations
python3 scripts/dependency_checker.py --format text --check-circular
python3 scripts/impact_analyzer.py --action unstaged --format text
python3 scripts/test_coverage_checker.py --format text
python3 scripts/prompt_validator.py --format text
```

- 文档/脚本改动跑 `python3 scripts/session_verifier.py --scope unstaged --skip-xcodebuild --format text` 和文档链接检查。
- 行为改动跑 `python3 scripts/session_verifier.py --scope unstaged --format text`；它会按实际 Swift 改动选择 `xcodebuild build` 或 `xcodebuild test`。
- CI 中的测试使用 `-enableCodeCoverage YES` 生成 `.xcresult`，再由 `test_coverage_checker.py --xcresult ... --check-coverage` 解析 xccov 覆盖率。

## 文档口径

- 文档短，事实单一归属。
- 脚本误报先修脚本，不把误报写成项目事实。
- 真实硬件行为未验证前，只写边界和待联调项。
