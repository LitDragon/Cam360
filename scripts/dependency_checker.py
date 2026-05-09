#!/usr/bin/env python3
"""Check Cam360 architectural dependencies with exact project symbols.

This scanner avoids substring matching. A dependency is only counted when a
Swift file references a type that is defined elsewhere in this repository.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from collections import defaultdict
from typing import Dict, List, Set

ROOT = pathlib.Path(__file__).resolve().parent.parent

TYPE_DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:final\s+|indirect\s+)?(?:class|struct|enum|protocol|actor)\s+(\w+)",
    re.MULTILINE,
)
TYPEALIAS_DECL_RE = re.compile(
    r"^\s*(?:public|internal|private|fileprivate|open)?\s*typealias\s+(\w+)",
    re.MULTILINE,
)
UPPER_SYMBOL_RE = re.compile(r"\b[A-Z][A-Za-z0-9_]*\b")
FORBIDDEN_FEATURE_TYPES = {
    "DeviceProtocolClient",
    "DeviceProtocolTransport",
    "NetworkDeviceProtocolTransport",
}
FORBIDDEN_FEATURE_IMPORTS = {"Network", "NetworkExtension"}


def swift_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for pattern in ("Cam360/**/*.swift", "Cam360Tests/**/*.swift"):
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def relative_path(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def determine_layer(file_path: str) -> str:
    if file_path.startswith("Cam360/App/"):
        return "App"
    if file_path.startswith("Cam360/Core/"):
        return "Core"
    if file_path.startswith("Cam360/Features/"):
        return "Features"
    if file_path.startswith("Cam360Tests/"):
        return "Tests"
    return "Other"


def strip_comments_and_strings(content: str) -> str:
    content = re.sub(r'"""[\s\S]*?"""', '""', content)
    content = re.sub(r'"(?:\\.|[^"\\])*"', '""', content)
    content = re.sub(r"//.*", "", content)
    content = re.sub(r"/\*[\s\S]*?\*/", "", content)
    return content


def extract_imports(content: str) -> Set[str]:
    return set(re.findall(r"^\s*import\s+(\w+)", content, re.MULTILINE))


def extract_defined_types(content: str) -> Set[str]:
    return set(TYPE_DECL_RE.findall(content)).union(TYPEALIAS_DECL_RE.findall(content))


def extract_type_references(content: str) -> Set[str]:
    return set(UPPER_SYMBOL_RE.findall(strip_comments_and_strings(content)))


def build_type_index(files: list[pathlib.Path]) -> Dict[str, str]:
    type_index: dict[str, str] = {}
    for path in files:
        rel_path = relative_path(path)
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for type_name in extract_defined_types(content):
            type_index.setdefault(type_name, rel_path)
    return type_index


def is_allowed_cross_layer_dependency(
    file_layer: str,
    dependency_layer: str,
    dependency: str,
) -> bool:
    if file_layer == dependency_layer:
        return True
    if file_layer == "Tests":
        return dependency_layer in {"App", "Core", "Features"}
    if file_layer == "App":
        return dependency_layer in {"Core", "Features"}
    if file_layer == "Features":
        return dependency_layer in {"App", "Core"}
    if file_layer == "Core":
        # Existing tab chrome is a deliberate shell/UI coupling in this repo.
        return dependency == "MainTab"
    return False


def analyze_dependencies() -> Dict[str, Dict]:
    files = swift_files()
    type_index = build_type_index(files)
    file_deps: Dict[str, Dict] = {}

    for path in files:
        rel_path = relative_path(path)
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        layer = determine_layer(rel_path)
        imports = extract_imports(content)
        defined_here = extract_defined_types(content)
        references = extract_type_references(content)
        project_dependencies = sorted(
            ref
            for ref in references
            if ref in type_index and ref not in defined_here
        )

        file_deps[rel_path] = {
            "layer": layer,
            "imports": sorted(imports),
            "type_references": sorted(references),
            "project_dependencies": project_dependencies,
            "dependency_files": {
                ref: type_index[ref]
                for ref in project_dependencies
                if type_index[ref] != rel_path
            },
        }

    return file_deps


def check_dependency_rules(file_deps: Dict[str, Dict]) -> List[Dict]:
    violations: list[Dict] = []

    for file_path, deps in file_deps.items():
        file_layer = deps["layer"]

        if file_layer == "Features":
            forbidden_imports = sorted(set(deps["imports"]).intersection(FORBIDDEN_FEATURE_IMPORTS))
            for import_name in forbidden_imports:
                violations.append(
                    {
                        "file": file_path,
                        "layer": file_layer,
                        "dependency": import_name,
                        "dependency_layer": "System",
                        "rule": "Features should not import transport frameworks directly",
                        "severity": "error",
                    }
                )

        for dependency, dependency_file in deps["dependency_files"].items():
            dependency_layer = file_deps[dependency_file]["layer"]

            if file_layer == "Features" and dependency in FORBIDDEN_FEATURE_TYPES:
                violations.append(
                    {
                        "file": file_path,
                        "layer": file_layer,
                        "dependency": dependency,
                        "dependency_layer": dependency_layer,
                        "rule": "Features should consume DeviceSession state instead of protocol transport types",
                        "severity": "error",
                    }
                )
                continue

            if not is_allowed_cross_layer_dependency(file_layer, dependency_layer, dependency):
                violations.append(
                    {
                        "file": file_path,
                        "layer": file_layer,
                        "dependency": dependency,
                        "dependency_layer": dependency_layer,
                        "rule": f"{file_layer} should not depend on {dependency_layer}",
                        "severity": "error",
                    }
                )

    return violations


def dependency_edges(file_deps: Dict[str, Dict]) -> Dict[str, Set[str]]:
    adjacency: Dict[str, Set[str]] = defaultdict(set)
    for file_path, deps in file_deps.items():
        for dependency, dependency_file in deps["dependency_files"].items():
            if dependency_file == file_path:
                continue
            dependency_layer = file_deps[dependency_file]["layer"]
            if is_allowed_cross_layer_dependency(deps["layer"], dependency_layer, dependency):
                adjacency[file_path].add(dependency_file)
    return adjacency


def check_circular_dependencies(file_deps: Dict[str, Dict]) -> List[Dict]:
    circular: list[Dict] = []
    adjacency = dependency_edges(file_deps)
    visited: set[str] = set()
    active: set[str] = set()

    def dfs(node: str, path: list[str]) -> None:
        visited.add(node)
        active.add(node)
        path.append(node)
        for neighbor in sorted(adjacency.get(node, set())):
            if neighbor not in visited:
                dfs(neighbor, path)
            elif neighbor in active:
                start = path.index(neighbor)
                cycle = path[start:] + [neighbor]
                if cycle not in [item["cycle"] for item in circular]:
                    circular.append({"cycle": cycle, "severity": "warning"})
        active.remove(node)
        path.pop()

    for node in sorted(adjacency):
        if node not in visited:
            dfs(node, [])
    return circular


def generate_dependency_report(
    file_deps: Dict[str, Dict],
    violations: List[Dict],
    circular: List[Dict],
) -> Dict:
    layer_counts = defaultdict(int)
    layer_deps = defaultdict(int)
    for file_path, deps in file_deps.items():
        layer_counts[deps["layer"]] += 1
        for dependency, dependency_file in deps["dependency_files"].items():
            dependency_layer = file_deps[dependency_file]["layer"]
            if dependency_layer != deps["layer"]:
                layer_deps[f"{deps['layer']}->{dependency_layer}"] += 1

    return {
        "summary": {
            "total_files": len(file_deps),
            "files_by_layer": dict(layer_counts),
            "violations": len(violations),
            "circular_dependencies": len(circular),
        },
        "dependencies_by_layer": dict(layer_deps),
        "violations": violations[:20],
        "circular_dependencies": circular[:10],
        "file_dependencies": {
            path: {
                "layer": deps["layer"],
                "import_count": len(deps["imports"]),
                "project_dependency_count": len(deps["project_dependencies"]),
            }
            for path, deps in file_deps.items()
        },
    }


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Check dependency rules in Cam360 project")
    parser.add_argument("--format", choices=["json", "text"], default="json")
    parser.add_argument("--output", "-o")
    parser.add_argument("--check-circular", action="store_true")
    args = parser.parse_args()

    file_deps = analyze_dependencies()
    if not file_deps:
        print("No Swift files found", file=sys.stderr)
        return 1

    violations = check_dependency_rules(file_deps)
    circular = check_circular_dependencies(file_deps) if args.check_circular else []
    report = generate_dependency_report(file_deps, violations, circular)

    if args.format == "json":
        output = json.dumps(report, indent=2, ensure_ascii=False)
    else:
        layers = ", ".join(
            f"{layer}:{count}"
            for layer, count in sorted(report["summary"]["files_by_layer"].items())
        )
        lines = [
            "Dependency Harness Check",
            f"- files: {report['summary']['total_files']} ({layers})",
            f"- boundary violations: {report['summary']['violations']}",
        ]
        if args.check_circular:
            lines.append(f"- circular dependencies: {report['summary']['circular_dependencies']} (advisory)")
        if violations:
            lines.append("- violations:")
            for item in violations[:10]:
                lines.append(f"  {item['file']}: {item['rule']} ({item['dependency']})")
        if circular:
            lines.append("- cycle details: use --format json")
        output = "\n".join(lines)

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Dependency report written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
