#!/usr/bin/env python3
"""Opt-in host install/replay test; requires passwordless sudo and apt repositories."""
import json
from pathlib import Path
import subprocess
import tempfile

NAME = 'agent-workspace-native-smoke'
BACKEND = '/config/bin/agent-workspace-deb-native'


def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout


def main():
    state = json.loads(run(BACKEND, 'list'))
    if NAME in state['packages'] or subprocess.run(
            ['dpkg-query', '-W', NAME], capture_output=True).returncode == 0:
        raise RuntimeError('Smoke package already exists; refusing to change it.')
    with tempfile.TemporaryDirectory(prefix='deb-native-smoke-', dir='/config/.cache') as directory:
        root = Path(directory) / 'package'
        for subdir in ('DEBIAN', 'usr/bin', 'usr/share/applications'):
            target = root / subdir
            target.mkdir(parents=True)
        # The desktop user's umask can be 0077; Debian control dirs need 0755.
        for path in [root, *root.rglob('*')]:
            path.chmod(0o755)
        (root / 'DEBIAN/control').write_text(
            f'Package: {NAME}\nVersion: 1.0\nArchitecture: all\nDepends: dash\n'
            'Maintainer: Workspace Tests <test@example.invalid>\nDescription: Native restore smoke test\n')
        binary = root / 'usr/bin' / NAME
        binary.write_text('#!/bin/sh\nprintf "native-smoke-ok\\n"\n')
        binary.chmod(0o755)
        (root / 'usr/share/applications' / (NAME + '.desktop')).write_text(
            '[Desktop Entry]\nType=Application\nName=Native restore test\n'
            f'Exec=/usr/bin/{NAME}\nTerminal=true\n')
        archive = Path(directory) / (NAME + '.deb')
        print(run('dpkg-deb', '--build', '--root-owner-group', str(root), str(archive)), flush=True)
        installed = False
        try:
            print(run(BACKEND, 'install', '--yes', str(archive)), flush=True)
            installed = True
            launcher = Path(run(BACKEND, 'launcher', NAME).strip())
            assert launcher.is_file() and 'Native' in launcher.read_text()
            assert 'native-smoke-ok' in run(BACKEND, 'run', '--package', NAME, '--', '/usr/bin/' + NAME)
            log = Path('/config/.local/log/agent-workspace/deb-native.log')
            before = log.stat().st_size
            print(run(BACKEND, 'restore', '--yes'), flush=True)
            assert log.stat().st_size == before, 'No-op restore unexpectedly ran apt'
            print(run('sudo', '-n', 'dpkg', '--remove', NAME), flush=True)
            assert not Path('/usr/bin', NAME).exists()
            print(run(BACKEND, 'restore', '--yes'), flush=True)
            assert 'native-smoke-ok' in run('/usr/bin/' + NAME)
            print('PASS: native install, launcher, run, no-op restore, and missing-package recovery.', flush=True)
        finally:
            if installed:
                print(run(BACKEND, 'remove', '--yes', NAME), flush=True)
                assert NAME not in json.loads(run(BACKEND, 'list'))['packages']
                assert not launcher.exists()


if __name__ == '__main__':
    main()
