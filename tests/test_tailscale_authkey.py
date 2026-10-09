import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKSPACECTL = ROOT / "scripts/workspacectl"
INIT_SCRIPT = ROOT / "scripts/tailscale-authkey-init.sh"
SECRET = "tskey-auth-kTESTSECRET0123456789"

STUB = """#!/bin/sh
# Records argv and fakes the daemon's backend state.
echo "$@" >> "$STUB_LOG"
case "$1" in
  status) printf '{"BackendState": "%s"}\\n' "$(cat "$STUB_STATE")" ;;
  up)
    for arg in "$@"; do
      case "$arg" in --auth-key=file:*) cat "${arg#--auth-key=file:}" >> "$STUB_KEYS" ;; esac
    done
    echo Running > "$STUB_STATE" ;;
esac
"""


class TailscaleAuthKeyInitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env_dir = self.root / "container_environment"
        self.env_dir.mkdir()
        self.key_file = self.root / "run/agent-workspace/tailscale-authkey"

    def run_init(self, **variables):
        for name, value in variables.items():
            (self.env_dir / name).write_text(value)
        env = {"PATH": os.environ["PATH"],
               "AGENT_WORKSPACE_CONTAINER_ENV_DIR": str(self.env_dir),
               "AGENT_WORKSPACE_TAILSCALE_KEY_FILE": str(self.key_file), **variables}
        return subprocess.run(["bash", str(INIT_SCRIPT)], env=env, capture_output=True, text=True, check=True)

    def test_key_moves_from_environment_to_private_file(self):
        result = self.run_init(TAILSCALE_AUTHKEY=SECRET, TAILSCALE_HOSTNAME="box")
        self.assertEqual(self.key_file.read_text().strip(), SECRET)
        self.assertEqual(stat.S_IMODE(self.key_file.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.key_file.parent.stat().st_mode), 0o700)
        self.assertFalse((self.env_dir / "TAILSCALE_AUTHKEY").exists())
        self.assertTrue((self.env_dir / "TAILSCALE_HOSTNAME").exists())
        self.assertNotIn(SECRET, result.stdout + result.stderr)

    def test_official_alias_is_accepted_and_removed(self):
        self.run_init(TS_AUTHKEY=SECRET)
        self.assertEqual(self.key_file.read_text().strip(), SECRET)
        self.assertFalse((self.env_dir / "TS_AUTHKEY").exists())

    def test_key_file_variable_is_copied(self):
        source = self.root / "secret"
        source.write_text(SECRET + "\n")
        self.run_init(TAILSCALE_AUTHKEY_FILE=str(source))
        self.assertEqual(self.key_file.read_text().strip(), SECRET)

    def test_unset_environment_leaves_no_file(self):
        self.key_file.parent.mkdir(parents=True)
        self.key_file.write_text("stale")
        result = self.run_init()
        self.assertFalse(self.key_file.exists())
        self.assertEqual(result.stdout, "")


class TailscaleAutoconnectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        stub = bin_dir / "tailscale"
        stub.write_text(STUB)
        stub.chmod(0o755)
        self.log = self.root / "argv.log"
        self.state = self.root / "state"
        self.keys = self.root / "keys"
        self.key_file = self.root / "authkey"
        self.key_file.write_text(SECRET + "\n")
        self.key_file.chmod(0o600)
        config = self.root / "config/.config/code-server/config.yaml"
        config.parent.mkdir(parents=True)
        config.write_text("bind-addr: 0.0.0.0:8443\ncert: true\n")
        self.env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}",
                    "AGENT_WORKSPACE_CONFIG_ROOT": str(self.root / "config"),
                    "STUB_LOG": str(self.log), "STUB_STATE": str(self.state), "STUB_KEYS": str(self.keys),
                    "TAILSCALE_AUTHKEY_FILE": str(self.key_file), "TAILSCALE_WAIT_SECONDS": "1"}

    def autoconnect(self, state="NeedsLogin", check=True, **extra):
        self.state.write_text(state)
        return subprocess.run(["bash", str(WORKSPACECTL), "tailscale", "autoconnect"],
                              env={**self.env, **extra}, capture_output=True, text=True, check=check)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_logs_in_with_file_reference_only(self):
        result = self.autoconnect(TAILSCALE_HOSTNAME="ws1", TAILSCALE_ADVERTISE_TAGS="tag:agent",
                                  TAILSCALE_EXTRA_ARGS="--ssh --accept-routes")
        up = [c for c in self.calls() if c.startswith("up ")]
        self.assertEqual(up, [f"up --auth-key=file:{self.key_file} --hostname=ws1 --accept-dns=false "
                              "--advertise-tags=tag:agent --ssh --accept-routes"])
        self.assertEqual(self.keys.read_text().strip(), SECRET)
        self.assertNotIn(SECRET, result.stdout + result.stderr + self.log.read_text())
        self.assertFalse(any(c.startswith("serve") for c in self.calls()))

    def test_skips_login_when_already_running(self):
        result = self.autoconnect(state="Running")
        self.assertFalse(any(c.startswith("up") for c in self.calls()))
        self.assertIn("already logged in", result.stdout)

    def test_serve_is_enabled_on_request(self):
        self.autoconnect(TAILSCALE_SERVE="true")
        self.assertIn("serve --bg --yes https+insecure://127.0.0.1:8443", self.calls())

    def test_missing_key_file_fails_without_calling_up(self):
        self.key_file.unlink()
        result = self.autoconnect(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c.startswith("up") for c in self.calls()))

    def test_unresponsive_daemon_fails(self):
        result = self.autoconnect(state="", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not answering", result.stderr)


if __name__ == "__main__":
    unittest.main()
