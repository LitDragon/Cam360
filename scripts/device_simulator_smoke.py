#!/usr/bin/env python3
"""Run the external Camera 360 simulator strict lifecycle smoke."""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
from typing import Mapping


DEFAULT_SIMULATOR_REPO = pathlib.Path("/Users/naxclow/camera-360-secives")
DEFAULT_PROFILE = "profiles/default-strict.json"


class SmokeError(RuntimeError):
    pass


@dataclasses.dataclass(frozen=True)
class ReadyEndpoint:
    host: str
    port: int
    binding_policy: str | None = None
    control_host: str | None = None
    control_port: int | None = None


def build_environment(
    simulator_repo: pathlib.Path,
    base_environment: Mapping[str, str] | None = None,
) -> dict[str, str]:
    environment = dict(os.environ if base_environment is None else base_environment)
    simulator_src = str(simulator_repo / "src")
    existing_pythonpath = environment.get("PYTHONPATH")
    environment["PYTHONPATH"] = (
        simulator_src if not existing_pythonpath else simulator_src + os.pathsep + existing_pythonpath
    )
    return environment


def build_serve_command(
    python_executable: str,
    simulator_repo: pathlib.Path,
    profile: str,
    ready_file: pathlib.Path,
    state_file: pathlib.Path,
    control_port: int,
    include_asset_server: bool,
) -> list[str]:
    profile_path = pathlib.Path(profile)
    if not profile_path.is_absolute():
        profile_path = simulator_repo / profile_path

    command = [
        python_executable,
        "-m",
        "camera360_device_simulator.cli",
        "serve",
        "--host",
        "127.0.0.1",
        "--port",
        "0",
        "--profile",
        str(profile_path),
        "--ready-file",
        str(ready_file),
        "--state-file",
        str(state_file),
        "--control-port",
        str(control_port),
        "--json-logs",
    ]
    if include_asset_server:
        command.extend(["--asset-host", "127.0.0.1", "--asset-port", "0"])
    return command


def build_client_smoke_command(python_executable: str, endpoint: ReadyEndpoint) -> list[str]:
    return [
        python_executable,
        "-m",
        "camera360_device_simulator.cli",
        "client",
        "--host",
        endpoint.host,
        "--port",
        str(endpoint.port),
        "smoke",
    ]


def read_ready_endpoint(path: pathlib.Path) -> ReadyEndpoint:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise SmokeError(f"failed to read ready file: {error}") from error
    except json.JSONDecodeError as error:
        raise SmokeError(f"ready file is not valid JSON: {error}") from error

    if payload.get("ready") is not True:
        raise SmokeError("ready file does not declare ready=true")

    host = payload.get("host")
    if not isinstance(host, str) or not host.strip():
        raise SmokeError("ready file host is missing")

    port = _port_from_value(payload.get("port"))
    if port is None:
        raise SmokeError("ready file port is missing or invalid")

    return ReadyEndpoint(
        host=host,
        port=port,
        binding_policy=_optional_string(payload.get("binding_policy")),
        control_host=_optional_string(payload.get("control_host")),
        control_port=_port_from_value(payload.get("control_port")),
    )


def wait_for_ready_endpoint(
    path: pathlib.Path,
    process: subprocess.Popen,
    timeout_seconds: float,
) -> ReadyEndpoint:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if process.poll() is not None:
            stdout, stderr = process.communicate(timeout=1)
            details = _process_output_details(stdout, stderr)
            raise SmokeError(
                f"simulator exited before ready-file was written: {process.returncode}{details}"
            )
        if path.exists():
            return read_ready_endpoint(path)
        time.sleep(0.1)
    raise SmokeError(f"timed out waiting for ready file: {path}")


def run_strict_smoke(
    simulator_repo: pathlib.Path,
    profile: str,
    runtime_dir: pathlib.Path,
    python_executable: str,
    control_port: int,
    include_asset_server: bool,
    timeout_seconds: float,
) -> int:
    if not simulator_repo.exists():
        raise SmokeError(f"simulator repo not found: {simulator_repo}")

    runtime_dir.mkdir(parents=True, exist_ok=True)
    ready_file = runtime_dir / "device-ready.json"
    state_file = runtime_dir / "device-state.json"
    ready_file.unlink(missing_ok=True)
    state_file.unlink(missing_ok=True)

    environment = build_environment(simulator_repo)
    serve_command = build_serve_command(
        python_executable=python_executable,
        simulator_repo=simulator_repo,
        profile=profile,
        ready_file=ready_file,
        state_file=state_file,
        control_port=control_port,
        include_asset_server=include_asset_server,
    )

    process = subprocess.Popen(
        serve_command,
        cwd=simulator_repo,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        endpoint = wait_for_ready_endpoint(ready_file, process, timeout_seconds)
        print(f"ready endpoint: {endpoint.host}:{endpoint.port}")
        print(f"binding policy: {endpoint.binding_policy or '-'}")

        client_command = build_client_smoke_command(python_executable, endpoint)
        result = subprocess.run(
            client_command,
            cwd=simulator_repo,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.stdout.strip():
            print(result.stdout.strip())
        if result.stderr.strip():
            print(result.stderr.strip(), file=sys.stderr)
        return result.returncode
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def _optional_string(value: object) -> str | None:
    return value if isinstance(value, str) and value else None


def _process_output_details(stdout: str | None, stderr: str | None) -> str:
    lines: list[str] = []
    if stdout and stdout.strip():
        lines.append("stdout: " + stdout.strip().splitlines()[-1])
    if stderr and stderr.strip():
        lines.append("stderr: " + stderr.strip().splitlines()[-1])
    return "" if not lines else " (" + "; ".join(lines) + ")"


def _port_from_value(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and 0 < value <= 65535:
        return value
    if isinstance(value, str):
        try:
            port = int(value)
        except ValueError:
            return None
        return port if 0 < port <= 65535 else None
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the external Camera 360 simulator strict lifecycle smoke."
    )
    parser.add_argument("--simulator-repo", type=pathlib.Path, default=DEFAULT_SIMULATOR_REPO)
    parser.add_argument("--profile", default=DEFAULT_PROFILE)
    parser.add_argument("--runtime-dir", type=pathlib.Path, default=None)
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--control-port", type=int, default=0)
    parser.add_argument("--asset-server", action="store_true")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    runtime_dir = args.runtime_dir
    temp_dir = None
    if runtime_dir is None:
        temp_dir = tempfile.TemporaryDirectory(prefix="cam360-device-simulator-")
        runtime_dir = pathlib.Path(temp_dir.name)

    try:
        return run_strict_smoke(
            simulator_repo=args.simulator_repo,
            profile=args.profile,
            runtime_dir=runtime_dir,
            python_executable=args.python,
            control_port=args.control_port,
            include_asset_server=args.asset_server,
            timeout_seconds=args.timeout,
        )
    except SmokeError as error:
        print(f"device simulator smoke failed: {error}", file=sys.stderr)
        return 1
    finally:
        if temp_dir is not None:
            temp_dir.cleanup()


if __name__ == "__main__":
    sys.exit(main())
