#!/usr/bin/env python3
"""Impact analysis script for Cam360 project.

Analyzes code changes to determine:
1. Which files are affected
2. Which modules are impacted
3. Which tests need to run
4. Potential risks and dependencies
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


def get_changed_files(days: int = 7) -> List[str]:
    """Get recently changed files."""
    try:
        result = subprocess.run(
            ["git", "-c", "core.quotepath=false", "log", f"--since={days} days ago", 
             "--name-only", "--pretty=format:"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        files = sorted(set(line.strip() for line in result.stdout.splitlines() if line.strip()))
        return files
    except subprocess.SubprocessError:
        return []


def get_staged_changes() -> List[str]:
    """Get staged changes."""
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]
    except subprocess.SubprocessError:
        return []


def get_untracked_changes() -> List[str]:
    """Get untracked files that are not ignored."""
    try:
        result = subprocess.run(
            ["git", "-c", "core.quotepath=false", "ls-files", "--others", "--exclude-standard"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]
    except subprocess.SubprocessError:
        return []


def get_unstaged_changes() -> List[str]:
    """Get unstaged and untracked changes."""
    try:
        result = subprocess.run(
            ["git", "-c", "core.quotepath=false", "diff", "--name-only"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        changed = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        return sorted(set(changed + get_untracked_changes()))
    except subprocess.SubprocessError:
        return get_untracked_changes()


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
    elif file_path.startswith("docs/") or file_path == "README.md" or file_path == "AGENTS.md":
        return "Docs"
    elif file_path.startswith("scripts/"):
        return "Scripts"
    else:
        return "Other"


def extract_dependencies(file_path: str) -> Set[str]:
    """Extract dependencies from a Swift file."""
    dependencies = set()
    full_path = ROOT / file_path
    
    if not full_path.exists() or not file_path.endswith(".swift"):
        return dependencies
    
    try:
        content = full_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return dependencies
    
    # Extract imports
    for match in re.finditer(r'^\s*import\s+(\w+)', content, re.MULTILINE):
        dependencies.add(match.group(1))
    
    # Extract type references (simplified)
    patterns = [
        r':\s*(\w+)',  # Type annotations
        r'as\s+(\w+)',  # Type casting
        r'<(\w+)>',  # Generic types
        r'(\w+)\.self',  # Type references
    ]
    
    for pattern in patterns:
        for match in re.finditer(pattern, content):
            type_name = match.group(1)
            if len(type_name) > 1:
                dependencies.add(type_name)
    
    return dependencies


def find_affected_files(changed_files: List[str]) -> Dict[str, List[str]]:
    """Find files affected by changes."""
    affected = defaultdict(list)
    
    # Build dependency index
    file_deps: Dict[str, Set[str]] = {}
    all_files = []
    
    for pattern in ["Cam360/**/*.swift", "Cam360Tests/**/*.swift"]:
        all_files.extend(ROOT.glob(pattern))
    
    for file_path in all_files:
        rel_path = file_path.relative_to(ROOT).as_posix()
        deps = extract_dependencies(rel_path)
        file_deps[rel_path] = deps
    
    # Find files that depend on changed files
    for changed_file in changed_files:
        if not changed_file.endswith(".swift") or not changed_file.startswith("Cam360/"):
            continue
        
        changed_deps = extract_dependencies(changed_file)
        
        for file_path, deps in file_deps.items():
            if file_path == changed_file:
                continue
            
            # Check if this file depends on changed file
            if changed_file in deps:
                affected[changed_file].append(file_path)
            
            # Check if this file depends on types defined in changed file
            for dep in deps:
                if dep in changed_deps:
                    affected[changed_file].append(file_path)
                    break
    
    return dict(affected)


def find_related_tests(changed_files: List[str]) -> List[str]:
    """Find tests related to changed files."""
    tests = []
    
    for changed_file in changed_files:
        if not changed_file.endswith(".swift"):
            continue
        if changed_file.startswith("Cam360Tests/"):
            tests.append(changed_file)
            continue
        
        # Extract module name
        if "/Features/" in changed_file:
            module_name = changed_file.split("/Features/")[1].split("/")[0]
            test_pattern = f"**/Tests/**/*{module_name}*Test*.swift"
        elif "/Core/" in changed_file:
            module_name = changed_file.split("/Core/")[1].split("/")[0]
            test_pattern = f"**/Tests/**/*{module_name}*Test*.swift"
        else:
            continue
        
        # Find matching test files. This repo keeps tests directly under Cam360Tests.
        for test_file in ROOT.glob(f"Cam360Tests/**/*{module_name}*Tests.swift"):
            tests.append(test_file.relative_to(ROOT).as_posix())
        if not tests and (ROOT / "Cam360Tests" / "Cam360Tests.swift").exists():
            tests.append("Cam360Tests/Cam360Tests.swift")
    
    return sorted(set(tests))


def analyze_impact(changed_files: List[str]) -> Dict:
    """Analyze impact of changes."""
    affected_files = find_affected_files(changed_files)
    related_tests = find_related_tests(changed_files)
    
    # Group by layer
    layers = defaultdict(list)
    for file in changed_files:
        layer = determine_layer(file)
        layers[layer].append(file)
    
    # Count affected files
    total_affected = sum(len(files) for files in affected_files.values())
    
    return {
        "changed_files": changed_files,
        "changed_by_layer": dict(layers),
        "affected_files": affected_files,
        "total_affected_files": total_affected,
        "related_tests": related_tests,
        "risk_assessment": assess_risk(changed_files, affected_files)
    }


def assess_risk(changed_files: List[str], affected_files: Dict[str, List[str]]) -> Dict:
    """Assess risk of changes."""
    risk_factors = []
    risk_level = "low"
    swift_changes = [f for f in changed_files if f.endswith(".swift")]
    source_swift_changes = [f for f in swift_changes if f.startswith("Cam360/")]
    doc_changes = [f for f in changed_files if f.endswith(".md") or f in {"README.md", "AGENTS.md"}]
    script_changes = [f for f in changed_files if f.startswith("scripts/")]
    
    if not swift_changes:
        if script_changes:
            risk_factors.append("Scripts changed; run Python compile checks and target script commands")
            risk_level = "medium"
        elif doc_changes:
            risk_factors.append("Docs-only changes")
        return {
            "level": risk_level,
            "factors": risk_factors,
            "recommendations": get_recommendations(risk_level, risk_factors, changed_files)
        }

    if swift_changes and not source_swift_changes:
        risk_factors.append("Only test Swift files changed")
        risk_level = "medium" if script_changes else "low"
        return {
            "level": risk_level,
            "factors": risk_factors,
            "recommendations": get_recommendations(risk_level, risk_factors, changed_files)
        }

    # Check if changes affect multiple layers
    layers = set()
    for file in changed_files:
        layers.add(determine_layer(file))
    
    if len(layers) > 1:
        risk_factors.append("Changes span multiple architectural layers")
        risk_level = "medium"
    
    # Check if changes affect core components
    core_changes = [f for f in changed_files if "/Core/" in f]
    if core_changes:
        risk_factors.append("Changes affect core components")
        risk_level = "high"
    
    # Check if many files are affected
    total_affected = sum(len(files) for files in affected_files.values())
    if total_affected > 10:
        risk_factors.append(f"Changes affect {total_affected} other files")
        risk_level = "high"
    
    # Check if tests are missing
    related_tests = find_related_tests(changed_files)
    if not related_tests:
        risk_factors.append("No related tests found")
        if risk_level == "low":
            risk_level = "medium"
    
    return {
        "level": risk_level,
        "factors": risk_factors,
        "recommendations": get_recommendations(risk_level, risk_factors, changed_files)
    }


def get_recommendations(risk_level: str, risk_factors: List[str], changed_files: List[str]) -> List[str]:
    """Get recommendations based on risk assessment."""
    recommendations = []
    swift_changes = [f for f in changed_files if f.endswith(".swift")]
    source_swift_changes = [f for f in swift_changes if f.startswith("Cam360/")]
    doc_changes = [f for f in changed_files if f.endswith(".md") or f in {"README.md", "AGENTS.md"}]
    script_changes = [f for f in changed_files if f.startswith("scripts/")]

    if doc_changes:
        recommendations.append("Run git diff --check")
        recommendations.append("Run docs link check")

    if script_changes:
        recommendations.append("Run python3 -m py_compile scripts/*.py")
        recommendations.append("Run changed script commands")

    if swift_changes and not source_swift_changes:
        recommendations.append("Run related tests")
        return recommendations

    if not swift_changes:
        return recommendations
    
    if risk_level == "high":
        recommendations.append("Run full test suite")
        recommendations.append("Conduct thorough code review")
        recommendations.append("Consider rollback plan")
    
    if risk_level == "medium":
        recommendations.append("Run related tests")
        recommendations.append("Review affected files")
    
    if "No related tests found" in risk_factors:
        recommendations.append("Add tests for changed functionality")
    
    if "Changes affect core components" in risk_factors:
        recommendations.append("Verify core functionality")
        recommendations.append("Check integration points")
    
    return recommendations


def generate_impact_report(impact: Dict) -> str:
    """Generate impact analysis report."""
    lines = []
    lines.append("Impact Harness Check")
    lines.append(f"- Changed files: {len(impact['changed_files'])}")
    lines.append(f"- Affected files: {impact['total_affected_files']}")
    lines.append(f"- Related tests: {len(impact['related_tests'])}")
    lines.append(f"- Risk level: {impact['risk_assessment']['level']}")
    lines.append("- Changed by layer:")
    for layer, files in impact['changed_by_layer'].items():
        lines.append(f"  {layer}: {len(files)}")
    if impact['related_tests']:
        lines.append("- Related tests:")
        for test in impact['related_tests']:
            lines.append(f"  {test}")
    if impact['risk_assessment']['factors']:
        lines.append("- Risk factors:")
        for factor in impact['risk_assessment']['factors']:
            lines.append(f"  {factor}")
    if impact['risk_assessment']['recommendations']:
        lines.append("- Recommendations:")
        for rec in impact['risk_assessment']['recommendations']:
            lines.append(f"  {rec}")
    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Analyze impact of code changes")
    parser.add_argument("--action", choices=["analyze", "staged", "unstaged", "recent"],
                       default="recent", help="What to analyze")
    parser.add_argument("--days", type=int, default=7,
                       help="Days to look back for recent changes")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                       help="Output format")
    parser.add_argument("--output", "-o", help="Output file")
    args = parser.parse_args()
    
    # Get files to analyze
    if args.action == "staged":
        files = get_staged_changes()
    elif args.action == "unstaged":
        files = get_unstaged_changes()
    elif args.action == "recent":
        files = get_changed_files(args.days)
    else:
        # Analyze all changes
        staged = get_staged_changes()
        unstaged = get_unstaged_changes()
        files = list(set(staged + unstaged))
    
    if not files:
        print("No changes found", file=sys.stderr)
        return 0
    
    # Analyze impact
    impact = analyze_impact(files)
    
    # Output results
    if args.format == "json":
        output = json.dumps(impact, indent=2, ensure_ascii=False)
    else:
        output = generate_impact_report(impact)
    
    if args.output:
        pathlib.Path(args.output).write_text(output, encoding="utf-8")
        print(f"Impact analysis written to {args.output}", file=sys.stderr)
    else:
        print(output)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
