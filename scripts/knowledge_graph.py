#!/usr/bin/env python3
"""Generate a low-noise exact dependency graph for Cam360."""

from __future__ import annotations

import json
import pathlib
import re
import sys
from collections import defaultdict
from typing import Dict, List, Set, Tuple

from dependency_checker import analyze_dependencies, relative_path, swift_files

ROOT = pathlib.Path(__file__).resolve().parent.parent

TYPE_DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:final\s+|indirect\s+)?(?P<kind>class|struct|enum|protocol|actor)\s+(?P<name>\w+)",
    re.MULTILINE,
)
TYPEALIAS_DECL_RE = re.compile(
    r"^\s*(?:public|internal|private|fileprivate|open)?\s*typealias\s+(?P<name>\w+)",
    re.MULTILINE,
)


def line_number(content: str, offset: int) -> int:
    return content[:offset].count("\n") + 1


def layer_counts(file_deps: Dict[str, Dict]) -> Dict[str, int]:
    counts: Dict[str, int] = defaultdict(int)
    for deps in file_deps.values():
        counts[deps["layer"]] += 1
    return dict(counts)


def extract_project_types() -> Dict[str, List[Dict]]:
    types_by_file: Dict[str, List[Dict]] = {}
    for path in swift_files():
        rel_path = relative_path(path)
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        types: List[Dict] = []
        for match in TYPE_DECL_RE.finditer(content):
            types.append(
                {
                    "name": match.group("name"),
                    "kind": match.group("kind"),
                    "line": line_number(content, match.start()),
                }
            )
        for match in TYPEALIAS_DECL_RE.finditer(content):
            types.append(
                {
                    "name": match.group("name"),
                    "kind": "typealias",
                    "line": line_number(content, match.start()),
                }
            )
        if types:
            types_by_file[rel_path] = types
    return types_by_file


def dependency_edges(file_deps: Dict[str, Dict]) -> List[Dict]:
    grouped: Dict[Tuple[str, str], Set[str]] = defaultdict(set)
    for source, deps in file_deps.items():
        for symbol, target in deps["dependency_files"].items():
            if target != source:
                grouped[(source, target)].add(symbol)

    return [
        {
            "source": source,
            "target": target,
            "relation": "depends_on",
            "symbols": sorted(symbols),
        }
        for (source, target), symbols in sorted(grouped.items())
    ]


def build_graph() -> Dict:
    file_deps = analyze_dependencies()
    types_by_file = extract_project_types()
    edges = dependency_edges(file_deps)
    nodes = [
        {
            "id": file_path,
            "label": pathlib.Path(file_path).name,
            "type": "file",
            "layer": deps["layer"],
            "project_dependency_count": len(deps["dependency_files"]),
        }
        for file_path, deps in sorted(file_deps.items())
    ]

    return {
        "summary": {
            "total_files": len(file_deps),
            "files_by_layer": layer_counts(file_deps),
            "project_types": sum(len(types) for types in types_by_file.values()),
            "project_dependency_edges": len(edges),
        },
        "nodes": nodes,
        "edges": edges,
        "types_by_file": types_by_file,
    }


def dot_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generate_dot(graph: Dict) -> str:
    lines = ["digraph Cam360 {", "  rankdir=LR;", "  node [shape=box];", ""]
    for node in graph["nodes"]:
        label = f"{node['label']}\\n{node['layer']}"
        lines.append(f"  {dot_quote(node['id'])} [label={dot_quote(label)}];")
    if graph["edges"]:
        lines.append("")
    for edge in graph["edges"]:
        symbols = ", ".join(edge["symbols"][:3])
        if len(edge["symbols"]) > 3:
            symbols += f", +{len(edge['symbols']) - 3}"
        lines.append(
            f"  {dot_quote(edge['source'])} -> {dot_quote(edge['target'])} "
            f"[label={dot_quote(symbols)}];"
        )
    lines.append("}")
    return "\n".join(lines)


def generate_text_report(graph: Dict) -> str:
    layers = ", ".join(
        f"{layer}:{count}"
        for layer, count in sorted(graph["summary"]["files_by_layer"].items())
    )
    return "\n".join(
        [
            "Knowledge Graph Check",
            f"- files: {graph['summary']['total_files']} ({layers})",
            f"- project types: {graph['summary']['project_types']}",
            f"- project dependency edges: {graph['summary']['project_dependency_edges']}",
        ]
    )


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Generate Cam360 project dependency graph")
    parser.add_argument("--format", choices=["json", "text", "dot"], default="json")
    parser.add_argument("--output", "-o")
    args = parser.parse_args()

    graph = build_graph()
    if not graph["nodes"]:
        print("No Swift files found", file=sys.stderr)
        return 1

    if args.format == "json":
        output = json.dumps(graph, indent=2, ensure_ascii=False)
    elif args.format == "dot":
        output = generate_dot(graph)
    else:
        output = generate_text_report(graph)

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Knowledge graph written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
