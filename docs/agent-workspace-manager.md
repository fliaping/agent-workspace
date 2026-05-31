# Agent Workspace Manager

`agent-workspace-manager` is the application-layer bootstrapper for Agent
Workspace.

The container image should remain stable and focus on operating-system
dependencies, desktop/runtime tooling, and base s6 services. Application
capabilities are installed and updated under `/config`, so they survive
container rebuilds and can evolve without rebuilding the image.

## TUI

Run inside the container:

```bash
agent-workspace-manager
```

The TUI can:

- update the manager source under `/config/agent-workspace-manager/source`
- install proxyctl and Caddy routing
- install code-server extensions
- register persistent custom s6 services
- install OpenClaw, Openfang, or Zeroclaw as first-class manager actions
- show capability status and run environment checks

Keyboard controls:

- `Up` / `Down`: move through the action list
- `Enter`: run the selected action
- `r`: refresh status
- `u`: update application source
- `f`: install the foundation capability set
- `q`: quit

Long-running operations stay inside the TUI. Child process stdout/stderr is
captured and appended to the log panel instead of writing directly to the
terminal.

Agent installation is not a nested TUI. The manager reuses the shared Agent
definitions from `scripts/agent-wizard.py`, then runs the install command,
creates the user service, enables and starts it, and prints the next onboarding
command in the same log panel.

## CLI

The same operations are available for automation:

```bash
agent-workspace-manager update
agent-workspace-manager install foundation
agent-workspace-manager install proxyctl
agent-workspace-manager install code-server-extensions
agent-workspace-manager install custom-services
agent-workspace-manager install agents
agent-workspace-manager status
agent-workspace-manager doctor
```

## Source Location

Default source path:

```text
/config/agent-workspace-manager/source
```

Use a local checkout during development:

```bash
AGENT_WORKSPACE_SOURCE_DIR=/config/Workspace/agent-workspace agent-workspace-manager
```

## Persistent Layout

Application state is kept under `/config`:

```text
/config/agent-workspace-manager
/config/proxyctl
/config/.local/share/code-server/extensions
/config/custom-services.d
```
