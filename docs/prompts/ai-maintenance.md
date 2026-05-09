## 任务：维护 AI Harness

### 前置读取
1. `docs/ai-maintenance-guide.md`
2. 目标脚本或目标文档

### 约束
- 不修改 `Cam360/` 源码。
- 默认精简，不新增泛化 iOS 建议。
- 脚本默认输出只给摘要；详细信息走 JSON。

### 验证
```bash
python3 -m py_compile scripts/*.py
./scripts/context.sh
python3 scripts/api_validator.py --format text --check-hallucinations
python3 scripts/dependency_checker.py --format text --check-circular
python3 scripts/impact_analyzer.py --action unstaged --format text
python3 scripts/test_coverage_checker.py --format text
git diff --check
python3 scripts/refactor_agent.py check-doc-links --config .github/docs-agent.json
```
