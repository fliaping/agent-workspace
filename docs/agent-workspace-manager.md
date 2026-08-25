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
- install the secure remote foundation (code-server, Control Center, and desktop integration)
- optionally install proxyctl and Caddy routing for an existing wildcard gateway
- optionally install a no-`NET_ADMIN` Tailscale userspace network
- register persistent custom s6 services
- install Codex, Claude Code, Hermes, DeepSeek Harness, OpenClaw, Openfang, or
  Zeroclaw as first-class manager actions
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
definitions from `scripts/agent-wizard.py`, then runs the install command and
prints the next onboarding command in the same log panel. Interactive CLIs
(Codex, Claude Code, and Hermes) stop there; DeepSeek Harness and other
daemon-style Agents additionally receive an enabled user service.

## CLI

The same operations are available for automation:

```bash
agent-workspace-manager update
agent-workspace-manager install foundation
agent-workspace-manager install code-server
agent-workspace-manager install proxyctl
agent-workspace-manager install desktop
agent-workspace-manager install tailscale
agent-workspace-manager install code-server-extensions
agent-workspace-manager install custom-services
agent-workspace-manager install agents
agent-workspace-manager install agents claude-code hermes deepseek-harness
agent-workspace-manager status
agent-workspace-manager doctor
```

`install all` installs the secure foundation plus all selected Agent runtimes.
The wildcard gateway remains an explicit `install proxyctl` step because it
requires deployment-specific DNS, TLS, and authentication decisions.

With no names, `install agents` installs Codex as the ready-to-use default.
Inside the workspace, `workspacectl` is the stable control surface Agents can
use to inspect or operate container capabilities. `workspacectl status --json`
is also the versioned backend used by Control Center.

Global resources are available from the same command surface:

```bash
workspacectl skills --json
workspacectl skill add <owner/repository>
workspacectl skill update
workspacectl mcp --json
workspacectl mcp add <name> --transport http --url <url> --agents all
workspacectl locale zh-cn --restart
workspacectl network domain workspace.example.com
workspacectl tailscale login
workspacectl tailscale serve
agent-workspace-manager install mcpm
```

Skills use the shared `/config/.agents/skills` source managed by `npx skills`.
MCPM is optional; when installed, new MCP definitions are stored once in MCPM
and each selected Agent connects through `mcpm run <name>`. Existing native
Codex, Claude Code, Hermes, and Agent Workspace-managed DeepSeek Harness MCP
entries remain visible and are not silently migrated. DeepSeek Harness also
discovers the shared `/config/.agents/skills` root natively.

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
/config/opt/code-server
/config/opt/tailscale
/config/.config/code-server
/config/proxyctl
/config/.local/share/code-server/extensions
/config/.local/share/tailscale
/config/custom-services.d
```
