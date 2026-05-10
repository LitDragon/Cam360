#!/usr/bin/env python3
"""Test inventory and xccov coverage gate for Cam360."""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
from typing import Dict, List, Optional, Set

ROOT = pathlib.Path(__file__).resolve().parent.parent


def find_swift_files() -> List[pathlib.Path]:
    files: List[pathlib.Path] = []
    for pattern in ("Cam360/**/*.swift",):
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def find_test_files() -> List[pathlib.Path]:
    files: List[pathlib.Path] = []
    for pattern in ("Cam360Tests/**/*.swift",):
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def relative_path(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def extract_functions(content: str) -> List[str]:
    return re.findall(
        r"^\s*(?:public|internal|private|fileprivate)?\s*(?:static\s+)?func\s+(\w+)",
        content,
        re.MULTILINE,
    )


def extract_types(content: str) -> List[str]:
    return re.findall(
        r"^\s*(?:public|internal|private|fileprivate)?\s*(?:final\s+)?"
        r"(?:class|struct|enum|protocol|actor)\s+(\w+)",
        content,
        re.MULTILINE,
    )


def extract_test_methods(content: str) -> List[str]:
    return re.findall(r"^\s*@Test(?:\([^)]*\))?\s*\n\s*func\s+(\w+)\s*\(", content, re.MULTILINE)


def analyze_test_inventory() -> Dict:
    source_files: Dict[str, Dict] = {}
    for file_path in find_swift_files():
        rel_path = relative_path(file_path)
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        functions = extract_functions(content)
        types = extract_types(content)
        source_files[rel_path] = {
            "functions": functions,
            "types": types,
            "function_count": len(functions),
            "type_count": len(types),
        }

    test_files: Dict[str, Dict] = {}
    all_test_methods: Set[str] = set()
    for file_path in find_test_files():
        rel_path = relative_path(file_path)
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        test_methods = extract_test_methods(content)
        test_files[rel_path] = {
            "test_methods": test_methods,
            "test_count": len(test_methods),
        }
        all_test_methods.update(test_methods)

    reminders = [
        "This inventory is not coverage. Use --xcresult or --xccov-json for executable coverage.",
        "Inspect existing @Test names and source behavior before changing non-UI code.",
    ]
    if not test_files:
        reminders.insert(0, "No Swift Testing files found.")
    elif len(test_files) <= 4:
        reminders.insert(
            0,
            f"Tests are concentrated in {len(test_files)} file(s); do not infer per-feature coverage from file names.",
        )

    return {
        "mode": "inventory",
        "source_files": source_files,
        "test_files": test_files,
        "risk_assessment": {
            "test_files": sorted(test_files.keys()),
            "test_method_count": len(all_test_methods),
            "reminders": reminders,
        },
        "summary": {
            "total_source_files": len(source_files),
            "total_test_files": len(test_files),
            "total_functions": sum(item["function_count"] for item in source_files.values()),
            "total_types": sum(item["type_count"] for item in source_files.values()),
            "total_test_methods": len(all_test_methods),
        },
    }


def load_xccov_json(xccov_json: pathlib.Path) -> Dict:
    return json.loads(xccov_json.read_text(encoding="utf-8"))


def load_xcresult_report(xcresult: pathlib.Path) -> Dict:
    result = subprocess.run(
        ["xcrun", "xccov", "view", "--report", "--json", str(xcresult)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "xcrun xccov failed")
    return json.loads(result.stdout)


def normalize_source_path(path_value: str) -> Optional[str]:
    if not path_value:
        return None
    path = pathlib.Path(path_value)
    if path.is_absolute():
        try:
            return path.resolve().relative_to(ROOT).as_posix()
        except (OSError, ValueError):
            pass

    value = path_value.replace("\\", "/")
    if value.startswith("Cam360/") or value.startswith("Cam360Tests/"):
        return value
    marker = "/Cam360/Cam360/"
    if marker in value:
        return "Cam360/" + value.split(marker, 1)[1]
    marker = "/Cam360/Cam360Tests/"
    if marker in value:
        return "Cam360Tests/" + value.split(marker, 1)[1]
    return None


def is_source_file(path_value: str) -> bool:
    normalized = normalize_source_path(path_value)
    return bool(normalized and normalized.startswith("Cam360/") and normalized.endswith(".swift"))


def percent(value: Optional[float]) -> Optional[float]:
    if value is None:
        return None
    return round(value * 100.0, 2)


def coverage_ratio(item: Dict) -> Optional[float]:
    executable = item.get("executableLines")
    covered = item.get("coveredLines")
    if isinstance(executable, (int, float)) and executable > 0 and isinstance(covered, (int, float)):
        return float(covered) / float(executable)
    value = item.get("lineCoverage")
    if isinstance(value, (int, float)):
        return float(value)
    return None


def source_coverage_files(report: Dict) -> List[Dict]:
    files: List[Dict] = []
    for target in report.get("targets", []):
        target_name = target.get("name", "")
        if "Tests" in target_name or target_name.endswith(".xctest"):
            continue
        for file_item in target.get("files", []):
            normalized = normalize_source_path(file_item.get("path") or file_item.get("name", ""))
            if normalized and is_source_file(normalized):
                ratio = coverage_ratio(file_item)
                files.append(
                    {
                        "path": normalized,
                        "covered_lines": int(file_item.get("coveredLines") or 0),
                        "executable_lines": int(file_item.get("executableLines") or 0),
                        "line_coverage": percent(ratio),
                    }
                )
    return sorted(files, key=lambda item: item["path"])


def target_fallback_coverage(report: Dict) -> Optional[Dict]:
    for target in report.get("targets", []):
        name = target.get("name", "")
        if "Tests" in name or name.endswith(".xctest"):
            continue
        ratio = coverage_ratio(target)
        if ratio is None:
            continue
        return {
            "covered_lines": int(target.get("coveredLines") or 0),
            "executable_lines": int(target.get("executableLines") or 0),
            "line_coverage": percent(ratio),
        }
    return None


def analyze_xccov_report(report: Dict) -> Dict:
    files = source_coverage_files(report)
    covered_lines = sum(item["covered_lines"] for item in files)
    executable_lines = sum(item["executable_lines"] for item in files)

    if executable_lines > 0:
        line_coverage = round(covered_lines / executable_lines * 100.0, 2)
    elif files:
        available = [item["line_coverage"] for item in files if item["line_coverage"] is not None]
        line_coverage = round(sum(available) / len(available), 2) if available else 0.0
    else:
        fallback = target_fallback_coverage(report)
        if fallback is None:
            line_coverage = 0.0
            covered_lines = 0
            executable_lines = 0
        else:
            line_coverage = fallback["line_coverage"]
            covered_lines = fallback["covered_lines"]
            executable_lines = fallback["executable_lines"]

    return {
        "mode": "xccov",
        "summary": {
            "source_files": len(files),
            "covered_lines": covered_lines,
            "executable_lines": executable_lines,
            "line_coverage": line_coverage,
        },
        "files": files,
    }


def generate_inventory_report(analysis: Dict) -> str:
    lines = [
        "Test Inventory Check",
        f"- Source files: {analysis['summary']['total_source_files']}",
        f"- Test files: {analysis['summary']['total_test_files']}",
        f"- @Test methods: {analysis['summary']['total_test_methods']}",
        "- Coverage mode: inventory only; pass --xcresult or --xccov-json for xccov coverage",
    ]
    if analysis["test_files"]:
        lines.append("- Test files:")
        for test_file in sorted(analysis["test_files"]):
            lines.append(f"  {test_file}: {analysis['test_files'][test_file]['test_count']}")
    lines.append("- Risk reminders:")
    for reminder in analysis["risk_assessment"]["reminders"]:
        lines.append(f"  {reminder}")
    return "\n".join(lines)


def generate_coverage_report(analysis: Dict) -> str:
    summary = analysis["summary"]
    lines = [
        "Coverage Check",
        "- Coverage mode: xccov",
        f"- Source files: {summary['source_files']}",
        f"- Line coverage: {summary['line_coverage']:.2f}%",
    ]
    if summary["executable_lines"]:
        lines.append(f"- Covered lines: {summary['covered_lines']}/{summary['executable_lines']}")
    if analysis["files"]:
        lowest = sorted(
            (item for item in analysis["files"] if item["line_coverage"] is not None),
            key=lambda item: item["line_coverage"],
        )[:5]
        if lowest:
            lines.append("- Lowest source files:")
            for item in lowest:
                lines.append(f"  {item['path']}: {item['line_coverage']:.2f}%")
    return "\n".join(lines)


def enforce_thresholds(analysis: Dict, min_line_coverage: float, min_file_coverage: float) -> List[str]:
    failures: List[str] = []
    line_coverage = analysis["summary"]["line_coverage"]
    if line_coverage < min_line_coverage:
        failures.append(f"line coverage {line_coverage:.2f}% < {min_line_coverage:.2f}%")
    if min_file_coverage > 0:
        for item in analysis["files"]:
            item_coverage = item["line_coverage"]
            if item_coverage is not None and item_coverage < min_file_coverage:
                failures.append(f"{item['path']} coverage {item_coverage:.2f}% < {min_file_coverage:.2f}%")
    return failures


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Analyze Cam360 test inventory or xccov coverage")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--output", "-o")
    parser.add_argument("--xcresult", help="Path to an .xcresult bundle produced with -enableCodeCoverage YES")
    parser.add_argument("--xccov-json", help="Path to xcrun xccov view --report --json output")
    parser.add_argument("--check-coverage", action="store_true", help="Fail if xccov coverage is missing or below threshold")
    parser.add_argument("--min-line-coverage", type=float, default=1.0)
    parser.add_argument("--min-file-coverage", type=float, default=0.0)
    parser.add_argument("--min-function-coverage", type=float, default=0.0, help="Reserved for future xccov function gates")
    args = parser.parse_args()

    if args.xcresult and args.xccov_json:
        print("Use only one of --xcresult or --xccov-json", file=sys.stderr)
        return 2

    if args.xcresult:
        try:
            analysis = analyze_xccov_report(load_xcresult_report(pathlib.Path(args.xcresult)))
        except (OSError, RuntimeError, json.JSONDecodeError) as error:
            print(f"Unable to read xcresult coverage: {error}", file=sys.stderr)
            return 1
    elif args.xccov_json:
        try:
            analysis = analyze_xccov_report(load_xccov_json(pathlib.Path(args.xccov_json)))
        except (OSError, json.JSONDecodeError) as error:
            print(f"Unable to read xccov JSON: {error}", file=sys.stderr)
            return 1
    else:
        if args.check_coverage:
            print("Coverage check requires --xcresult or --xccov-json", file=sys.stderr)
            return 1
        analysis = analyze_test_inventory()

    if args.check_coverage:
        failures = enforce_thresholds(analysis, args.min_line_coverage, args.min_file_coverage)
        if failures:
            for failure in failures:
                print(f"Coverage failure: {failure}", file=sys.stderr)
            return 1

    output = (
        json.dumps(analysis, indent=2, ensure_ascii=False)
        if args.format == "json"
        else generate_coverage_report(analysis)
        if analysis["mode"] == "xccov"
        else generate_inventory_report(analysis)
    )

    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Coverage report written to {args.output}", file=sys.stderr)
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
