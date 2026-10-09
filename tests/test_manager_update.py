import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("agent_workspace_manager", str(ROOT / "scripts/agent-workspace-manager"))
spec = importlib.util.spec_from_loader("agent_workspace_manager", loader)
manager_module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = manager_module  # dataclasses resolve annotations via sys.modules
loader.exec_module(manager_module)

GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"}


def git(*args, cwd=None):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True,
                   env={**os.environ, **GIT_ENV})


class UpdateSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.upstream = root / "upstream"
        git("init", "-q", "-b", "main", str(self.upstream))
        (self.upstream / "scripts").mkdir()
        (self.upstream / "scripts/agent-workspace-manager").write_text("#!/bin/sh\n")
        (self.upstream / "marker").write_text("main\n")
        git("add", "-A", cwd=self.upstream)
        git("commit", "-qm", "main", cwd=self.upstream)
        git("checkout", "-qb", "dev", cwd=self.upstream)
        (self.upstream / "marker").write_text("dev\n")
        git("commit", "-qam", "dev", cwd=self.upstream)
        git("checkout", "-q", "main", cwd=self.upstream)
        config = root / "config"
        self.settings = manager_module.Settings(
            config_root=config, state_root=config / "agent-workspace-manager",
            source_dir=config / "agent-workspace-manager/source",
            repo_url=f"file://{self.upstream}", repo_ref="main")
        self.manager = manager_module.WorkspaceManager(self.settings)
        controls = patch.object(manager_module.WorkspaceManager, "install_workspace_controls")
        controls.start()
        self.addCleanup(controls.stop)
        git_env = patch.dict(os.environ, GIT_ENV)
        git_env.start()
        self.addCleanup(git_env.stop)

    def marker(self) -> str:
        return (self.settings.source_dir / "marker").read_text().strip()

    def test_update_can_switch_to_another_branch_after_shallow_clone(self):
        self.manager.update_source()
        self.assertEqual(self.marker(), "main")
        self.manager.update_source(repo_ref="dev")
        self.assertEqual(self.marker(), "dev")
        self.manager.update_source(repo_ref="main")
        self.assertEqual(self.marker(), "main")


if __name__ == "__main__":
    unittest.main()
