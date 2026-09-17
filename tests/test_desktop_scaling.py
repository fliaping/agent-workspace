import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("desktop_scaling", ROOT / "scripts/workspacectl-desktop-scaling.py")
scaling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scaling)


class DesktopScalingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.value = self.root / "value"
        self.value.write_text("2.0")
        binary = self.root / "gsettings"
        binary.write_text("""#!/usr/bin/env python3
import os, sys
from pathlib import Path
p = Path(os.environ['TEST_VALUE'])
if sys.argv[1] == 'get': print(p.read_text())
elif sys.argv[1] == 'writable': print(os.environ.get('TEST_WRITABLE', 'true'))
elif sys.argv[1] == 'set': p.write_text(sys.argv[-1])
else: sys.exit(1)
""")
        binary.chmod(0o755)
        self.env = {**os.environ, "PATH": str(self.root) + ":" + os.environ["PATH"],
                    "TEST_VALUE": str(self.value)}
        self.state = self.root / "state"
        state_patch = patch.object(scaling, "STATE", self.state)
        state_patch.start()
        self.addCleanup(state_patch.stop)

    def test_repair_is_idempotent_and_restore_retains_original(self):
        self.assertTrue(scaling.change("repair", self.env)["changed"])
        self.assertEqual(float(self.value.read_text()), 1.0)
        self.assertFalse(scaling.change("repair", self.env)["changed"])
        self.assertEqual(json.loads((self.state / "original.json").read_text())["text_scale"], 2.0)
        scaling.change("restore", self.env)
        self.assertEqual(float(self.value.read_text()), 2.0)
        self.assertFalse((self.state / "original.json").exists())

    def test_already_aligned_does_not_create_a_misleading_backup(self):
        self.value.write_text("1.0")
        self.assertFalse(scaling.change("repair", self.env)["changed"])
        self.assertFalse((self.state / "original.json").exists())
        with self.assertRaisesRegex(RuntimeError, "No managed"):
            scaling.change("restore", self.env)

    def test_readonly_settings_are_unchanged(self):
        with self.assertRaisesRegex(RuntimeError, "not writable"):
            scaling.change("repair", {**self.env, "TEST_WRITABLE": "false"})
        self.assertEqual(self.value.read_text(), "2.0")
        self.assertFalse(self.state.exists())

    def test_invalid_backup_cannot_set_a_scale(self):
        self.state.mkdir()
        (self.state / "original.json").write_text('{"text_scale": "nan"}')
        with self.assertRaises(ValueError):
            scaling.change("restore", self.env)
        self.assertEqual(self.value.read_text(), "2.0")

    def test_uses_plasma_bus_not_terminal_or_outer_compositor(self):
        proc = self.root / "proc"
        for pid, name, session in [("1", "kwin_wayland", "wayland"),
                                   ("2", "plasmashell", "x11"), ("3", "plasmashell", "wayland")]:
            directory = proc / pid
            directory.mkdir(parents=True)
            (directory / "comm").write_text(name)
            values = {"HOME": str(self.root), "XDG_SESSION_TYPE": session,
                      "WAYLAND_DISPLAY": "wayland-0", "DBUS_SESSION_BUS_ADDRESS": "unix:path=test",
                      "UNRELATED_SECRET": "private"}
            (directory / "environ").write_text(chr(0).join(k + "=" + v for k, v in values.items()))
        with patch.dict(os.environ, {"DBUS_SESSION_BUS_ADDRESS": "wrong", "GSETTINGS_BACKEND": "memory"}):
            env = scaling.desktop_env(proc)
        self.assertEqual(env["DBUS_SESSION_BUS_ADDRESS"], "unix:path=test")
        self.assertNotIn("UNRELATED_SECRET", env)
        self.assertNotIn("GSETTINGS_BACKEND", env)
        (proc / "3/comm").write_text("bash")
        with self.assertRaisesRegex(RuntimeError, "No current-user"):
            scaling.desktop_env(proc)


if __name__ == "__main__":
    unittest.main()
