#!/usr/bin/env python3
"""Low-noise project API scanner for Cam360.

The hallucination check is intentionally conservative: it only reports
unresolved symbols that look like Cam360 project types. Framework types,
Swift standard library members, enum cases, and ordinary property access are
left to the Swift compiler.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Set, Tuple

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
FUNCTION_DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:static\s+|class\s+)?func\s+(\w+)\s*\(",
    re.MULTILINE,
)
PROPERTY_DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:static\s+|class\s+)?(?:let|var)\s+(\w+)\b",
    re.MULTILINE,
)
INIT_DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:convenience\s+)?init\s*\(",
    re.MULTILINE,
)

FRAMEWORK_OR_SWIFT_TYPES = {
    "Any",
    "AnyObject",
    "Array",
    "Binding",
    "Bool",
    "Button",
    "CGSize",
    "CGFloat",
    "Color",
    "CodingKey",
    "Data",
    "Date",
    "DecodingError",
    "Dictionary",
    "Divider",
    "DispatchQueue",
    "Double",
    "Error",
    "EmptyView",
    "Float",
    "ForEach",
    "Foundation",
    "GeometryProxy",
    "HStack",
    "Image",
    "Int",
    "MainActor",
    "Never",
    "NavigationView",
    "Network",
    "NSObject",
    "NSLock",
    "Option",
    "Optional",
    "PlainButtonStyle",
    "ProcessInfo",
    "Published",
    "Result",
    "RoundedRectangle",
    "ScrollView",
    "Set",
    "Spacer",
    "StackNavigationViewStyle",
    "State",
    "String",
    "SwiftUI",
    "Task",
    "Test",
    "Testing",
    "Text",
    "UUID",
    "URL",
    "UIApplication",
    "UIApplicationDelegate",
    "UIScene",
    "UISceneConfiguration",
    "UISceneSession",
    "UIWindow",
    "UIWindowScene",
    "UserDefaults",
    "VStack",
    "View",
    "ZStack",
}
PROJECT_SUFFIXES = (
    "Action",
    "Button",
    "Card",
    "Client",
    "Command",
    "Configuration",
    "Container",
    "Error",
    "Event",
    "Info",
    "Model",
    "Models",
    "Option",
    "Provider",
    "Repository",
    "Route",
    "Session",
    "State",
    "Store",
    "Transport",
    "View",
)


@dataclass(frozen=True)
class APISignature:
    name: str
    kind: str
    file: str
    line: int
    signature: str = ""
    access: str = "internal"

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "kind": self.kind,
            "file": self.file,
            "line": self.line,
            "signature": self.signature,
            "access": self.access,
        }


def swift_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for pattern in ("Cam360/**/*.swift", "Cam360Tests/**/*.swift"):
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def relative_path(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def line_number(content: str, offset: int) -> int:
    return content[:offset].count("\n") + 1


def extract_access_modifier(line: str) -> str:
    for access in ("public", "open", "private", "fileprivate", "internal"):
        if re.search(rf"\b{access}\b", line):
            return access
    return "internal"


def signature_kind(line: str) -> str:
    for kind in ("class", "struct", "enum", "protocol", "actor"):
        if re.search(rf"\b{kind}\b", line):
            return kind
    return "unknown"


def extract_type_definitions(content: str, file_path: str) -> List[APISignature]:
    types: list[APISignature] = []
    for match in TYPE_DECL_RE.finditer(content):
        line = match.group(0)
        types.append(
            APISignature(
                name=match.group(1),
                kind=signature_kind(line),
                file=file_path,
                line=line_number(content, match.start()),
                access=extract_access_modifier(line),
            )
        )
    for match in TYPEALIAS_DECL_RE.finditer(content):
        line = match.group(0)
        types.append(
            APISignature(
                name=match.group(1),
                kind="typealias",
                file=file_path,
                line=line_number(content, match.start()),
                access=extract_access_modifier(line),
            )
        )
    return types


def extract_function_definitions(content: str, file_path: str) -> List[APISignature]:
    functions: list[APISignature] = []
    for match in FUNCTION_DECL_RE.finditer(content):
        line = match.group(0).strip()
        functions.append(
            APISignature(
                name=match.group(1),
                kind="function",
                file=file_path,
                line=line_number(content, match.start()),
                signature=line,
                access=extract_access_modifier(line),
            )
        )
    return functions


def extract_property_definitions(content: str, file_path: str) -> List[APISignature]:
    properties: list[APISignature] = []
    for match in PROPERTY_DECL_RE.finditer(content):
        line = match.group(0).strip()
        properties.append(
            APISignature(
                name=match.group(1),
                kind="property",
                file=file_path,
                line=line_number(content, match.start()),
                signature=line,
                access=extract_access_modifier(line),
            )
        )
    return properties


def extract_init_definitions(content: str, file_path: str) -> List[APISignature]:
    inits: list[APISignature] = []
    for match in INIT_DECL_RE.finditer(content):
        line = match.group(0).strip()
        inits.append(
            APISignature(
                name="init",
                kind="init",
                file=file_path,
                line=line_number(content, match.start()),
                signature=line,
                access=extract_access_modifier(line),
            )
        )
    return inits


def strip_comments_and_strings(content: str) -> str:
    content = re.sub(r'"""[\s\S]*?"""', '""', content)
    content = re.sub(r'"(?:\\.|[^"\\])*"', '""', content)
    content = re.sub(r"//.*", "", content)
    content = re.sub(r"/\*[\s\S]*?\*/", "", content)
    content = re.sub(r"^\s*(?:@testable\s+)?import\s+\w+.*$", "", content, flags=re.MULTILINE)
    return content


def extract_project_type_usage(content: str) -> Set[str]:
    cleaned = strip_comments_and_strings(content)
    return set(re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", cleaned))


def analyze_project() -> Tuple[Dict[str, List[APISignature]], Dict[str, Set[str]]]:
    file_apis: Dict[str, List[APISignature]] = {}
    file_usage: Dict[str, Set[str]] = {}

    for file_path in swift_files():
        rel_path = relative_path(file_path)
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        apis: list[APISignature] = []
        apis.extend(extract_type_definitions(content, rel_path))
        apis.extend(extract_function_definitions(content, rel_path))
        apis.extend(extract_property_definitions(content, rel_path))
        apis.extend(extract_init_definitions(content, rel_path))
        file_apis[rel_path] = apis
        file_usage[rel_path] = extract_project_type_usage(content)

    return file_apis, file_usage


def build_api_index(file_apis: Dict[str, List[APISignature]]) -> Dict[str, List[Dict]]:
    api_index: Dict[str, List[Dict]] = defaultdict(list)
    for apis in file_apis.values():
        for api in apis:
            api_index[api.name].append(api.to_dict())
    return dict(api_index)


def camel_prefix(name: str) -> str:
    match = re.match(r"[A-Z][a-z0-9]*", name)
    return match.group(0) if match else name


def project_prefixes(defined_types: Set[str]) -> Set[str]:
    prefixes = {camel_prefix(name) for name in defined_types}
    return {prefix for prefix in prefixes if len(prefix) > 2}


def looks_like_project_symbol(name: str, prefixes: Set[str]) -> bool:
    if name in FRAMEWORK_OR_SWIFT_TYPES:
        return False
    if name.startswith("UI") or name.startswith("NS") or name.startswith("CG"):
        return False
    if name in prefixes or camel_prefix(name) in prefixes:
        return True
    return name.endswith(PROJECT_SUFFIXES)


def find_potential_hallucinations(
    file_apis: Dict[str, List[APISignature]],
    file_usage: Dict[str, Set[str]],
) -> List[Dict]:
    defined_types = {
        api.name
        for apis in file_apis.values()
        for api in apis
        if api.kind in {"class", "struct", "enum", "protocol", "actor", "typealias"}
    }
    prefixes = project_prefixes(defined_types)

    hallucinations: list[Dict] = []
    seen: set[tuple[str, str]] = set()
    for file_path, usage in file_usage.items():
        for api_name in sorted(usage):
            key = (file_path, api_name)
            if key in seen or api_name in defined_types:
                continue
            seen.add(key)
            if looks_like_project_symbol(api_name, prefixes):
                hallucinations.append(
                    {
                        "file": file_path,
                        "api_name": api_name,
                        "type": "unresolved_project_symbol",
                    }
                )
    return hallucinations


def generate_report(
    file_apis: Dict[str, List[APISignature]],
    file_usage: Dict[str, Set[str]],
    hallucinations: List[Dict],
) -> Dict:
    total_apis = sum(len(apis) for apis in file_apis.values())
    total_usage = sum(len(usage) for usage in file_usage.values())

    api_kinds = defaultdict(int)
    api_access = defaultdict(int)
    for apis in file_apis.values():
        for api in apis:
            api_kinds[api.kind] += 1
            api_access[api.access] += 1

    return {
        "summary": {
            "total_files": len(file_apis),
            "total_apis": total_apis,
            "total_project_type_references": total_usage,
            "potential_hallucinations": len(hallucinations),
        },
        "api_kinds": dict(api_kinds),
        "api_access": dict(api_access),
        "hallucinations": hallucinations[:20],
        "api_index": build_api_index(file_apis),
    }


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Validate project API usage in Cam360")
    parser.add_argument("--format", choices=["json", "text"], default="json")
    parser.add_argument("--output", "-o")
    parser.add_argument("--check-hallucinations", action="store_true")
    args = parser.parse_args()

    file_apis, file_usage = analyze_project()
    if not file_apis:
        print("No Swift files found", file=sys.stderr)
        return 1

    hallucinations = []
    if args.check_hallucinations:
        hallucinations = find_potential_hallucinations(file_apis, file_usage)

    report = generate_report(file_apis, file_usage, hallucinations)

    if args.format == "json":
        output = json.dumps(report, indent=2, ensure_ascii=False)
    else:
        lines = [
            "API Harness Check",
            f"- files: {report['summary']['total_files']}",
            f"- project APIs: {report['summary']['total_apis']}",
            f"- unresolved project symbols: {report['summary']['potential_hallucinations']}",
        ]
        if hallucinations:
            lines.append("- findings:")
            for item in hallucinations[:10]:
                lines.append(f"  {item['file']}: {item['api_name']}")
        output = "\n".join(lines)

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"API validation report written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
