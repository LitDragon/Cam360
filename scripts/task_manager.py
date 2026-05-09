#!/usr/bin/env python3
"""Task management script for Cam360 project.

Provides task management capabilities:
1. Parse TASKS.md for current phase and tasks
2. Track task progress
3. Generate task reports
4. Integrate with other validation scripts
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from datetime import datetime
from typing import Dict, List, Optional, Tuple

ROOT = pathlib.Path(__file__).resolve().parent.parent


class Task:
    """Represents a task."""
    
    def __init__(self, title: str, description: str = "", status: str = "pending",
                 priority: str = "medium", category: str = ""):
        self.title = title
        self.description = description
        self.status = status  # pending, in_progress, completed, blocked
        self.priority = priority  # low, medium, high, critical
        self.category = category
        self.created_at = datetime.now().isoformat()
        self.updated_at = self.created_at
        self.dependencies: List[str] = []
        self.notes: List[str] = []
    
    def to_dict(self) -> Dict:
        return {
            "title": self.title,
            "description": self.description,
            "status": self.status,
            "priority": self.priority,
            "category": self.category,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "dependencies": self.dependencies,
            "notes": self.notes
        }


def parse_tasks_md() -> Dict:
    """Parse TASKS.md for current phase and tasks."""
    tasks_path = ROOT / "docs" / "TASKS.md"
    if not tasks_path.exists():
        return {"phase": "unknown", "tasks": []}
    
    content = tasks_path.read_text(encoding="utf-8")
    
    # Extract phase status
    phase_match = re.search(r"## 阶段状态\s*\n([\s\S]*?)(?=\n## |\Z)", content)
    phase = phase_match.group(1).strip() if phase_match else "unknown"
    
    # Extract tasks (simplified - in reality would need more sophisticated parsing)
    tasks = []
    
    # Look for task-like patterns
    task_patterns = [
        r"-\s*\[[ x]\]\s*(.+)",  # Markdown checkboxes
        r"-\s*(.+)",  # List items
        r"\d+\.\s*(.+)",  # Numbered lists
    ]
    
    for pattern in task_patterns:
        for match in re.finditer(pattern, content):
            task_text = match.group(1).strip()
            if task_text and len(task_text) > 5:  # Filter out short items
                # Determine status from checkbox or keywords
                status = "pending"
                if "[x]" in match.group(0).lower():
                    status = "completed"
                elif "进行中" in task_text or "in progress" in task_text.lower():
                    status = "in_progress"
                elif "阻塞" in task_text or "blocked" in task_text.lower():
                    status = "blocked"
                
                tasks.append(Task(
                    title=task_text,
                    status=status,
                    category="general"
                ))
    
    return {
        "phase": phase,
        "tasks": [task.to_dict() for task in tasks]
    }


def load_tasks_from_json(json_path: pathlib.Path) -> List[Task]:
    """Load tasks from JSON file."""
    if not json_path.exists():
        return []
    
    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
        tasks = []
        for item in data.get("tasks", []):
            task = Task(
                title=item.get("title", ""),
                description=item.get("description", ""),
                status=item.get("status", "pending"),
                priority=item.get("priority", "medium"),
                category=item.get("category", "")
            )
            task.created_at = item.get("created_at", task.created_at)
            task.updated_at = item.get("updated_at", task.updated_at)
            task.dependencies = item.get("dependencies", [])
            task.notes = item.get("notes", [])
            tasks.append(task)
        return tasks
    except (json.JSONDecodeError, KeyError):
        return []


def save_tasks_to_json(tasks: List[Task], json_path: pathlib.Path) -> None:
    """Save tasks to JSON file."""
    data = {
        "tasks": [task.to_dict() for task in tasks],
        "metadata": {
            "total": len(tasks),
            "by_status": {
                "pending": sum(1 for t in tasks if t.status == "pending"),
                "in_progress": sum(1 for t in tasks if t.status == "in_progress"),
                "completed": sum(1 for t in tasks if t.status == "completed"),
                "blocked": sum(1 for t in tasks if t.status == "blocked")
            },
            "by_priority": {
                "low": sum(1 for t in tasks if t.priority == "low"),
                "medium": sum(1 for t in tasks if t.priority == "medium"),
                "high": sum(1 for t in tasks if t.priority == "high"),
                "critical": sum(1 for t in tasks if t.priority == "critical")
            },
            "last_updated": datetime.now().isoformat()
        }
    }
    
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def generate_task_report(tasks: List[Task]) -> str:
    """Generate task report."""
    lines = []
    lines.append("# Task Report")
    lines.append("")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    
    # Summary
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Total tasks: {len(tasks)}")
    lines.append(f"- Pending: {sum(1 for t in tasks if t.status == 'pending')}")
    lines.append(f"- In progress: {sum(1 for t in tasks if t.status == 'in_progress')}")
    lines.append(f"- Completed: {sum(1 for t in tasks if t.status == 'completed')}")
    lines.append(f"- Blocked: {sum(1 for t in tasks if t.status == 'blocked')}")
    lines.append("")
    
    # Priority breakdown
    lines.append("## Priority Breakdown")
    lines.append("")
    lines.append(f"- Critical: {sum(1 for t in tasks if t.priority == 'critical')}")
    lines.append(f"- High: {sum(1 for t in tasks if t.priority == 'high')}")
    lines.append(f"- Medium: {sum(1 for t in tasks if t.priority == 'medium')}")
    lines.append(f"- Low: {sum(1 for t in tasks if t.priority == 'low')}")
    lines.append("")
    
    # Tasks by status
    lines.append("## Tasks by Status")
    lines.append("")
    
    for status in ["blocked", "in_progress", "pending", "completed"]:
        status_tasks = [t for t in tasks if t.status == status]
        if status_tasks:
            lines.append(f"### {status.replace('_', ' ').title()}")
            lines.append("")
            for task in status_tasks:
                lines.append(f"- [{task.priority}] {task.title}")
                if task.description:
                    lines.append(f"  {task.description}")
            lines.append("")
    
    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Manage tasks for Cam360 project")
    parser.add_argument("--action", choices=["list", "report", "parse", "add", "update"],
                       default="list", help="Action to perform")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                       help="Output format")
    parser.add_argument("--output", "-o", help="Output file")
    parser.add_argument("--title", help="Task title (for add/update)")
    parser.add_argument("--status", help="Task status (for update)")
    parser.add_argument("--priority", help="Task priority (for add/update)")
    parser.add_argument("--category", help="Task category (for add)")
    parser.add_argument("--task-file", default="build/tasks.json",
                       help="Task JSON file path")
    args = parser.parse_args()
    
    task_file = ROOT / args.task_file
    
    if args.action == "parse":
        # Parse TASKS.md
        result = parse_tasks_md()
        if args.format == "json":
            output = json.dumps(result, indent=2, ensure_ascii=False)
        else:
            lines = ["Current Phase:"]
            lines.append(result["phase"])
            lines.append("")
            lines.append(f"Tasks found: {len(result['tasks'])}")
            for task in result["tasks"][:10]:  # Show first 10
                lines.append(f"- {task['title']}")
            output = "\n".join(lines)
    
    elif args.action == "list":
        # List tasks from JSON file
        tasks = load_tasks_from_json(task_file)
        if not tasks:
            # Try parsing TASKS.md
            result = parse_tasks_md()
            tasks = [Task(**task) for task in result["tasks"]]
        
        if args.format == "json":
            output = json.dumps([t.to_dict() for t in tasks], indent=2, ensure_ascii=False)
        else:
            lines = [f"Tasks ({len(tasks)}):"]
            for task in tasks:
                lines.append(f"- [{task.status}] {task.title}")
            output = "\n".join(lines)
    
    elif args.action == "report":
        # Generate report
        tasks = load_tasks_from_json(task_file)
        if not tasks:
            result = parse_tasks_md()
            tasks = [Task(**task) for task in result["tasks"]]
        
        report = generate_task_report(tasks)
        
        if args.output:
            pathlib.Path(args.output).write_text(report, encoding="utf-8")
            print(f"Report written to {args.output}", file=sys.stderr)
        else:
            print(report)
        return 0
    
    elif args.action == "add":
        # Add new task
        if not args.title:
            print("Error: --title is required for add action", file=sys.stderr)
            return 1
        
        tasks = load_tasks_from_json(task_file)
        new_task = Task(
            title=args.title,
            status="pending",
            priority=args.priority or "medium",
            category=args.category or "general"
        )
        tasks.append(new_task)
        save_tasks_to_json(tasks, task_file)
        
        print(f"Task added: {args.title}", file=sys.stderr)
        return 0
    
    elif args.action == "update":
        # Update task status
        if not args.title or not args.status:
            print("Error: --title and --status are required for update action", file=sys.stderr)
            return 1
        
        tasks = load_tasks_from_json(task_file)
        updated = False
        
        for task in tasks:
            if task.title == args.title:
                task.status = args.status
                task.updated_at = datetime.now().isoformat()
                if args.priority:
                    task.priority = args.priority
                updated = True
                break
        
        if not updated:
            print(f"Task not found: {args.title}", file=sys.stderr)
            return 1
        
        save_tasks_to_json(tasks, task_file)
        print(f"Task updated: {args.title}", file=sys.stderr)
        return 0
    
    else:
        print(f"Unknown action: {args.action}", file=sys.stderr)
        return 1
    
    # Output results
    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Output written to {args.output}", file=sys.stderr)
    else:
        print(output)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())