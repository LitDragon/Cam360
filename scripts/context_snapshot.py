#!/usr/bin/env python3
"""Generate a concise project context summary for AI session warm-start.

Outputs: current branch, recent commits, TASKS.md phase, spec statuses,
and recently modified files. Designed to be pasted at the start of an AI session.
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return result.stdout.strip()


def git_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"]) or "unknown"


def git_recent_commits(count: int = 5) -> list[str]:
    output = run(["git", "log", f"-{count}", "--oneline", "--no-decorate"])
    return [line for line in output.splitlines() if line] if output else []


def git_changed_files(days: int = 7) -> list[str]:
    output = run(["git", "-c", "core.quotepath=false", "log", f"--since={days} days ago", "--name-only", "--pretty=format:"])
    files = sorted(set(line.strip() for line in output.splitlines() if line.strip()))
    return files[:30]


def git_worktree_changes() -> list[str]:
    output = run(["git", "-c", "core.quotepath=false", "status", "--short"])
    return [line for line in output.splitlines() if line][:40]


def parse_tasks_phase() -> str:
    tasks_path = ROOT / "docs" / "TASKS.md"
    if not tasks_path.exists():
        return "TASKS.md not found"
    content = tasks_path.read_text(encoding="utf-8")
    match = re.search(r"## 阶段状态\s*\n([\s\S]*?)(?=\n## |\Z)", content)
    if match:
        return match.group(1).strip()[:500]
    return "Phase status section not found"


def parse_spec_metadata() -> list[dict[str, str]]:
    specs_dir = ROOT / "docs" / "specs"
    results = []
    if not specs_dir.exists():
        return results
    for spec_path in sorted(specs_dir.rglob("README.md")):
        if spec_path.parent == specs_dir:
            continue
        content = spec_path.read_text(encoding="utf-8")
        front_matter = {}
        fm_match = re.match(r"^---\s*\n([\s\S]*?)\n---", content)
        if fm_match:
            for line in fm_match.group(1).splitlines():
                if ":" in line:
                    key, _, value = line.partition(":")
                    front_matter[key.strip()] = value.strip()
        rel_path = spec_path.relative_to(ROOT).as_posix()
        results.append({
            "path": rel_path,
            "depends_on": front_matter.get("depends_on", "[]"),
            "hardware_required": front_matter.get("hardware_required", "unknown"),
        })
    return results


def main() -> int:
    branch = git_branch()
    commits = git_recent_commits(5)
    changed = git_changed_files(7)
    phase = parse_tasks_phase()
    spec_metadata = parse_spec_metadata()

    output = {
        "branch": branch,
        "recent_commits": commits,
        "tasks_phase": phase,
        "spec_metadata": spec_metadata,
        "recently_changed_files": changed,
        "worktree_changes": git_worktree_changes(),
    }

    print(json.dumps(output, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
