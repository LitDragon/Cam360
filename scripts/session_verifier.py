#!/usr/bin/env python3
"""Run the narrow validation set for the current AI session changes."""

from __future__ import annotations

import json
import os
import pathlib
import shlex
import subprocess
import sys
from typing import Dict, List, Tuple

from impact_analyzer import analyze_impact, collect_changed_files

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCOPE_TO_ACTION = {
    "unstaged": "unstaged",
    "staged": "staged",
    "all": "analyze",
    "recent": "recent",
}


def command_text(command: List[str]) -> str:
    return " ".join(shlex.quote(part) for part in command)


def run_command(command: List[str]) -> Dict:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return {
        "command": command_text(command),
        "exit_code": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def base_commands() -> List[List[str]]:
    return [
        [
            "python3",
            "-m",
            "py_compile",
            *[path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "scripts").glob("*.py"))],
        ],
        ["./scripts/context.sh"],
        ["python3", "scripts/api_validator.py", "--format", "text", "--check-hallucinations"],
        ["python3", "scripts/dependency_checker.py", "--format", "text", "--check-circular"],
        ["python3", "scripts/knowledge_graph.py", "--format", "text"],
        ["python3", "scripts/impact_analyzer.py", "--action", "unstaged", "--format", "text"],
        ["python3", "scripts/task_manager.py", "--action", "parse", "--format", "text"],
        ["python3", "scripts/test_coverage_checker.py", "--format", "text"],
        ["python3", "scripts/prompt_validator.py", "--format", "text"],
        ["git", "diff", "--check"],
    ]


def needs_doc_link_check(changed_files: List[str]) -> bool:
    return any(path.endswith(".md") or path in {"README.md", "AGENTS.md"} for path in changed_files)


def needs_xcodebuild(changed_files: List[str]) -> bool:
    return any(path.endswith(".swift") and path.startswith(("Cam360/", "Cam360Tests/")) for path in changed_files)


def xcode_action(changed_files: List[str], impact: Dict) -> str:
    tests_changed = any(path.startswith("Cam360Tests/") and path.endswith(".swift") for path in changed_files)
    if tests_changed or impact.get("related_tests"):
        return "test"
    return "build"


def xcodebuild_command(action: str) -> Tuple[List[str], str]:
    destination = os.environ.get("SIMULATOR_DESTINATION")
    if not destination:
        return [], "SIMULATOR_DESTINATION is required for Swift validation"
    return [
        "xcodebuild",
        action,
        "-project",
        "Cam360.xcodeproj",
        "-scheme",
        "Cam360",
        "-configuration",
        "Debug",
        "-destination",
        destination,
        "CODE_SIGNING_ALLOWED=NO",
    ], ""


def validation_plan(scope: str, days: int, skip_xcodebuild: bool) -> Dict:
    action = SCOPE_TO_ACTION[scope]
    changed_files = collect_changed_files(action, days)
    impact = analyze_impact(changed_files) if changed_files else {
        "changed_files": [],
        "changed_by_layer": {},
        "affected_files": {},
        "total_affected_files": 0,
        "related_tests": [],
        "risk_assessment": {"level": "low", "factors": [], "validation": []},
    }
    commands = base_commands()
    if needs_doc_link_check(changed_files):
        commands.append(["python3", "scripts/refactor_agent.py", "check-doc-links", "--config", ".github/docs-agent.json"])
    xcode_error = ""
    if needs_xcodebuild(changed_files):
        if skip_xcodebuild:
            impact["risk_assessment"].setdefault("factors", []).append("Swift validation skipped by --skip-xcodebuild")
        else:
            command, xcode_error = xcodebuild_command(xcode_action(changed_files, impact))
            if command:
                commands.append(command)

    return {
        "scope": scope,
        "changed_files": changed_files,
        "impact": impact,
        "commands": commands,
        "xcode_error": xcode_error,
    }


def run_plan(plan: Dict) -> Dict:
    results: List[Dict] = []
    if plan["xcode_error"]:
        return {**plan, "results": results, "status": "failed", "error": plan["xcode_error"]}

    for command in plan["commands"]:
        result = run_command(command)
        results.append(result)
        if result["exit_code"] != 0:
            return {**plan, "results": results, "status": "failed"}
    return {**plan, "results": results, "status": "passed"}


def text_report(report: Dict, plan_only: bool) -> str:
    lines = [
        "Session Verification",
        f"- scope: {report['scope']}",
        f"- changed files: {len(report['changed_files'])}",
        f"- risk level: {report['impact']['risk_assessment']['level']}",
    ]
    if report["impact"]["changed_by_layer"]:
        lines.append(
            "- changed by layer: "
            + ", ".join(
                f"{layer}:{len(files)}"
                for layer, files in report["impact"]["changed_by_layer"].items()
            )
        )
    if report.get("error"):
        lines.append(f"- error: {report['error']}")
    lines.append("- commands:")
    for command in report["commands"]:
        lines.append(f"  {command_text(command)}")
    if not plan_only:
        lines.append(f"- status: {report['status']}")
        if report.get("results"):
            failed = [item for item in report["results"] if item["exit_code"] != 0]
            if failed:
                lines.append(f"- failed command: {failed[0]['command']}")
                if failed[0]["stderr"]:
                    lines.append(f"- stderr: {failed[0]['stderr'].splitlines()[-1]}")
    return "\n".join(lines)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Verify current Cam360 AI session changes")
    parser.add_argument("--scope", choices=sorted(SCOPE_TO_ACTION), default="unstaged")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--plan-only", action="store_true")
    parser.add_argument("--skip-xcodebuild", action="store_true")
    args = parser.parse_args()

    plan = validation_plan(args.scope, args.days, args.skip_xcodebuild)
    report = plan if args.plan_only else run_plan(plan)
    output = json.dumps(report, indent=2, ensure_ascii=False) if args.format == "json" else text_report(report, args.plan_only)
    print(output)
    return 0 if args.plan_only or report.get("status") == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
