#!/usr/bin/env python3
"""Low-noise task queue helper for Cam360 AI sessions."""

from __future__ import annotations

import json
import pathlib
import sys
from datetime import datetime
from typing import Dict, List

from project_docs import parse_tasks_md

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATUSES = ("blocked", "in_progress", "pending", "completed")
PRIORITIES = ("critical", "high", "medium", "low")


def now_iso() -> str:
    return datetime.now().replace(microsecond=0).isoformat()


def managed_task(
    title: str,
    status: str = "pending",
    priority: str = "medium",
    category: str = "general",
) -> Dict:
    timestamp = now_iso()
    return {
        "title": title,
        "description": "",
        "status": status,
        "priority": priority,
        "category": category,
        "created_at": timestamp,
        "updated_at": timestamp,
        "dependencies": [],
        "notes": [],
    }


def load_tasks_from_json(json_path: pathlib.Path) -> List[Dict]:
    if not json_path.exists():
        return []

    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []

    tasks: List[Dict] = []
    for item in data.get("tasks", []):
        task = managed_task(
            title=item.get("title", ""),
            status=item.get("status", "pending"),
            priority=item.get("priority", "medium"),
            category=item.get("category", "general"),
        )
        task["description"] = item.get("description", "")
        task["created_at"] = item.get("created_at", task["created_at"])
        task["updated_at"] = item.get("updated_at", task["updated_at"])
        task["dependencies"] = item.get("dependencies", [])
        task["notes"] = item.get("notes", [])
        tasks.append(task)
    return tasks


def summarize_tasks(tasks: List[Dict]) -> Dict:
    return {
        "total": len(tasks),
        "by_status": {status: sum(1 for task in tasks if task.get("status") == status) for status in STATUSES},
        "by_priority": {
            priority: sum(1 for task in tasks if task.get("priority") == priority)
            for priority in PRIORITIES
        },
        "by_category": category_counts(tasks),
    }


def category_counts(tasks: List[Dict]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for task in tasks:
        category = task.get("category") or "general"
        counts[category] = counts.get(category, 0) + 1
    return counts


def save_tasks_to_json(tasks: List[Dict], json_path: pathlib.Path) -> None:
    data = {
        "tasks": tasks,
        "metadata": {
            **summarize_tasks(tasks),
            "last_updated": now_iso(),
        },
    }
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def task_source(task_file: pathlib.Path) -> tuple[List[Dict], str]:
    tasks = load_tasks_from_json(task_file)
    if tasks:
        return tasks, task_file.relative_to(ROOT).as_posix()
    return parse_tasks_md()["tasks"], "docs/TASKS.md"


def generate_task_report(tasks: List[Dict], source: str) -> str:
    summary = summarize_tasks(tasks)
    lines = [
        "Task Harness Check",
        f"- source: {source}",
        f"- tracked tasks: {summary['total']}",
        "- by status: "
        + ", ".join(f"{status}:{summary['by_status'][status]}" for status in STATUSES),
    ]
    if summary["by_category"]:
        lines.append(
            "- by category: "
            + ", ".join(
                f"{category}:{count}"
                for category, count in sorted(summary["by_category"].items())
            )
        )
    return "\n".join(lines)


def parse_report(result: Dict) -> str:
    lines = [
        "Task Harness Check",
        f"- phase items: {len(result['phase'].splitlines())}",
        f"- tracked tasks: {len(result['tasks'])}",
        "- tracked sections: "
        + ", ".join(f"{name}:{len(items)}" for name, items in result["sections"].items()),
    ]
    return "\n".join(lines)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Manage Cam360 AI task queues")
    parser.add_argument("--action", choices=["list", "report", "parse", "add", "update"], default="list")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--output", "-o")
    parser.add_argument("--title", help="Task title for add/update")
    parser.add_argument("--status", help="Task status for update")
    parser.add_argument("--priority", help="Task priority for add/update")
    parser.add_argument("--category", help="Task category for add")
    parser.add_argument("--task-file", default="build/tasks.json")
    args = parser.parse_args()

    task_file = ROOT / args.task_file

    if args.action == "parse":
        result = parse_tasks_md()
        output = json.dumps(result, indent=2, ensure_ascii=False) if args.format == "json" else parse_report(result)

    elif args.action == "list":
        tasks, source = task_source(task_file)
        if args.format == "json":
            output = json.dumps(tasks, indent=2, ensure_ascii=False)
        else:
            lines = [generate_task_report(tasks, source)]
            for task in tasks:
                lines.append(f"  {task.get('status', 'pending')}: {task.get('title', '')}")
            output = "\n".join(lines)

    elif args.action == "report":
        tasks, source = task_source(task_file)
        output = json.dumps({"summary": summarize_tasks(tasks), "source": source}, indent=2, ensure_ascii=False)
        if args.format == "text":
            output = generate_task_report(tasks, source)

    elif args.action == "add":
        if not args.title:
            print("Error: --title is required for add action", file=sys.stderr)
            return 1
        tasks = load_tasks_from_json(task_file)
        tasks.append(
            managed_task(
                title=args.title,
                priority=args.priority or "medium",
                category=args.category or "general",
            )
        )
        save_tasks_to_json(tasks, task_file)
        print(f"Task added: {args.title}", file=sys.stderr)
        return 0

    elif args.action == "update":
        if not args.title or not args.status:
            print("Error: --title and --status are required for update action", file=sys.stderr)
            return 1
        tasks = load_tasks_from_json(task_file)
        for task in tasks:
            if task.get("title") == args.title:
                task["status"] = args.status
                task["updated_at"] = now_iso()
                if args.priority:
                    task["priority"] = args.priority
                save_tasks_to_json(tasks, task_file)
                print(f"Task updated: {args.title}", file=sys.stderr)
                return 0
        print(f"Task not found: {args.title}", file=sys.stderr)
        return 1

    else:
        print(f"Unknown action: {args.action}", file=sys.stderr)
        return 1

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Output written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
