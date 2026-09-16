"""Replay validation and idempotence without changing the host package database."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'scripts/agent-workspace-deb-native'
module = runpy.run_path(str(SOURCE))


class NativeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        env = patch.dict(os.environ, AGENT_WORKSPACE_CONFIG_ROOT=temp.name)
        env.start()
        self.addCleanup(env.stop)
        self.runtime = module['NativeRuntime']()
        self.runtime.cache.mkdir(parents=True)
        package = Path(temp.name) / 'package'
        (package / 'DEBIAN').mkdir(parents=True)
        package.chmod(0o755)
        (package / 'DEBIAN').chmod(0o755)
        (package / 'DEBIAN/control').write_text(
            'Package: native-test\nVersion: 1.0\nArchitecture: all\n'
            'Maintainer: Tests <test@example.invalid>\nDescription: Replay test\n')
        self.archive = self.runtime.cache / 'native-test.deb'
        subprocess.run(['dpkg-deb', '--build', '--root-owner-group', str(package), str(self.archive)],
                       check=True, capture_output=True)
        self.record = {**self.runtime.metadata(self.archive), 'desired_version': '1.0',
                       'archive': str(self.archive), 'sha256': module['digest'](self.archive)}
        module['atomic_json'](self.runtime.manifest, {'packages': {'native-test': self.record}})

    def test_current_or_newer_version_does_not_call_apt(self):
        for version in ('1.0', '2.0'):
            with self.subTest(version=version), patch.object(self.runtime, 'installed', return_value=(True, version)), \
                    patch.object(self.runtime, 'apt') as apt, patch.object(self.runtime, 'sync'):
                self.runtime.restore()
                apt.assert_not_called()
                self.assertEqual(json.loads((self.runtime.state / 'restore-status.json').read_text())['status'], 'up-to-date')

    def test_missing_package_is_replayed_with_no_remove(self):
        with patch.object(self.runtime, 'installed', side_effect=[(False, ''), (True, '1.0')]), \
                patch.object(self.runtime, 'apt', return_value=subprocess.CompletedProcess([], 0)) as apt, \
                patch.object(self.runtime, 'sync'):
            self.runtime.restore()
        self.assertEqual(apt.call_args_list[1].args[0], ['install', '-y', '--no-remove', str(self.archive)])

    def test_corrupt_archive_is_rejected_before_apt(self):
        self.archive.write_bytes(b'corrupted')
        with patch.object(self.runtime, 'apt') as apt:
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                self.runtime.restore()
            apt.assert_not_called()
        self.assertEqual(json.loads((self.runtime.state / 'restore-status.json').read_text())['status'], 'failed')

    def test_archive_outside_cache_is_rejected(self):
        external = self.runtime.config / 'external.deb'
        external.write_bytes(self.archive.read_bytes())
        with self.assertRaisesRegex(RuntimeError, 'inside the native'):
            self.runtime.verified_archive({**self.record, 'archive': str(external)})

    def test_failed_install_retains_desired_state_for_retry(self):
        with patch.object(self.runtime, 'apt', side_effect=subprocess.CalledProcessError(100, ['apt-get'])):
            with self.assertRaises(subprocess.CalledProcessError):
                self.runtime.install(self.archive)
        record = self.runtime.load()['packages']['native-test']
        self.assertEqual(record['desired_version'], '1.0')
        self.assertTrue(Path(record['archive']).exists())

    def test_native_gui_is_never_elevated_or_wrapped_in_proot(self):
        with patch('os.geteuid', return_value=1000):
            self.assertEqual(self.runtime.invocation(['/usr/bin/test-app']), ['/usr/bin/test-app'])
            self.assertEqual(self.runtime.invocation(['apt-get', 'update'], install=True)[:2], ['sudo', '-n'])
        self.assertNotIn('PROOT_NO_SECCOMP', self.runtime.environment(False))

    def test_remove_clears_replay_manifest(self):
        with patch.object(self.runtime, 'apt'), patch.object(self.runtime, 'sync'):
            self.runtime.remove('native-test')
        self.assertNotIn('native-test', self.runtime.load()['packages'])


if __name__ == '__main__':
    unittest.main()
