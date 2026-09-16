"""Exercise the real desktop frontend with a Wayland-only KDE session."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


FRONTEND = Path(__file__).resolve().parents[1] / 'scripts/agent-workspace-deb-installer'
STUB = '''import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['DIALOG_TEST_TRACE'], 'a') as output:
    output.write(json.dumps([name, args]) + '\\n')
if name == 'kdialog':
    if '--radiolist' in args:
        print(os.environ.get('DIALOG_TEST_MODE', 'proot'))
        sys.exit(int(os.environ.get('DIALOG_TEST_MODE_CANCEL', '0')))
    if '--yesno' in args:
        sys.exit(int(os.environ.get('DIALOG_TEST_CONFIRM', '0')))
    if '--progressbar' in args:
        print('org.kde.kdialog-test /ProgressDialog')
elif name in ('agent-workspace-deb', 'agent-workspace-deb-native'):
    if args[0] == 'launcher':
        sys.exit(0 if os.environ.get('DIALOG_TEST_LAUNCHER') else 1)
    if args[0] == 'launch':
        sys.exit(0)
    print('Checking <package> & dependencies', flush=True)
    time.sleep(0.6)
    if os.environ.get('DIALOG_TEST_INSTALL', '0') != '0':
        print('malloc(): corrupted top size')
        print('dpkg-deb: error: <decompress> subprocess was killed')
        print('dpkg: error processing archive /tmp/package.deb (--unpack):')
        print(' cannot copy extracted data: unexpected end of file or stream')
        for number in range(20):
            print('Unpacking unrelated dependency', number)
        print('E: Sub-process /usr/bin/dpkg returned an error code (1)')
    sys.exit(int(os.environ.get('DIALOG_TEST_INSTALL', '0')))
elif name in ('zenity', 'xmessage'):
    sys.exit(99)
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.config = self.directory / 'home'
        self.bin = self.config / 'bin'
        self.bin.mkdir(parents=True)
        self.trace = self.directory / 'calls.jsonl'
        for command in ('kdialog', 'zenity', 'xmessage', 'qdbus6', 'agent-workspace-deb', 'agent-workspace-deb-native'):
            file = self.bin / command
            file.write_text('#!' + sys.executable + '\n' + STUB)
            file.chmod(0o755)
        package = self.directory / 'package'
        (package / 'DEBIAN').mkdir(parents=True)
        package.chmod(0o755)
        (package / 'DEBIAN').chmod(0o755)
        (package / 'DEBIAN/control').write_text(
            'Package: dialog-test\nVersion: 1.0\nArchitecture: all\n'
            'Maintainer: Tests <test@example.invalid>\n'
            'Description: <img src="invalid"> & plain text\n')
        self.deb = self.directory / 'package with spaces.deb'
        subprocess.run(['dpkg-deb', '--build', '--root-owner-group', str(package), str(self.deb)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.env = dict(os.environ, AGENT_WORKSPACE_CONFIG_ROOT=str(self.config),
                        PATH=str(self.bin) + ':' + os.environ['PATH'],
                        DIALOG_TEST_TRACE=str(self.trace), XDG_CURRENT_DESKTOP='KDE',
                        DISPLAY='', WAYLAND_DISPLAY='wayland-test', LANG='C.UTF-8', LC_ALL='C.UTF-8')

    def invoke(self, *options, **env):
        result = subprocess.run(['/bin/bash', str(FRONTEND), *options, str(self.deb)],
                                env={**self.env, **env}, capture_output=True, text=True, timeout=10)
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()] if self.trace.exists() else []
        return result, calls

    def test_wayland_confirmation_progress_and_result(self):
        result, calls = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(name in ('zenity', 'xmessage') for name, _ in calls))
        question = next(args for name, args in calls if name == 'kdialog' and '--yesno' in args)
        self.assertIn('&lt;img src="invalid"&gt; &amp; plain text', question[-1])
        backend = next(args for name, args in calls if name == 'agent-workspace-deb')
        self.assertEqual(backend, ['install', '--yes', str(self.deb)])
        self.assertTrue(any('--progressbar' in args for _, args in calls))
        self.assertTrue(any(name == 'qdbus6' and 'close' in args for name, args in calls))
        self.assertTrue(any('--msgbox' in args for _, args in calls))
        launch = self.config / '.local/log/agent-workspace/deb-installer-launch.log'
        self.assertIn('dialog=kdialog', launch.read_text())

    def test_cancel_does_not_start_installation(self):
        result, calls = self.invoke(DIALOG_TEST_CONFIRM='1')
        self.assertEqual(result.returncode, 0)
        self.assertFalse(any(name == 'agent-workspace-deb' for name, _ in calls))

    def test_install_error_is_visible_and_logged(self):
        result, calls = self.invoke(DIALOG_TEST_INSTALL='42')
        self.assertEqual(result.returncode, 42)
        self.assertTrue(any('--error' in args for _, args in calls))
        error = next(args for _, args in calls if '--error' in args)[-1]
        self.assertIn('malloc(): corrupted top size', error)
        self.assertIn('cannot copy extracted data', error)
        self.assertNotIn('Unpacking unrelated dependency 19', error)
        log = self.config / '.local/log/agent-workspace/deb-installer.log'
        self.assertIn('[exit=42]', log.read_text())

    def test_noninteractive_mode_never_opens_dialog(self):
        result, calls = self.invoke('--yes')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([name for name, _ in calls], ['agent-workspace-deb'])

    def test_native_selection_uses_native_backend_and_launch_action(self):
        result, calls = self.invoke(DIALOG_TEST_MODE='native', DIALOG_TEST_LAUNCHER='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        native = [args for name, args in calls if name == 'agent-workspace-deb-native']
        self.assertEqual(native, [['install', '--yes', str(self.deb)],
                                 ['launcher', 'dialog-test'], ['launch', 'dialog-test']])
        self.assertFalse(any(name == 'agent-workspace-deb' for name, _ in calls))
        self.assertTrue((self.config / '.local/log/agent-workspace/deb-installer-native.log').exists())

    def test_cancel_mode_selection_does_not_install(self):
        result, calls = self.invoke(DIALOG_TEST_MODE_CANCEL='1')
        self.assertEqual(result.returncode, 0)
        self.assertFalse(any(name.startswith('agent-workspace-deb') for name, _ in calls))

    def test_native_noninteractive_has_no_dialogs_or_launch(self):
        result, calls = self.invoke('--native', '--yes')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [['agent-workspace-deb-native', ['install', '--yes', str(self.deb)]]])


if __name__ == '__main__':
    unittest.main()
