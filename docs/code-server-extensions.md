# code-server Control Center

Agent Workspace presents one code-server Activity Bar entry for onboarding and
daily operations:

- `extensions/control-center`: five-step first-run guide plus Overview, Agents,
  Services, Network, and Diagnostics pages.
- `extensions/selkies-desktop`: embedded Selkies desktop support used by the
  Control Center's **Open desktop** action.

The UI is unified, while its components remain decoupled. Control Center reads
the versioned `workspacectl status --json` contract and sends mutations back
through `workspacectl`; proxy routing and service supervision therefore remain
usable from a terminal or by any installed Agent.

Install or refresh the extensions inside a running container:

```bash
agent-workspace-manager install code-server-extensions
```

The installer packages source with VSCE, installs the VSIX files through the
code-server CLI, and removes legacy standalone Services and Caddy sidebar
extensions. Installed extensions are persisted under:

```text
/config/.local/share/code-server/extensions
```

Reload the code-server window after an upgrade:

```text
Developer: Reload Window
```

On a fresh profile, Control Center opens automatically until its guide is
completed or skipped. It can always be reopened from the Agent Workspace icon
or from `Agent Workspace: Show Getting Started` in the Command Palette.

The layout follows the active VS Code theme, uses a compact sidebar summary and
a responsive editor-area dashboard, and collapses cleanly on narrow screens.
Its operational pages are:

- **Overview**: readiness, durable workspace, quick actions, and Docker boundary.
- **Agents**: install or launch Codex, Claude Code, and Hermes.
- **Services**: filter and operate persistent user services and s6 services.
- **Network**: access URLs, listening ports, Docker boundary, and optional
  proxyctl routes.
- **Diagnostics**: capability state, environment checks, source update, and
  operation logs.

The historical `extensions/service-manager` and
`extensions/caddy-proxy-manager` directories remain as reference modules, but
normal installations no longer expose their separate Activity Bar containers.

Validate extension changes with:

```bash
node --check extensions/control-center/extension.js
node --check extensions/selkies-desktop/extension.js
```

Changes to `package.json` contributions must increment the extension version so
code-server invalidates its manifest cache during installation.
