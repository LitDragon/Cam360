#!/usr/bin/env python3
"""Test coverage analysis script for Cam360 project.

Analyzes test coverage to:
1. Identify untested code
2. Generate coverage reports
3. Suggest areas needing tests
4. Track coverage trends
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
from collections import defaultdict
from typing import Dict, List, Set, Tuple

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
    
    # Analyze coverage
    coverage = analyze_coverage(source_files, test_files, all_test_methods)
    
    return {
        "source_files": source_files,
        "test_files": test_files,
        "coverage": coverage,
        "summary": {
            "total_source_files": len(source_files),
            "total_test_files": len(test_files),
            "total_functions": sum(f["function_count"] for f in source_files.values()),
            "total_types": sum(f["type_count"] for f in source_files.values()),
            "total_test_methods": len(all_test_methods)
        }
    }


def analyze_coverage(source_files: Dict[str, Dict], 
                     test_files: Dict[str, Dict],
                     all_test_methods: Set[str]) -> Dict:
    """Analyze test coverage based on naming conventions."""
    # Simple heuristic: check if test files exist for source files
    covered_files = []
    uncovered_files = []
    
    for source_file in source_files:
        # Extract module name from path
        if "/Features/" in source_file:
            module_name = source_file.split("/Features/")[1].split("/")[0]
        elif "/Core/" in source_file:
            module_name = source_file.split("/Core/")[1].split("/")[0]
        else:
            module_name = pathlib.Path(source_file).stem
        
        # Check if test file exists
        has_tests = False
        for test_file in test_files:
            if module_name.lower() in test_file.lower():
                has_tests = True
                break
        
        if has_tests:
            covered_files.append(source_file)
        else:
            uncovered_files.append(source_file)
    
    # Check function coverage (simplified)
    covered_functions = 0
    total_functions = 0
    
    for source_file, info in source_files.items():
        total_functions += info["function_count"]
        
        # Check if any test method references this function
        for func in info["functions"]:
            for test_method in all_test_methods:
                if func.lower() in test_method.lower():
                    covered_functions += 1
                    break
    
    # Calculate coverage percentages
    file_coverage = len(covered_files) / len(source_files) * 100 if source_files else 0
    function_coverage = covered_functions / total_functions * 100 if total_functions else 0
    
    return {
        "covered_files": covered_files,
        "uncovered_files": uncovered_files,
        "file_coverage_percent": round(file_coverage, 2),
        "function_coverage_percent": round(function_coverage, 2),
        "covered_functions": covered_functions,
        "total_functions": total_functions
    }


def generate_coverage_report(analysis: Dict) -> str:
    """Generate test coverage report."""
    lines = []
    lines.append("Test Inventory Check")
    lines.append(f"- Source files: {analysis['summary']['total_source_files']}")
    lines.append(f"- Test files: {analysis['summary']['total_test_files']}")
    lines.append(f"- @Test methods: {analysis['summary']['total_test_methods']}")
    lines.append(f"- Heuristic file signal: {analysis['coverage']['file_coverage_percent']}%")
    if not analysis['test_files']:
        lines.append("- Recommendation: add test files")
    if analysis['coverage']['uncovered_files']:
        lines.append(f"- Review before behavior changes: {len(analysis['coverage']['uncovered_files'])} heuristic gaps")
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
        file_coverage = analysis['coverage']['file_coverage_percent']
        function_coverage = analysis['coverage']['function_coverage_percent']
        
        issues = []
        if file_coverage < args.min_file_coverage:
            issues.append(f"File coverage {file_coverage}% is below minimum {args.min_file_coverage}%")
        if function_coverage < args.min_function_coverage:
            issues.append(f"Function coverage {function_coverage}% is below minimum {args.min_function_coverage}%")
        
        if issues:
            print("Coverage heuristic warnings:", file=sys.stderr)
            for issue in issues:
                print(f"  - {issue}", file=sys.stderr)
            return 0
        else:
            print("Coverage heuristic thresholds satisfied", file=sys.stderr)
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
