import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("workspacectl_json", ROOT / "scripts/workspacectl-json.py")
wsjson = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wsjson)

USER_LSOF = """COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
selkies 328 abc    9u  IPv4 1      0t0  TCP *:8082 (LISTEN)
"""
ROOT_LSOF = """COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nginx   307 root   5u  IPv4 2      0t0  TCP *:3000 (LISTEN)
nginx   307 root   7u  IPv4 3      0t0  TCP *:3001 (LISTEN)
selkies 328 abc    9u  IPv4 1      0t0  TCP *:8082 (LISTEN)
"""


def fake_run(args, **_kwargs):
    stdout = ROOT_LSOF if args[:2] == ["sudo", "-n"] else USER_LSOF
    return subprocess.CompletedProcess(args, 0, stdout, "")


class PortsTests(unittest.TestCase):
    def setUp(self):
        for target, value in (
            ("command_path", lambda name: f"/usr/bin/{name}"),
            ("run", fake_run),
        ):
            patcher = patch.object(wsjson, target, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_unprivileged_user_also_sees_root_listeners(self):
        with patch.object(wsjson.os, "geteuid", return_value=1000), \
                patch.object(wsjson, "passwordless_sudo", return_value=True):
            rows = wsjson.ports()
        self.assertEqual(
            [(row["command"], row["address"]) for row in rows],
            [("nginx", "*:3000"), ("nginx", "*:3001"), ("selkies", "*:8082")],
        )

    def test_without_sudo_keeps_unprivileged_view(self):
        with patch.object(wsjson.os, "geteuid", return_value=1000), \
                patch.object(wsjson, "passwordless_sudo", return_value=False):
            rows = wsjson.ports()
        self.assertEqual([row["address"] for row in rows], ["*:8082"])

    def test_ports_text_output(self):
        lines = wsjson.text_lines("ports", [{"command": "nginx", "pid": 307, "user": "root", "address": "*:3001"}])
        self.assertIn("COMMAND", lines[0])
        self.assertIn("*:3001", lines[1])


class ResourceTextTests(unittest.TestCase):
    def test_skills_text_is_human_readable(self):
        payload = {"root": "/config/.agents/skills", "count": 1, "shared_count": 1,
                   "items": [{"name": "demo", "shared": True, "agents": ["codex"]}]}
        lines = wsjson.text_lines("skills", payload)
        self.assertTrue(lines[0].startswith("Global Skills: 1"))
        self.assertIn("demo", lines[1])
        self.assertFalse(any(line.startswith("{") for line in lines))

    def test_mcp_text_lists_agents(self):
        payload = {"count": 1, "global_count": 0, "items": [
            {"name": "docs", "transport": "http", "detail": "https://example.com/mcp",
             "agents": [{"id": "codex"}, {"id": "claude-code"}]}]}
        lines = wsjson.text_lines("mcp", payload)
        self.assertIn("codex,claude-code", lines[1])

    def test_unknown_text_command_is_rejected(self):
        with self.assertRaises(ValueError):
            wsjson.text_lines("status", {})


if __name__ == "__main__":
    unittest.main()
