#!/usr/bin/env python3
"""Shared parsers for Cam360 AI harness documentation."""

from __future__ import annotations

import pathlib
import re
from typing import Dict, List

ROOT = pathlib.Path(__file__).resolve().parent.parent
TRACKED_TASK_SECTIONS = ("无设备期间", "硬件恢复后联调队列", "资料缺口")


def section_body(content: str, title: str) -> str:
    match = re.search(rf"## {re.escape(title)}\s*\n([\s\S]*?)(?=\n## |\Z)", content)
    return match.group(1).strip() if match else ""


def section_items(content: str) -> List[str]:
    items: List[str] = []
    for line in content.splitlines():
        match = re.match(r"\s*(?:-\s+|\d+\.\s+)(.+)", line)
        if match:
            items.append(match.group(1).strip())
    return items


def task_status_for_section(section_name: str) -> str:
    if section_name in {"硬件恢复后联调队列", "资料缺口"}:
        return "blocked"
    return "pending"


def parse_tasks_md(root: pathlib.Path = ROOT) -> Dict:
    tasks_path = root / "docs" / "TASKS.md"
    if not tasks_path.exists():
        return {"phase": "TASKS.md not found", "sections": {}, "tasks": []}

    content = tasks_path.read_text(encoding="utf-8")
    phase = section_body(content, "阶段状态") or "Phase status section not found"
    sections: Dict[str, List[str]] = {}
    tasks: List[Dict[str, str]] = []

    for section_name in TRACKED_TASK_SECTIONS:
        items = section_items(section_body(content, section_name))
        sections[section_name] = items
        for item in items:
            tasks.append(
                {
                    "title": item,
                    "status": task_status_for_section(section_name),
                    "priority": "medium",
                    "category": section_name,
                }
            )

    return {"phase": phase, "sections": sections, "tasks": tasks}


def parse_front_matter(content: str) -> Dict[str, str]:
    front_matter: Dict[str, str] = {}
    match = re.match(r"^---\s*\n([\s\S]*?)\n---", content)
    if not match:
        return front_matter

    for line in match.group(1).splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            front_matter[key.strip()] = value.strip()
    return front_matter


def parse_spec_metadata(root: pathlib.Path = ROOT) -> List[Dict[str, str]]:
    specs_dir = root / "docs" / "specs"
    results: List[Dict[str, str]] = []
    if not specs_dir.exists():
        return results

    for spec_path in sorted(specs_dir.rglob("README.md")):
        if spec_path.parent == specs_dir:
            continue
        content = spec_path.read_text(encoding="utf-8")
        front_matter = parse_front_matter(content)
        results.append(
            {
                "path": spec_path.relative_to(root).as_posix(),
                "depends_on": front_matter.get("depends_on", "[]"),
                "hardware_required": front_matter.get("hardware_required", "unknown"),
            }
        )
    return results
