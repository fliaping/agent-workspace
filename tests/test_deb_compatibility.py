"""Launch policy regressions with real payload layouts and Wayland sockets."""
import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import socket
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'scripts'
module = runpy.run_path(str(SOURCE / 'agent-workspace-deb'))
native = runpy.run_path(str(SOURCE / 'agent-workspace-deb-native'))


class CompatibilityTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.config = Path(temp.name)
        env = patch.dict(os.environ, AGENT_WORKSPACE_CONFIG_ROOT=temp.name)
        env.start()
        self.addCleanup(env.stop)
        self.runtime = module['Runtime']()
        self.directory = self.runtime.root / 'opt/example'
        self.directory.mkdir(parents=True)
        for name in ('icudtl.dat', 'resources.pak', 'resources/app.asar'):
            path = self.directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        executable = self.directory / 'example'
        executable.write_text('#!/bin/sh\nexit 0\n')
        executable.chmod(0o755)
        self.env = {'PATH': '/usr/bin:/bin'}
        self.argv = ['/opt/example/example']

    def settings(self, value):
        module['atomic_json'](self.runtime.overrides, {'example-app': value})

    def launch(self, argv=None, env=None):
        return self.runtime.prepare_launch(argv or self.argv, dict(env or self.env), 'example-app')

    def wayland(self):
        server = socket.socket(socket.AF_UNIX)
        self.addCleanup(server.close)
        server.bind(str(self.config / 'wayland-0'))
        return {**self.env, 'WAYLAND_DISPLAY': 'wayland-0', 'XDG_RUNTIME_DIR': str(self.config)}

    def test_unrecognized_app_and_unscoped_command_are_unchanged(self):
        self.assertEqual(self.launch(['/usr/bin/python3', '--', 'document'])[0],
                         ['/usr/bin/python3', '--', 'document'])
        self.assertEqual(self.runtime.prepare_launch(self.argv, self.env, None)[0], self.argv)
        (self.directory / 'resources/app.asar').unlink()
        self.assertEqual(self.launch()[1]['profile'], 'none')

    def test_generic_electron_proot_defaults_and_real_wayland_socket(self):
        argv, report = self.launch(env=self.wayland())
        self.assertEqual(argv, self.argv + ['--no-sandbox', '--disable-gpu', '--ozone-platform=wayland'])
        self.assertEqual(report['profile'], 'electron')
        self.assertEqual(self.argv, ['/opt/example/example'])

    def test_stale_wayland_environment_and_regular_file_do_not_force_wayland(self):
        env = {**self.env, 'WAYLAND_DISPLAY': 'missing', 'XDG_RUNTIME_DIR': str(self.config)}
        for exists in (False, True):
            if exists:
                (self.config / 'missing').touch()
            self.assertNotIn('--ozone-platform=wayland', self.launch(env=env)[0])

    def test_native_preserves_sandbox_and_gpu_defaults(self):
        self.runtime = native['NativeRuntime']()
        self.runtime.root = self.directory.parents[1]
        argv, report = self.launch(env=self.wayland())
        self.assertEqual(argv, self.argv + ['--ozone-platform=wayland'])
        self.assertEqual(report['backend'], 'native')

    def test_absolute_symlink_and_code_style_wrapper_are_detected(self):
        (self.directory / 'resources/app.asar').unlink()
        (self.directory / 'resources/app').mkdir()
        (self.directory / 'resources/app/package.json').write_text('{}')
        wrapper = self.directory / 'bin/example'
        wrapper.parent.mkdir()
        wrapper.write_text('#!/bin/sh\n')
        wrapper.chmod(0o755)
        link = self.runtime.root / 'usr/bin/example'
        link.parent.mkdir(parents=True)
        link.symlink_to('/opt/example/bin/example')
        self.assertEqual(self.launch(['example'])[1]['profile'], 'electron')

    def test_crash_helper_is_not_treated_as_app(self):
        helper = self.directory / 'chrome_crashpad_handler'
        helper.touch()
        helper.chmod(0o755)
        self.assertEqual(self.launch(['/opt/example/chrome_crashpad_handler'])[1]['profile'], 'none')

    def test_electron_node_worker_receives_no_automatic_gui_flags(self):
        argv = ['env', '--', 'ELECTRON_RUN_AS_NODE=1', '/opt/example/example', 'worker.js']
        self.assertEqual(self.launch(argv)[0], argv)
        self.settings({'environment': {'ELECTRON_RUN_AS_NODE': '1'}})
        self.assertEqual(self.launch()[0], self.argv)

    def test_env_prefix_and_file_operands_remain_intact(self):
        argv = ['/usr/bin/env', 'WAYLAND_DISPLAY=', '/opt/example/example', '--', '--disable-gpu', 'a b']
        result, report = self.launch(argv, self.wayland())
        self.assertEqual(result, argv[:3] + ['--no-sandbox', '--disable-gpu'] + argv[3:])
        self.assertFalse(report['wayland_available'])

    def test_explicit_parameters_override_defaults_without_duplicates(self):
        self.settings({'extra_args': ['--no-sandbox', '--use-gl=desktop', '--ozone-platform', 'x11']})
        argv, report = self.launch(env=self.wayland())
        self.assertEqual(report['automatic_args'], [])
        self.assertEqual(argv.count('--no-sandbox'), 1)
        self.assertNotIn('--disable-gpu', argv)
        self.assertNotIn('--ozone-platform=wayland', argv)
        self.settings({})
        argv, report = self.launch(self.argv + ['--enable-sandbox', '--enable-gpu', '--ozone-platform=x11'])
        self.assertEqual(report['automatic_args'], [])

    def test_policy_can_disable_all_or_individual_defaults(self):
        env = self.wayland()
        for settings in ({'profile': 'none'}, {'sandbox': 'default', 'gpu': 'default', 'display': 'default'}):
            self.settings({'compatibility': settings})
            self.assertEqual(self.launch(env=env)[0], self.argv)
        self.settings({'compatibility': {'display': 'x11'}})
        self.assertIn('--ozone-platform=x11', self.launch(env=env)[0])

    def test_environment_override_controls_display_detection(self):
        self.settings({'environment': {'WAYLAND_DISPLAY': ''}})
        self.assertNotIn('--ozone-platform=wayland', self.launch(env=self.wayland())[0])

    def test_unusual_layout_can_explicitly_opt_in(self):
        self.settings({'compatibility': {'profile': 'electron'}})
        self.assertIn('--disable-gpu', self.launch(['/custom/wrapper'])[0])

    def test_invalid_policy_and_unsupported_env_prefix_fail_clearly(self):
        for settings in ({'gpu': 'typo'}, {'unknown': 'auto'}, [], {'display': {}}):
            self.settings({'compatibility': settings})
            with self.assertRaisesRegex(RuntimeError, 'Invalid compatibility'):
                self.launch()
        self.settings({'extra_args': ['--test']})
        with self.assertRaisesRegex(RuntimeError, 'direct executable'):
            self.launch(['env', '-S', 'example'])

    def test_dry_run_does_not_spawn_or_write_launch_state(self):
        output = io.StringIO()
        with patch.object(self.runtime, 'require_ready'), \
                patch.object(self.runtime, 'environment', return_value=self.env), \
                patch.object(self.runtime, 'invocation') as invocation, \
                contextlib.redirect_stdout(output):
            self.assertEqual(self.runtime.run(self.argv, None, 'example-app', True, True), 0)
        invocation.assert_not_called()
        self.assertIn('--disable-gpu', json.loads(output.getvalue())['argv'])
        self.assertFalse(self.runtime.log.parent.exists())

    def test_stale_main_is_detected_but_children_and_matching_processes_are_not(self):
        _, report = self.launch(env=self.wayland())
        proc = self.config / 'proc'
        for pid, args, environ in (
            (101, ['example', '--no-sandbox'], b''),
            (102, ['example', '--no-sandbox', '--disable-gpu', '--ozone-platform', 'wayland'], b''),
            (103, ['example', '--type=renderer'], b''),
            (104, ['example', 'worker.js'], b'ELECTRON_RUN_AS_NODE=1\0'),
        ):
            path = proc / str(pid)
            path.mkdir(parents=True)
            (path / 'exe').symlink_to(self.directory / 'example')
            (path / 'cmdline').write_bytes('\0'.join(args).encode())
            (path / 'environ').write_bytes(environ)
        self.assertEqual(self.runtime.stale_electron_processes(report, proc), [101])


if __name__ == '__main__':
    unittest.main()
