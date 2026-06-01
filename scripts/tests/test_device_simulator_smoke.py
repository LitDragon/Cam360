import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts" / "device_simulator_smoke.py"


def load_smoke_module():
    spec = importlib.util.spec_from_file_location("device_simulator_smoke", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class DeviceSimulatorSmokeTests(unittest.TestCase):
    def test_ready_file_endpoint_uses_ready_file_host_and_port(self):
        module = load_smoke_module()
        with tempfile.TemporaryDirectory() as temp_dir:
            ready_file = pathlib.Path(temp_dir) / "ready.json"
            ready_file.write_text(
                json.dumps(
                    {
                        "ready": True,
                        "host": "127.0.0.1",
                        "port": 39123,
                        "binding_policy": "uuid_read",
                        "control_host": "127.0.0.1",
                        "control_port": 18765,
                    }
                ),
                encoding="utf-8",
            )

            endpoint = module.read_ready_endpoint(ready_file)

        self.assertEqual(endpoint.host, "127.0.0.1")
        self.assertEqual(endpoint.port, 39123)
        self.assertEqual(endpoint.binding_policy, "uuid_read")
        self.assertEqual(
            module.build_client_smoke_command("python3", endpoint),
            [
                "python3",
                "-m",
                "camera360_device_simulator.cli",
                "client",
                "--host",
                "127.0.0.1",
                "--port",
                "39123",
                "smoke",
            ],
        )

    def test_build_serve_command_uses_strict_profile_and_runtime_files(self):
        module = load_smoke_module()
        simulator_repo = pathlib.Path("/tmp/camera-360-secives")
        runtime_dir = pathlib.Path("/tmp/cam360-runtime")
        command = module.build_serve_command(
            python_executable="python3",
            simulator_repo=simulator_repo,
            profile="profiles/default-strict.json",
            ready_file=runtime_dir / "device-ready.json",
            state_file=runtime_dir / "device-state.json",
            control_port=18765,
            include_asset_server=True,
        )

        self.assertEqual(command[:3], ["python3", "-m", "camera360_device_simulator.cli"])
        self.assertIn("serve", command)
        self.assertIn("--profile", command)
        self.assertIn(str(simulator_repo / "profiles/default-strict.json"), command)
        self.assertIn("--ready-file", command)
        self.assertIn(str(runtime_dir / "device-ready.json"), command)
        self.assertIn("--state-file", command)
        self.assertIn(str(runtime_dir / "device-state.json"), command)
        self.assertIn("--control-port", command)
        self.assertIn("18765", command)
        self.assertIn("--asset-host", command)
        self.assertIn("--asset-port", command)
        self.assertIn("0", command)

    def test_build_environment_adds_simulator_src_to_pythonpath(self):
        module = load_smoke_module()
        env = module.build_environment(
            simulator_repo=pathlib.Path("/tmp/camera-360-secives"),
            base_environment={"PYTHONPATH": "/tmp/existing"},
        )

        self.assertEqual(env["PYTHONPATH"], "/tmp/camera-360-secives/src:/tmp/existing")


if __name__ == "__main__":
    unittest.main()
