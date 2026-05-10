#!/usr/bin/env python3
"""Validate Cam360 AI prompt verification command blocks."""

from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Dict, List

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROMPTS_DIR = ROOT / "docs" / "prompts"
SIMULATOR_GUARD = (
    'SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?Set SIMULATOR_DESTINATION to an '
    'available simulator, e.g. platform=iOS Simulator,name=iPhone 17}"'
)
SESSION_VERIFY = "python3 scripts/session_verifier.py --scope unstaged --format text"
MAINTENANCE_VERIFY = "python3 scripts/session_verifier.py --scope unstaged --skip-xcodebuild --format text"
DOC_LINK_CHECK = "python3 scripts/refactor_agent.py check-doc-links --config .github/docs-agent.json"


def prompt_files() -> List[pathlib.Path]:
    return sorted(path for path in PROMPTS_DIR.glob("*.md") if path.name != "README.md")


def verification_section(content: str) -> str:
    match = re.search(r"### 验证\s*\n([\s\S]*?)(?=\n### |\Z)", content)
    return match.group(1).strip() if match else ""


def bash_blocks(section: str) -> List[str]:
    return re.findall(r"```bash\s*\n([\s\S]*?)\n```", section)


def normalized_lines(blocks: List[str]) -> List[str]:
    lines: List[str] = []
    for block in blocks:
        for line in block.splitlines():
            stripped = line.strip()
            if stripped:
                lines.append(stripped)
    return lines


def validate_prompt(path: pathlib.Path) -> List[str]:
    content = path.read_text(encoding="utf-8")
    section = verification_section(content)
    if not section:
        return ["missing ### 验证 section"]

    lines = normalized_lines(bash_blocks(section))
    if not lines:
        return ["missing bash validation block"]

    if path.name == "ai-maintenance.md":
        return validate_maintenance_prompt(lines)
    return validate_app_prompt(lines)


def validate_app_prompt(lines: List[str]) -> List[str]:
    violations: List[str] = []
    if SIMULATOR_GUARD not in lines:
        violations.append("missing canonical SIMULATOR_DESTINATION guard")
    if SESSION_VERIFY not in lines:
        violations.append("missing canonical session verifier command")
    if any(line.startswith("xcodebuild ") for line in lines):
        violations.append("use session_verifier instead of direct xcodebuild in prompt templates")
    return violations


def validate_maintenance_prompt(lines: List[str]) -> List[str]:
    violations: List[str] = []
    if MAINTENANCE_VERIFY not in lines:
        violations.append("missing maintenance session verifier command")
    if DOC_LINK_CHECK not in lines:
        violations.append("missing docs link check command")
    if any(line.startswith("xcodebuild ") for line in lines):
        violations.append("maintenance prompt should not run direct xcodebuild")
    return violations


def validate_prompts() -> Dict:
    violations: List[Dict[str, str]] = []
    files = prompt_files()
    for path in files:
        rel_path = path.relative_to(ROOT).as_posix()
        for violation in validate_prompt(path):
            violations.append({"file": rel_path, "violation": violation})
    return {
        "summary": {
            "prompt_files": len(files),
            "violations": len(violations),
        },
        "violations": violations,
    }


def text_report(report: Dict) -> str:
    lines = [
        "Prompt Template Check",
        f"- prompt files: {report['summary']['prompt_files']}",
        f"- violations: {report['summary']['violations']}",
    ]
    if report["violations"]:
        lines.append("- findings:")
        for item in report["violations"]:
            lines.append(f"  {item['file']}: {item['violation']}")
    return "\n".join(lines)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Validate docs/prompts verification command format")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args()

    report = validate_prompts()
    print(json.dumps(report, indent=2, ensure_ascii=False) if args.format == "json" else text_report(report))
    return 0 if report["summary"]["violations"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
