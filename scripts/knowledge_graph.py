#!/usr/bin/env python3
"""Generate a knowledge graph of the Cam360 project for AI context.

Analyzes Swift source files to extract:
- Module dependencies (import statements)
- Type definitions (classes, structs, enums, protocols)
- Function definitions and calls
- Architecture layers (App, Core, Features)

Output: JSON graph suitable for visualization or AI context injection.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from collections import defaultdict
from typing import Dict, List, Set, Tuple

ROOT = pathlib.Path(__file__).resolve().parent.parent


def swift_files() -> list[pathlib.Path]:
    """Find all Swift files in the project."""
    patterns = ["Cam360/**/*.swift", "Cam360Tests/**/*.swift"]
    files = []
    for pattern in patterns:
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def relative_path(path: pathlib.Path) -> str:
    """Get path relative to project root."""
    return path.relative_to(ROOT).as_posix()


def extract_imports(content: str) -> Set[str]:
    """Extract import statements from Swift code."""
    imports = set()
    for match in re.finditer(r'^\s*import\s+(\w+)', content, re.MULTILINE):
        imports.add(match.group(1))
    return imports


def extract_types(content: str, file_path: str) -> List[Dict]:
    """Extract type definitions from Swift code."""
    types = []
    # Match class, struct, enum, protocol definitions
    pattern = r'^\s*(?:public|internal|private|fileprivate)?\s*(?:final\s+|indirect\s+)?(?:class|struct|enum|protocol|actor)\s+(\w+)'
    for match in re.finditer(pattern, content, re.MULTILINE):
        type_name = match.group(1)
        # Determine type kind from the match
        kind = "unknown"
        if "class " in match.group(0):
            kind = "class"
        elif "struct " in match.group(0):
            kind = "struct"
        elif "enum " in match.group(0):
            kind = "enum"
        elif "protocol " in match.group(0):
            kind = "protocol"
        elif "actor " in match.group(0):
            kind = "actor"
        
        types.append({
            "name": type_name,
            "kind": kind,
            "file": file_path,
            "line": content[:match.start()].count('\n') + 1
        })
    return types


def extract_functions(content: str, file_path: str) -> List[Dict]:
    """Extract function definitions from Swift code."""
    functions = []
    # Match function definitions
    pattern = r'^\s*(?:public|internal|private|fileprivate)?\s*(?:static\s+)?(?:func|init)\s+(\w+)?'
    for match in re.finditer(pattern, content, re.MULTILINE):
        func_name = match.group(1) if match.group(1) else "init"
        functions.append({
            "name": func_name,
            "file": file_path,
            "line": content[:match.start()].count('\n') + 1
        })
    return functions


def extract_function_calls(content: str) -> Set[str]:
    """Extract function calls from Swift code."""
    calls = set()
    # Simple pattern for function calls (not perfect but reasonable)
    pattern = r'\b(\w+)\s*\('
    for match in re.finditer(pattern, content):
        call = match.group(1)
        # Filter out common Swift keywords that look like function calls
        keywords = {"if", "for", "while", "switch", "return", "func", "var", "let", "class", "struct", "enum", "protocol"}
        if call not in keywords and len(call) > 1:
            calls.add(call)
    return calls


def determine_layer(file_path: str) -> str:
    """Determine which architectural layer a file belongs to."""
    if file_path.startswith("Cam360/App/"):
        return "App"
    elif file_path.startswith("Cam360/Core/"):
        return "Core"
    elif file_path.startswith("Cam360/Features/"):
        return "Features"
    elif file_path.startswith("Cam360Tests/"):
        return "Tests"
    else:
        return "Other"


def analyze_dependencies(files: list[pathlib.Path]) -> Dict:
    """Analyze dependencies between files and modules."""
    # file -> set of imports
    file_imports: Dict[str, Set[str]] = {}
    # file -> list of types
    file_types: Dict[str, List[Dict]] = {}
    # file -> list of functions
    file_functions: Dict[str, List[Dict]] = {}
    # file -> set of function calls
    file_calls: Dict[str, Set[str]] = {}
    # layer -> set of files
    layer_files: Dict[str, Set[str]] = defaultdict(set)
    
    for file_path in files:
        rel_path = relative_path(file_path)
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        
        imports = extract_imports(content)
        types = extract_types(content, rel_path)
        functions = extract_functions(content, rel_path)
        calls = extract_function_calls(content)
        layer = determine_layer(rel_path)
        
        file_imports[rel_path] = imports
        file_types[rel_path] = types
        file_functions[rel_path] = functions
        file_calls[rel_path] = calls
        layer_files[layer].add(rel_path)
    
    return {
        "file_imports": file_imports,
        "file_types": file_types,
        "file_functions": file_functions,
        "file_calls": file_calls,
        "layer_files": dict(layer_files)
    }


def build_graph(analysis: Dict) -> Dict:
    """Build a knowledge graph from the analysis."""
    nodes = []
    edges = []
    
    # Create nodes for each file
    for file_path in analysis["file_imports"]:
        layer = determine_layer(file_path)
        node_id = file_path.replace("/", "_").replace(".", "_")
        nodes.append({
            "id": node_id,
            "label": file_path.split("/")[-1],
            "type": "file",
            "layer": layer,
            "path": file_path
        })
    
    # Create nodes for each type
    for file_path, types in analysis["file_types"].items():
        for type_info in types:
            node_id = f"{file_path}_{type_info['name']}".replace("/", "_").replace(".", "_")
            nodes.append({
                "id": node_id,
                "label": type_info["name"],
                "type": type_info["kind"],
                "file": file_path,
                "line": type_info["line"]
            })
            # Edge from type to file
            file_node_id = file_path.replace("/", "_").replace(".", "_")
            edges.append({
                "source": node_id,
                "target": file_node_id,
                "relation": "defined_in"
            })
    
    # Create edges for imports (dependencies)
    for file_path, imports in analysis["file_imports"].items():
        file_node_id = file_path.replace("/", "_").replace(".", "_")
        for import_name in imports:
            # Find files that might provide this import
            # This is simplified - in reality we'd need module mapping
            pass
    
    # Create edges for function calls (simplified)
    # This is a basic implementation - could be enhanced with actual call graph analysis
    
    return {
        "nodes": nodes,
        "edges": edges,
        "metadata": {
            "total_files": len(analysis["file_imports"]),
            "total_types": sum(len(types) for types in analysis["file_types"].values()),
            "total_functions": sum(len(funcs) for funcs in analysis["file_functions"].values()),
            "layers": {layer: len(files) for layer, files in analysis["layer_files"].items()}
        }
    }


def generate_dot(graph: Dict) -> str:
    """Generate DOT format for Graphviz visualization."""
    lines = ["digraph Cam360 {", "  rankdir=LR;", "  node [shape=record];", ""]
    
    # Add nodes
    for node in graph["nodes"]:
        node_id = node["id"]
        label = node["label"]
        node_type = node["type"]
        
        if node_type == "file":
            color = "lightblue"
            shape = "box"
        elif node_type in ["class", "struct"]:
            color = "lightgreen"
            shape = "ellipse"
        elif node_type == "protocol":
            color = "lightyellow"
            shape = "diamond"
        elif node_type == "enum":
            color = "lightpink"
            shape = "hexagon"
        else:
            color = "white"
            shape = "ellipse"
        
        lines.append(f'  {node_id} [label="{label}", fillcolor={color}, style=filled, shape={shape}];')
    
    lines.append("")
    
    # Add edges
    for edge in graph["edges"]:
        source = edge["source"]
        target = edge["target"]
        relation = edge["relation"]
        lines.append(f'  {source} -> {target} [label="{relation}"];')
    
    lines.append("}")
    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate Cam360 knowledge graph")
    parser.add_argument("--format", choices=["json", "dot"], default="json",
                       help="Output format (default: json)")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    args = parser.parse_args()
    
    # Analyze project
    files = swift_files()
    if not files:
        print("No Swift files found", file=sys.stderr)
        return 1
    
    analysis = analyze_dependencies(files)
    graph = build_graph(analysis)
    
    # Output results
    if args.format == "json":
        output = json.dumps(graph, indent=2, ensure_ascii=False)
    else:
        output = generate_dot(graph)
    
    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Knowledge graph written to {args.output}", file=sys.stderr)
    else:
        print(output)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
