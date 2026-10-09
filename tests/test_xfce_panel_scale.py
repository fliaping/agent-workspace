import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WATCHER = ROOT / "scripts/watch-xfce-panel-scale.sh"

STUBS = {
    # Root cannot read another user's /proc/<pid>/environ without
    # CAP_SYS_PTRACE; the watcher must read it as abc through s6-setuidgid.
    "s6-setuidgid": """#!/bin/sh
shift
if [ "$1" = cat ]; then
  [ -f "$STUB_DIR/environ-unreadable" ] && { echo "cat: $2: Permission denied" >&2; exit 1; }
  printf 'DISPLAY=:1\\0DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/bus\\0WAYLAND_DISPLAY=wayland-1\\0XDG_RUNTIME_DIR=/tmp/xdg\\0'
  exit 0
fi
exec "$@"
""",
    "pgrep": "#!/bin/sh\necho $PPID\n",
    "xfce4-panel": "#!/bin/sh\nexit 0\n",
    "wlr-randr": "#!/bin/sh\necho 'HEADLESS-1'\necho '  Scale: 1.500000'\n",
    "xfconf-query": """#!/bin/sh
echo "$@" >> "$STUB_DIR/xfconf.log"
case "$*" in *" -s "*) exit 0 ;; esac
echo 1
""",
}


class XfcePanelScaleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        for name, body in STUBS.items():
            path = self.dir / name
            path.write_text(body)
            path.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{self.dir}:{os.environ['PATH']}", "STUB_DIR": str(self.dir),
                    "PIXELFLUX_WAYLAND": "true", "XFCE_PANEL_SCALE_INTERVAL": "1"}

    def run_watcher(self, seconds=4):
        result = subprocess.run(["timeout", str(seconds), "bash", str(WATCHER)], env=self.env,
                                capture_output=True, text=True)
        return result.stdout + result.stderr

    def test_reads_session_as_abc_and_scales_panels(self):
        output = self.run_watcher()
        self.assertIn("Connected to XFCE session", output)
        self.assertIn("Scale 1.500: panel-1=39, icons=24, panel-2=72", output)
        sets = [line for line in (self.dir / "xfconf.log").read_text().splitlines() if " -s " in line]
        self.assertIn("-c xfce4-panel -p /panels/panel-1/size -s 39", sets)
        self.assertNotIn("Permission denied", output)

    def test_unreadable_session_logs_once_instead_of_flooding(self):
        (self.dir / "environ-unreadable").touch()
        output = self.run_watcher(seconds=7)
        self.assertNotIn("Permission denied", output)
        self.assertEqual(output.count("Waiting for the XFCE session environment"), 1)
        self.assertNotIn("Connected", output)


if __name__ == "__main__":
    unittest.main()
