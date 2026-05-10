#!/usr/bin/env python3
"""Test inventory and risk signal script for Cam360 project.

This script does not compute real line, file, or function coverage. It keeps a
low-noise inventory of Swift Testing files and reminds AI agents to inspect the
actual tests before changing behavior.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Dict, List, Set

ROOT = pathlib.Path(__file__).resolve().parent.parent


def find_swift_files() -> List[pathlib.Path]:
    """Find all Swift source files (excluding tests)."""
    patterns = ["Cam360/**/*.swift"]
    files = []
    for pattern in patterns:
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def find_test_files() -> List[pathlib.Path]:
    """Find all Swift test files."""
    patterns = ["Cam360Tests/**/*.swift"]
    files = []
    for pattern in patterns:
        files.extend(ROOT.glob(pattern))
    return sorted(files)


def relative_path(path: pathlib.Path) -> str:
    """Get path relative to project root."""
    return path.relative_to(ROOT).as_posix()


def extract_functions(content: str) -> List[str]:
    """Extract function names from Swift code."""
    functions = []
    pattern = r'^\s*(?:public|internal|private|fileprivate)?\s*(?:static\s+)?func\s+(\w+)'
    for match in re.finditer(pattern, content, re.MULTILINE):
        functions.append(match.group(1))
    return functions


def extract_types(content: str) -> List[str]:
    """Extract type names from Swift code."""
    types = []
    pattern = r'^\s*(?:public|internal|private|fileprivate)?\s*(?:final\s+)?(?:class|struct|enum|protocol|actor)\s+(\w+)'
    for match in re.finditer(pattern, content, re.MULTILINE):
        types.append(match.group(1))
    return types


def extract_test_methods(content: str) -> List[str]:
    """Extract Swift Testing @Test method names."""
    methods = []
    pattern = r'^\s*@Test(?:\([^)]*\))?\s*\n\s*func\s+(\w+)\s*\('
    for match in re.finditer(pattern, content, re.MULTILINE):
        methods.append(match.group(1))
    return methods


def analyze_test_coverage() -> Dict:
    """Analyze test coverage."""
    # Source files and their functions
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
            "type_count": len(types)
        }
    
    # Test files and their test methods
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
            "test_count": len(test_methods)
        }
        all_test_methods.update(test_methods)
    
    # Build risk reminders without pretending this is executable coverage.
    risk_assessment = build_risk_assessment(test_files, all_test_methods)

    return {
        "source_files": source_files,
        "test_files": test_files,
        "risk_assessment": risk_assessment,
        "summary": {
            "total_source_files": len(source_files),
            "total_test_files": len(test_files),
            "total_functions": sum(f["function_count"] for f in source_files.values()),
            "total_types": sum(f["type_count"] for f in source_files.values()),
            "total_test_methods": len(all_test_methods)
        }
    }


def build_risk_assessment(test_files: Dict[str, Dict], all_test_methods: Set[str]) -> Dict:
    """Build test inventory reminders without naming-based coverage heuristics."""
    reminders = [
        "This is an inventory signal, not a coverage report.",
        "Inspect existing @Test names and source behavior before adding or changing non-UI code.",
        "For behavior changes, run the related Swift Testing cases or xcodebuild test.",
    ]
    if not test_files:
        reminders.insert(0, "No Swift Testing files found.")
    elif len(test_files) <= 4:
        reminders.insert(
            0,
            f"Tests are concentrated in {len(test_files)} file(s); do not infer per-feature coverage from file names.",
        )

    return {
        "test_files": sorted(test_files.keys()),
        "test_method_count": len(all_test_methods),
        "reminders": reminders,
    }


def generate_coverage_report(analysis: Dict) -> str:
    """Generate test inventory report."""
    lines = []
    lines.append("Test Inventory Check")
    lines.append(f"- Source files: {analysis['summary']['total_source_files']}")
    lines.append(f"- Test files: {analysis['summary']['total_test_files']}")
    lines.append(f"- @Test methods: {analysis['summary']['total_test_methods']}")
    lines.append("- Coverage mode: inventory only; no heuristic percentage")
    if not analysis['test_files']:
        lines.append("- Recommendation: add test files")
    else:
        lines.append("- Test files:")
        for test_file in sorted(analysis['test_files']):
            count = analysis['test_files'][test_file]['test_count']
            lines.append(f"  {test_file}: {count}")
    lines.append("- Risk reminders:")
    for reminder in analysis['risk_assessment']['reminders']:
        lines.append(f"  {reminder}")
    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Analyze test coverage for Cam360 project")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                       help="Output format")
    parser.add_argument("--output", "-o", help="Output file")
    parser.add_argument("--check-coverage", action="store_true",
                       help="Print heuristic threshold warnings without failing")
    parser.add_argument("--min-file-coverage", type=float, default=80.0,
                       help="Minimum file coverage percentage")
    parser.add_argument("--min-function-coverage", type=float, default=70.0,
                       help="Minimum function coverage percentage")
    args = parser.parse_args()
    
    # Analyze coverage
    analysis = analyze_test_coverage()
    
    # Check thresholds if requested
    if args.check_coverage:
        print("Coverage thresholds are not computed by this inventory script.", file=sys.stderr)
        for reminder in analysis['risk_assessment']['reminders']:
            print(f"  - {reminder}", file=sys.stderr)
        return 0
    
    # Output results
    if args.format == "json":
        output = json.dumps(analysis, indent=2, ensure_ascii=False)
    else:
        output = generate_coverage_report(analysis)
    
    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Coverage report written to {args.output}", file=sys.stderr)
    else:
        print(output)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
