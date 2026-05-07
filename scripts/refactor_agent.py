#!/usr/bin/env python3
"""Small, guarded refactor agent for the Cam360 GitHub workflow.

The script intentionally avoids third-party dependencies so it can run on
GitHub-hosted macOS runners before the project has a separate tooling stack.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import json
import os
import pathlib
import re
import subprocess
import sys
import textwrap
import urllib.error
import urllib.request
import urllib.parse
from typing import Iterable


ROOT = pathlib.Path.cwd()


@dataclasses.dataclass(frozen=True)
class Finding:
    rule_id: str
    severity: str
    path: str
    line: int
    message: str
    snippet: str


def rel(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_text(path: pathlib.Path, limit: int | None = None) -> str:
    data = path.read_text(encoding="utf-8", errors="replace")
    if limit is not None and len(data) > limit:
        return data[:limit] + "\n...[truncated]\n"
    return data


def write_text(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def run_command(command: list[str] | str, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        shell=isinstance(command, str),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if check and result.returncode != 0:
        raise RuntimeError(result.stdout.strip())
    return result


def bool_arg(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "y"}


def load_config(path: pathlib.Path) -> dict:
    return json.loads(read_text(path))


def git_tracked_files() -> list[str]:
    try:
        result = run_command(["git", "ls-files"], check=True)
    except RuntimeError:
        return []
    return [line for line in result.stdout.splitlines() if line]


def path_matches_prefixes(path_rel: str, prefixes: Iterable[str]) -> bool:
    for prefix in prefixes:
        normalized = prefix.rstrip("/")
        if path_rel == normalized or path_rel.startswith(normalized + "/"):
            return True
    return False


def swift_files(config: dict) -> list[pathlib.Path]:
    scan_paths = tuple(config.get("scan_paths", []))
    files = git_tracked_files()
    if files:
        candidates = [ROOT / item for item in files]
    else:
        candidates = []
        for item in scan_paths:
            base = ROOT / item
            if base.exists():
                candidates.extend(base.rglob("*.swift"))

    result: list[pathlib.Path] = []
    for path in candidates:
        path_rel = rel(path)
        if not path_rel.endswith(".swift"):
            continue
        if scan_paths and not path_matches_prefixes(path_rel, scan_paths):
            continue
        result.append(path)
    return sorted(result)


def add_finding(
    findings: list[Finding],
    rule_id: str,
    severity: str,
    path: str,
    line: int,
    message: str,
    snippet: str,
) -> None:
    findings.append(
        Finding(
            rule_id=rule_id,
            severity=severity,
            path=path,
            line=line,
            message=message,
            snippet=snippet.strip(),
        )
    )


def scan(config: dict) -> list[Finding]:
    kind = config.get("agent_kind", "refactor")
    if kind == "build":
        return scan_build(config)
    if kind == "docs":
        return scan_docs(config)
    return scan_refactor(config)


def scan_refactor(config: dict) -> list[Finding]:
    findings: list[Finding] = []
    for path in swift_files(config):
        path_rel = rel(path)
        try:
            content = read_text(path)
        except OSError:
            continue
        lines = content.splitlines()

        if len(lines) > 450 and "/Features/" in path_rel:
            add_finding(
                findings,
                "oversized_feature_file",
                "P3",
                path_rel,
                1,
                "Feature file is large enough to make future real-data wiring risky.",
                f"{len(lines)} lines",
            )

        for index, line in enumerate(lines, start=1):
            stripped = line.strip()
            if path_rel.startswith("Cam360/Features/") and re.match(r"import\s+(Network|NetworkExtension)\b", stripped):
                add_finding(
                    findings,
                    "feature_imports_transport",
                    "P1",
                    path_rel,
                    index,
                    "Feature layer imports transport APIs; repo docs keep device transport under Core/AppContainer boundaries.",
                    stripped,
                )
            if path_rel.startswith("Cam360/Features/") and re.search(r"\b(DeviceProtocolClient|DeviceProtocolTransport|NetworkDeviceProtocolTransport)\b", line):
                add_finding(
                    findings,
                    "feature_reaches_protocol_layer",
                    "P1",
                    path_rel,
                    index,
                    "Feature layer reaches protocol types directly instead of consuming AppContainer-provided state.",
                    stripped,
                )
            if path_rel.startswith("Cam360/Features/") and re.search(r"\bDeviceSession\s*\(", line):
                add_finding(
                    findings,
                    "feature_constructs_device_session",
                    "P1",
                    path_rel,
                    index,
                    "Feature layer constructs DeviceSession instead of receiving shared dependencies from AppContainer.",
                    stripped,
                )
            if "UserDefaults.standard" in line and not path_rel.startswith("Cam360/Core/Storage/"):
                add_finding(
                    findings,
                    "storage_boundary",
                    "P2",
                    path_rel,
                    index,
                    "Direct UserDefaults access outside Core/Storage weakens the persistence boundary.",
                    stripped,
                )
            if re.search(r"\b(import\s+Observation|@Observable\b)", line):
                add_finding(
                    findings,
                    "ios17_observation_on_main_path",
                    "P1",
                    path_rel,
                    index,
                    "Observation is iOS 17+; repo rules require iOS 13 main-path compatibility.",
                    stripped,
                )
            if re.search(r"\b(try!|as!|fatalError\s*\()", line):
                add_finding(
                    findings,
                    "unsafe_runtime_escape",
                    "P2",
                    path_rel,
                    index,
                    "Forced runtime escape should be removed or isolated when the fix is local.",
                    stripped,
                )
            if re.search(r"\bprint\s*\(", line) and not path_rel.startswith("Cam360Tests/"):
                add_finding(
                    findings,
                    "debug_print",
                    "P3",
                    path_rel,
                    index,
                    "Debug print in app source should not become a production behavior dependency.",
                    stripped,
                )
            if re.search(r"\b(TODO|FIXME|HACK)\b", line):
                add_finding(
                    findings,
                    "tracked_placeholder",
                    "P3",
                    path_rel,
                    index,
                    "Tracked placeholder needs review before real-device integration work depends on it.",
                    stripped,
                )
    severity_order = {"P1": 0, "P2": 1, "P3": 2}
    return sorted(findings, key=lambda item: (severity_order.get(item.severity, 9), item.path, item.line))


def normalize_repo_path(raw_path: str) -> str | None:
    raw = raw_path.strip()
    path = pathlib.Path(raw)
    if path.is_absolute():
        try:
            raw = path.relative_to(ROOT).as_posix()
        except ValueError:
            return None
    raw = raw.replace("\\", "/")
    if raw.startswith("./"):
        raw = raw[2:]
    if not raw.endswith(".swift"):
        return None
    if not (ROOT / raw).exists():
        return None
    return raw


def first_failure_excerpt(output: str, limit: int = 1200) -> str:
    lines = [line for line in output.splitlines() if "error:" in line.lower()]
    if not lines:
        lines = output.splitlines()[-30:]
    return "\n".join(lines)[:limit]


def scan_build(config: dict) -> list[Finding]:
    command = config.get("diagnostic_command") or config.get("validation_command", "")
    if not command.strip():
        return []

    result = run_command(command, check=False)
    log_path = config.get("diagnostic_log_path", "build/build-fix-agent/diagnostic.log")
    write_text(ROOT / log_path, result.stdout)
    if result.returncode == 0:
        return []

    findings: list[Finding] = []
    seen: set[tuple[str, int, str]] = set()
    pattern = re.compile(r"(?P<path>(?:/|\./)?[^:\n]+\.swift):(?P<line>\d+):(?:(?P<column>\d+):)?\s*(?P<level>error|warning):\s*(?P<message>.+)")
    for raw_line in result.stdout.splitlines():
        match = pattern.search(raw_line)
        if not match or match.group("level") != "error":
            continue
        path_rel = normalize_repo_path(match.group("path"))
        if not path_rel:
            continue
        line_number = int(match.group("line"))
        message = match.group("message").strip()
        key = (path_rel, line_number, message)
        if key in seen:
            continue
        seen.add(key)
        add_finding(
            findings,
            "build_error",
            "P1",
            path_rel,
            line_number,
            "xcodebuild reported a compiler error.",
            raw_line.strip(),
        )

    if findings:
        return findings

    fallback_paths = config.get("fallback_context_paths", [])
    fallback = next((item for item in fallback_paths if (ROOT / item).exists()), None)
    if fallback:
        add_finding(
            findings,
            "build_failure",
            "P1",
            fallback,
            1,
            "Diagnostic build failed; no specific Swift compiler location was parsed.",
            first_failure_excerpt(result.stdout),
        )
    return findings


def scan_docs(config: dict) -> list[Finding]:
    findings: list[Finding] = []
    review_paths = config.get("review_docs") or config.get("context_docs", [])
    for item in review_paths:
        if (ROOT / item).exists():
            add_finding(
                findings,
                "docs_code_alignment_review",
                "P2",
                item,
                1,
                "Review this document against the current repository structure and public code contracts.",
                item,
            )
    return findings


def summarize_findings(findings: list[Finding]) -> str:
    if not findings:
        return "No findings matched the current rule set."
    rows = []
    for item in findings[:80]:
        rows.append(
            f"- {item.severity} `{item.rule_id}` {item.path}:{item.line} - {item.message}\n"
            f"  `{item.snippet}`"
        )
    if len(findings) > 80:
        rows.append(f"- ... {len(findings) - 80} more findings omitted from report")
    return "\n".join(rows)


def docs_context(config: dict) -> str:
    chunks: list[str] = []
    remaining = int(config.get("max_context_chars", 70000))
    for item in config.get("context_docs", []):
        path = ROOT / item
        if not path.exists():
            continue
        text = read_text(path)
        if len(text) > remaining:
            text = text[:remaining] + "\n...[truncated]\n"
        chunks.append(f"## {item}\n\n{text}")
        remaining -= len(text)
        if remaining <= 0:
            break
    return "\n\n".join(chunks)


def candidate_paths(findings: list[Finding], focus: str, max_files: int) -> list[str]:
    scores: dict[str, int] = {}
    focus_lower = focus.lower()
    for item in findings:
        weight = {"P1": 100, "P2": 40, "P3": 10}.get(item.severity, 1)
        if focus_lower and (focus_lower in item.path.lower() or focus_lower in item.message.lower() or focus_lower in item.rule_id.lower()):
            weight += 80
        scores[item.path] = scores.get(item.path, 0) + weight
    return [path for path, _ in sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))[:max_files]]


def code_fence(path: str) -> str:
    if path.endswith(".swift"):
        return "swift"
    if path.endswith(".md"):
        return "markdown"
    if path.endswith(".json"):
        return "json"
    if path.endswith(".yml") or path.endswith(".yaml"):
        return "yaml"
    return ""


def file_context(paths: Iterable[str], max_file_chars: int) -> str:
    chunks = []
    for item in paths:
        path = ROOT / item
        if path.exists():
            chunks.append(f"## {item}\n\n```{code_fence(item)}\n{read_text(path, max_file_chars)}\n```")
    return "\n\n".join(chunks)


def filtered_tracked_files(prefixes: Iterable[str]) -> list[str]:
    files = git_tracked_files()
    if not prefixes:
        return files
    return [item for item in files if path_matches_prefixes(item, prefixes)]


def repository_reference(config: dict) -> str:
    kind = config.get("agent_kind", "refactor")
    chunks: list[str] = []

    if kind == "build":
        log_path = config.get("diagnostic_log_path")
        if log_path and (ROOT / log_path).exists():
            chunks.append(f"## Diagnostic log excerpt\n\n```text\n{read_text(ROOT / log_path, int(config.get('max_log_chars', 20000)))}\n```")

    if kind == "docs":
        prefixes = config.get("reference_paths", ["Cam360", "Cam360Tests", "docs", "README.md"])
        files = filtered_tracked_files(prefixes)
        max_files = int(config.get("max_reference_files", 220))
        chunks.append("## Repository file index\n\n```text\n" + "\n".join(files[:max_files]) + "\n```")

        symbol_rows: list[str] = []
        symbol_pattern = re.compile(r"^\s*(?:public|internal|private|fileprivate)?\s*(?:final\s+)?(?:class|struct|enum|protocol|actor|func)\s+\w+")
        for item in files:
            if not item.endswith(".swift"):
                continue
            path = ROOT / item
            if not path.exists():
                continue
            for index, line in enumerate(read_text(path, int(config.get("max_file_chars", 18000))).splitlines(), start=1):
                if symbol_pattern.search(line):
                    symbol_rows.append(f"{item}:{index}: {line.strip()}")
                if len(symbol_rows) >= int(config.get("max_symbol_rows", 180)):
                    break
            if len(symbol_rows) >= int(config.get("max_symbol_rows", 180)):
                break
        if symbol_rows:
            chunks.append("## Swift symbol index\n\n```text\n" + "\n".join(symbol_rows) + "\n```")

    return "\n\n".join(chunks)


def system_prompt(config: dict) -> str:
    kind = config.get("agent_kind", "refactor")
    if kind == "build":
        return textwrap.dedent(
            """
            You are an automated build-fix agent for the Cam360 iOS Swift repository.
            Return exactly one unified diff, or the exact text NO_CHANGE.
            Fix only the compiler, syntax, or test failure shown in the diagnostic log.
            Keep the change surgical and preserve behavior unless the failure proves a bug.
            Only edit files that are included in the provided file context.
            Do not edit project files, workflows, generated files, docs, assets, or package manifests.
            Do not introduce new dependencies.
            Keep iOS 13 main-path compatibility and the existing SwiftUI/UIKit lifecycle.
            """
        ).strip()
    if kind == "docs":
        return textwrap.dedent(
            """
            You are an automated docs-alignment agent for the Cam360 iOS Swift repository.
            Return exactly one unified diff, or the exact text NO_CHANGE.
            Only align existing documentation with inspected repository files and code contracts.
            Do not speculate about unverified hardware behavior or future implementation.
            Only edit files that are included in the provided file context.
            Do not edit source code, project files, workflows, generated files, assets, or package manifests.
            Keep documentation concise and avoid duplicating the same fact across multiple files.
            """
        ).strip()
    return textwrap.dedent(
        """
        You are an automated technical-debt agent for the Cam360 iOS Swift repository.
        Return exactly one unified diff, or the exact text NO_CHANGE.
        Keep the change surgical and preserve existing behavior unless the finding proves a bug.
        Only edit files that are included in the provided file context.
        Do not edit project files, workflows, generated files, docs, assets, or package manifests.
        Do not introduce new dependencies.
        Keep iOS 13 main-path compatibility and the existing SwiftUI/UIKit lifecycle.
        For non-UI behavior changes, update the smallest existing test that proves the change.
        """
    ).strip()


def build_prompt(config: dict, findings: list[Finding], focus: str, max_files: int) -> tuple[str, str]:
    targets = candidate_paths(findings, focus, max_files)
    user_prompt = textwrap.dedent(
        f"""
        Current optional focus:
        {focus or "(none)"}

        Editable path prefixes:
        {", ".join(config.get("editable_paths", []))}

        Maximum edited files:
        {max_files}

        Repository architecture/spec context:
        {docs_context(config)}

        Current scan findings:
        {summarize_findings(findings)}

        Additional repository reference:
        {repository_reference(config) or "(none)"}

        Candidate file contents:
        {file_context(targets, int(config.get("max_file_chars", 18000)))}
        """
    ).strip()
    return system_prompt(config), user_prompt


def extract_response_text(payload: dict) -> str:
    if isinstance(payload.get("output_text"), str):
        return payload["output_text"]

    pieces: list[str] = []

    for choice in payload.get("choices", []):
        if not isinstance(choice, dict):
            continue
        message = choice.get("message", {})
        if not isinstance(message, dict):
            continue
        content = message.get("content")
        if isinstance(content, str):
            pieces.append(content)
        elif isinstance(content, list):
            for item in content:
                if isinstance(item, dict) and isinstance(item.get("text"), str):
                    pieces.append(item["text"])

    def walk(value: object) -> None:
        if isinstance(value, dict):
            if isinstance(value.get("text"), str):
                pieces.append(value["text"])
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(payload.get("output", []))
    return "\n".join(pieces).strip()


def openai_base_url(config: dict) -> str:
    env_name = config.get("base_url_env", "OPENAI_BASE_URL")
    value = os.environ.get(env_name, "").strip() or config.get("base_url", "https://api.openai.com/v1")
    return value.rstrip("/")


def openai_api_mode(config: dict, base_url: str) -> str:
    env_name = config.get("api_mode_env", "OPENAI_API_MODE")
    value = os.environ.get(env_name, "").strip() or config.get("api_mode", "").strip()
    if value:
        return value
    host = urllib.parse.urlparse(base_url).netloc
    if host and host != "api.openai.com":
        return "chat_completions"
    return "responses"


def request_body(mode: str, model: str, system_prompt: str, user_prompt: str) -> dict:
    if mode == "responses":
        return {
            "model": model,
            "instructions": system_prompt,
            "input": user_prompt,
            "max_output_tokens": 6000,
        }
    if mode == "chat_completions":
        return {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": 6000,
        }
    raise RuntimeError(f"Unsupported OPENAI_API_MODE: {mode}")


def request_url(base_url: str, mode: str) -> str:
    if mode == "responses":
        return base_url + "/responses"
    if mode == "chat_completions":
        return base_url + "/chat/completions"
    raise RuntimeError(f"Unsupported OPENAI_API_MODE: {mode}")


def request_patch(config: dict, system_prompt: str, user_prompt: str) -> str:
    key_name = config.get("api_key_env", "OPENAI_API_KEY")
    model_name = config.get("model_env", "OPENAI_MODEL")
    api_key = os.environ.get(key_name, "").strip()
    model = os.environ.get(model_name, "").strip()
    if not api_key:
        raise RuntimeError(f"{key_name} is not set")
    if not model:
        raise RuntimeError(f"{model_name} is not set")

    base_url = openai_base_url(config)
    mode = openai_api_mode(config, base_url)
    body = json.dumps(request_body(mode, model, system_prompt, user_prompt)).encode("utf-8")
    request = urllib.request.Request(
        request_url(base_url, mode),
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI request failed: HTTP {error.code}: {detail}") from error
    return extract_response_text(payload)


def missing_ai_config(config: dict) -> list[str]:
    names = [
        config.get("api_key_env", "OPENAI_API_KEY"),
        config.get("model_env", "OPENAI_MODEL"),
    ]
    return [name for name in names if not os.environ.get(name, "").strip()]


def actionable_findings(config: dict, findings: list[Finding], focus: str) -> list[Finding]:
    if config.get("agent_kind") in {"build", "docs"}:
        return findings
    if focus.strip():
        return findings
    return [item for item in findings if item.severity in {"P1", "P2"}]


def extract_diff(text: str) -> str | None:
    clean = text.strip()
    if clean == "NO_CHANGE":
        return None
    fence = re.search(r"```(?:diff|patch)?\s*(.*?)```", clean, flags=re.DOTALL)
    if fence:
        clean = fence.group(1).strip()
    if "diff --git " not in clean and "--- " not in clean:
        raise RuntimeError("Model output did not contain a unified diff")
    return clean + "\n"


def changed_paths(diff_text: str) -> set[str]:
    paths: set[str] = set()
    for line in diff_text.splitlines():
        if line.startswith("diff --git "):
            parts = line.split()
            if len(parts) >= 4:
                for raw in parts[2:4]:
                    if raw.startswith(("a/", "b/")):
                        paths.add(raw[2:])
        elif line.startswith(("--- a/", "+++ b/")):
            paths.add(line[6:].split("\t", 1)[0])
    paths.discard("/dev/null")
    return paths


def changed_line_count(diff_text: str) -> int:
    total = 0
    for line in diff_text.splitlines():
        if line.startswith(("+++", "---")):
            continue
        if line.startswith(("+", "-")):
            total += 1
    return total


def validate_diff(config: dict, diff_text: str, max_files: int) -> None:
    paths = changed_paths(diff_text)
    if not paths:
        raise RuntimeError("Patch has no changed paths")
    if len(paths) > max_files:
        raise RuntimeError(f"Patch changes {len(paths)} files; limit is {max_files}")

    editable = tuple(config.get("editable_paths", []))
    for item in sorted(paths):
        if item.startswith("/") or ".." in pathlib.PurePosixPath(item).parts:
            raise RuntimeError(f"Unsafe patch path: {item}")
        if not (ROOT / item).exists():
            raise RuntimeError(f"Patch creates or references a missing file: {item}")
        if not path_matches_prefixes(item, editable):
            raise RuntimeError(f"Patch touches a non-editable path: {item}")
        if item.endswith((".xcodeproj", ".pbxproj")) or item.startswith(".github/"):
            raise RuntimeError(f"Patch touches a protected path: {item}")

    changed = changed_line_count(diff_text)
    limit = int(config.get("max_changed_lines", 400))
    if changed > limit:
        raise RuntimeError(f"Patch changes {changed} lines; limit is {limit}")


def apply_diff(config: dict, diff_text: str, max_files: int) -> None:
    validate_diff(config, diff_text, max_files)
    patch_path = ROOT / config.get("patch_path", "build/refactor-agent/proposed.patch")
    write_text(patch_path, diff_text)
    run_command(["git", "apply", "--check", patch_path.as_posix()])
    run_command(["git", "apply", patch_path.as_posix()])


def git_has_changes() -> bool:
    return bool(run_command(["git", "status", "--porcelain"], check=True).stdout.strip())


def build_report(config: dict, findings: list[Finding], status: str, details: list[str]) -> str:
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    title = config.get("agent_name", "Refactor Agent")
    report = [
        f"# {title} Report",
        "",
        f"- Time: `{now}`",
        f"- Status: `{status}`",
        f"- Findings: `{len(findings)}`",
        "",
        "## Details",
        "",
    ]
    if details:
        report.extend(f"- {item}" for item in details)
    else:
        report.append("- No additional details.")
    report.extend(["", "## Findings", "", summarize_findings(findings), ""])
    return "\n".join(report)


def markdown_files(config: dict) -> list[pathlib.Path]:
    configured = config.get("link_check_paths") or config.get("context_docs", [])
    paths: list[pathlib.Path] = []
    for item in configured:
        path = ROOT / item
        if path.is_dir():
            paths.extend(sorted(path.rglob("*.md")))
        elif path.exists() and path.suffix == ".md":
            paths.append(path)
    return sorted(set(paths))


def local_markdown_links(text: str) -> Iterable[str]:
    for match in re.finditer(r"!?\[[^\]]*\]\(([^)]+)\)", text):
        raw = match.group(1).strip()
        if not raw or raw.startswith("#"):
            continue
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", raw):
            continue
        yield raw


def check_doc_links(config: dict) -> int:
    errors: list[str] = []
    root_resolved = ROOT.resolve()
    for path in markdown_files(config):
        path_rel = rel(path)
        for raw in local_markdown_links(read_text(path)):
            target = raw.split()[0].strip("<>")
            target_path = target.split("#", 1)[0]
            if not target_path:
                continue
            resolved = (path.parent / target_path).resolve()
            try:
                resolved.relative_to(root_resolved)
            except ValueError:
                errors.append(f"{path_rel}: link escapes repository: {raw}")
                continue
            if not resolved.exists():
                errors.append(f"{path_rel}: missing link target: {raw}")
    if errors:
        print("\n".join(errors))
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Cam360 refactor agent.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("--config", default=".github/refactor-agent.json")
    run_parser.add_argument("--dry-run", default="false")
    run_parser.add_argument("--focus", default="")
    run_parser.add_argument("--max-files", type=int, default=None)
    check_parser = subparsers.add_parser("check-doc-links")
    check_parser.add_argument("--config", default=".github/docs-agent.json")
    args = parser.parse_args()

    config = load_config(ROOT / args.config)
    if args.command == "check-doc-links":
        return check_doc_links(config)

    max_files = args.max_files or int(config.get("max_files", 3))
    dry_run = bool_arg(args.dry_run)
    details: list[str] = []

    findings = scan(config)
    status = "scanned"

    try:
        patch_findings = actionable_findings(config, findings, args.focus)
        system_prompt, user_prompt = build_prompt(config, patch_findings, args.focus, max_files)
        write_text(ROOT / config.get("prompt_path", "build/refactor-agent/prompt.txt"), system_prompt + "\n\n" + user_prompt)
        if not findings:
            details.append(config.get("no_findings_message", "No matching findings; no patch requested."))
            return_code = 0
        elif dry_run:
            details.append("Dry run enabled; no patch requested.")
            return_code = 0
        elif not patch_findings:
            details.append("Only P3/report-only findings matched; no patch requested without an explicit focus.")
            return_code = 0
        elif missing_ai_config(config):
            details.append("AI patch generation skipped; missing " + ", ".join(missing_ai_config(config)) + ".")
            return_code = 0
        else:
            raw_patch = request_patch(config, system_prompt, user_prompt)
            diff_text = extract_diff(raw_patch)
            if not diff_text:
                details.append("Model returned NO_CHANGE; no patch applied.")
                return_code = 0
            else:
                apply_diff(config, diff_text, max_files)
                details.append(f"Patch applied to {len(changed_paths(diff_text))} file(s).")
                if git_has_changes():
                    validation = config.get("validation_command", "").strip()
                    if validation:
                        run_command(validation)
                        details.append("Validation command passed.")
                    else:
                        details.append("No validation command configured.")
                status = "patched"
                return_code = 0
    except Exception as error:
        status = "failed"
        details.append(str(error))
        return_code = 1
    finally:
        write_text(
            ROOT / config.get("report_path", "build/refactor-agent/report.md"),
            build_report(config, findings, status, details),
        )

    return return_code


if __name__ == "__main__":
    sys.exit(main())
