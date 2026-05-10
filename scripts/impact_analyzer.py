#!/usr/bin/env python3
"""Low-noise impact analysis for Cam360 changes."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
from collections import defaultdict
from typing import Dict, List, Set

from dependency_checker import analyze_dependencies, determine_layer as determine_swift_layer

ROOT = pathlib.Path(__file__).resolve().parent.parent


def run_git(args: List[str]) -> List[str]:
    result = subprocess.run(
        ["git", "-c", "core.quotepath=false", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def get_changed_files(days: int = 7) -> List[str]:
    return sorted(set(run_git(["log", f"--since={days} days ago", "--name-only", "--pretty=format:"])))


def get_staged_changes() -> List[str]:
    return run_git(["diff", "--cached", "--name-only"])


def get_untracked_changes() -> List[str]:
    return run_git(["ls-files", "--others", "--exclude-standard"])


def get_unstaged_changes() -> List[str]:
    return sorted(set(run_git(["diff", "--name-only"]) + get_untracked_changes()))


def collect_changed_files(action: str, days: int) -> List[str]:
    if action == "staged":
        return get_staged_changes()
    if action == "unstaged":
        return get_unstaged_changes()
    if action == "recent":
        return get_changed_files(days)
    return sorted(set(get_staged_changes() + get_unstaged_changes()))


def determine_change_layer(file_path: str) -> str:
    if file_path.startswith(".github/"):
        return "CI"
    if file_path.startswith("docs/") or file_path in {"README.md", "AGENTS.md"}:
        return "Docs"
    if file_path.startswith("scripts/"):
        return "Scripts"
    return determine_swift_layer(file_path)


def find_affected_files(changed_files: List[str], file_deps: Dict[str, Dict]) -> Dict[str, List[str]]:
    changed = set(changed_files)
    affected: Dict[str, Set[str]] = defaultdict(set)

    for source, deps in file_deps.items():
        if source in changed:
            continue
        for target in deps["dependency_files"].values():
            if target in changed:
                affected[target].add(source)

    return {path: sorted(files) for path, files in sorted(affected.items())}


def find_related_tests(changed_files: List[str], file_deps: Dict[str, Dict]) -> List[str]:
    changed = set(changed_files)
    source_swift = {
        file_path
        for file_path in changed
        if file_path.startswith("Cam360/") and file_path.endswith(".swift")
    }
    tests = {
        file_path
        for file_path in changed
        if file_path.startswith("Cam360Tests/") and file_path.endswith(".swift")
    }

    for file_path, deps in file_deps.items():
        if not file_path.startswith("Cam360Tests/"):
            continue
        if any(target in source_swift for target in deps["dependency_files"].values()):
            tests.add(file_path)

    fallback = ROOT / "Cam360Tests" / "Cam360Tests.swift"
    if source_swift and not tests and fallback.exists():
        tests.add("Cam360Tests/Cam360Tests.swift")
    return sorted(tests)


def changed_by_layer(changed_files: List[str]) -> Dict[str, List[str]]:
    layers: Dict[str, List[str]] = defaultdict(list)
    for file_path in changed_files:
        layers[determine_change_layer(file_path)].append(file_path)
    return {layer: sorted(files) for layer, files in sorted(layers.items())}


def validation_commands(changed_files: List[str], related_tests: List[str]) -> List[str]:
    commands: List[str] = []
    docs_changed = any(path.endswith(".md") or path in {"README.md", "AGENTS.md"} for path in changed_files)
    scripts_changed = any(path.startswith("scripts/") for path in changed_files)
    source_swift_changed = any(path.startswith("Cam360/") and path.endswith(".swift") for path in changed_files)
    tests_changed = any(path.startswith("Cam360Tests/") and path.endswith(".swift") for path in changed_files)

    if scripts_changed:
        commands.append("python3 -m py_compile scripts/*.py")
        commands.append("run changed script commands")
    if docs_changed:
        commands.append("git diff --check")
        commands.append("python3 scripts/refactor_agent.py check-doc-links --config .github/docs-agent.json")
    if source_swift_changed or tests_changed:
        if related_tests:
            commands.append("xcodebuild test -project Cam360.xcodeproj -scheme Cam360 -destination \"$SIMULATOR_DESTINATION\" CODE_SIGNING_ALLOWED=NO")
        else:
            commands.append("xcodebuild build -project Cam360.xcodeproj -scheme Cam360 -destination \"$SIMULATOR_DESTINATION\" CODE_SIGNING_ALLOWED=NO")
    return commands


def assess_risk(
    changed_files: List[str],
    affected_files: Dict[str, List[str]],
    related_tests: List[str],
) -> Dict:
    factors: List[str] = []
    risk_level = "low"
    layers = set(changed_by_layer(changed_files).keys())
    source_swift = [path for path in changed_files if path.startswith("Cam360/") and path.endswith(".swift")]
    scripts_changed = any(path.startswith("scripts/") for path in changed_files)
    docs_changed = any(path.endswith(".md") or path in {"README.md", "AGENTS.md"} for path in changed_files)
    affected_count = sum(len(files) for files in affected_files.values())

    if scripts_changed:
        factors.append("Scripts changed")
        risk_level = "medium"
    if docs_changed:
        factors.append("Docs changed")
    if len(layers) > 1:
        factors.append("Changes span multiple layers")
        risk_level = "medium"
    if any("/Core/" in path or path.startswith("Cam360/App/") for path in source_swift):
        factors.append("Core or App Swift changed")
        risk_level = "high"
    if affected_count > 10:
        factors.append(f"Exact dependency graph shows {affected_count} affected files")
        risk_level = "high"
    if source_swift and not related_tests:
        factors.append("No related tests found")
        if risk_level == "low":
            risk_level = "medium"

    return {
        "level": risk_level,
        "factors": factors,
        "validation": validation_commands(changed_files, related_tests),
    }


def analyze_impact(changed_files: List[str]) -> Dict:
    file_deps = analyze_dependencies()
    affected_files = find_affected_files(changed_files, file_deps)
    related_tests = find_related_tests(changed_files, file_deps)
    return {
        "changed_files": changed_files,
        "changed_by_layer": changed_by_layer(changed_files),
        "affected_files": affected_files,
        "total_affected_files": sum(len(files) for files in affected_files.values()),
        "related_tests": related_tests,
        "risk_assessment": assess_risk(changed_files, affected_files, related_tests),
    }


def generate_impact_report(impact: Dict) -> str:
    lines = [
        "Impact Harness Check",
        f"- changed files: {len(impact['changed_files'])}",
        f"- affected files: {impact['total_affected_files']}",
        f"- related tests: {len(impact['related_tests'])}",
        f"- risk level: {impact['risk_assessment']['level']}",
    ]
    if impact["changed_by_layer"]:
        lines.append(
            "- changed by layer: "
            + ", ".join(
                f"{layer}:{len(files)}"
                for layer, files in impact["changed_by_layer"].items()
            )
        )
    if impact["risk_assessment"]["factors"]:
        lines.append("- risk factors: " + "; ".join(impact["risk_assessment"]["factors"]))
    if impact["risk_assessment"]["validation"]:
        lines.append("- validation:")
        for command in impact["risk_assessment"]["validation"]:
            lines.append(f"  {command}")
    return "\n".join(lines)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Analyze impact of Cam360 changes")
    parser.add_argument("--action", choices=["analyze", "staged", "unstaged", "recent"], default="recent")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--output", "-o")
    args = parser.parse_args()

    files = collect_changed_files(args.action, args.days)
    if not files:
        print("No changes found")
        return 0

    impact = analyze_impact(files)
    output = (
        json.dumps(impact, indent=2, ensure_ascii=False)
        if args.format == "json"
        else generate_impact_report(impact)
    )

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Impact analysis written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
