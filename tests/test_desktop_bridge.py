import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
import json
import urllib.request
import urllib.error
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('desktop_bridge', str(ROOT / 'addons/desktop-bridge/bin/agent-desktop-bridge'))
spec = importlib.util.spec_from_loader(loader.name, loader)
bridge = importlib.util.module_from_spec(spec)
loader.exec_module(bridge)


class DesktopBridgeTests(unittest.TestCase):
    def test_status_explains_outage_while_health_still_fails(self):
        server = bridge.ThreadingHTTPServer(('127.0.0.1', 0), bridge.Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = 'http://127.0.0.1:' + str(server.server_port)
        try:
            with patch.object(bridge, 'status', return_value={'backend_available': False, 'state': 'backend-unavailable'}):
                with urllib.request.urlopen(url + '/v1/status') as response:
                    self.assertEqual(json.load(response)['state'], 'backend-unavailable')
                with self.assertRaises(urllib.error.HTTPError) as error:
                    urllib.request.urlopen(url + '/health')
                self.assertEqual(error.exception.code, 503)
                error.exception.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_process_discovery_does_not_match_command_arguments_or_leak_secrets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for pid, comm in [('1', 'bash'), ('2', 'plasmashell')]:
                directory = root / pid
                directory.mkdir()
                (directory / 'comm').write_text(comm + '\n')
                (directory / 'cmdline').write_bytes(b'bash\0-c\0inspect labwc\0')
                (directory / 'environ').write_bytes(b'WAYLAND_DISPLAY=wayland-0\0SECRET=private\0')
            self.assertEqual(bridge.process_envs({'plasmashell', 'labwc'}, root),
                             [('plasmashell', {'WAYLAND_DISPLAY': 'wayland-0'})])

    def test_kde_uses_inner_desktop_socket(self):
        with patch.object(bridge, 'process_envs', return_value=[
            ('kwin_wayland', {'WAYLAND_DISPLAY': 'wayland-1'}),
            ('plasmashell', {'WAYLAND_DISPLAY': 'wayland-0', 'DISPLAY': ':1'}),
        ]):
            self.assertEqual(bridge.desktop_env()['WAYLAND_DISPLAY'], 'wayland-0')

    def test_backend_failure_explains_running_process_configuration(self):
        cases = [([], 'selkies-not-running', False),
                 ([('selkies', {})], 'native-backend-disabled', True),
                 ([('selkies', {'PIXELFLUX_CU': '5000'})], 'native-backend-port-mismatch', True),
                 ([('selkies', {'PIXELFLUX_CU': str(bridge.NATIVE_PORT)})], 'native-backend-not-listening', False)]
        for processes, reason, restart in cases:
            with self.subTest(reason=reason), patch.object(bridge, 'process_envs', return_value=processes):
                result = bridge.backend_diagnostic()
                self.assertEqual(result['reason'], reason)
                self.assertEqual(result['restart_required'], restart)

    def test_install_does_not_restart_live_desktop_by_default(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            stub = root / 'stubs'
            stub.mkdir()
            log = root / 'calls'
            for name in ['sudo', 'systemctl']:
                file = stub / name
                file.write_text("""#!/bin/sh
printf '%s\n' "$*" >> "$DESKTOP_TEST_LOG"
""")
                file.chmod(0o755)
            env = {**os.environ, 'PATH': str(stub) + ':' + os.environ['PATH'],
                   'CONFIG_ROOT': str(root / 'config'), 'DESKTOP_TEST_LOG': str(log),
                   'AGENT_DESKTOP_RESTART_SELKIES': '0'}
            env.pop('AGENT_DESKTOP_INSTALL_ROOT', None)
            subprocess.run(['bash', str(ROOT / 'addons/desktop-bridge/install.sh')],
                           env=env, check=True, capture_output=True, text=True)
            self.assertNotIn('s6-svc', log.read_text())
            self.assertTrue((root / 'config/bin/agent-desktop-bridge').exists())


if __name__ == '__main__':
    unittest.main()
