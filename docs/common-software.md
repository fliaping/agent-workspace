# Common Software

This document records reusable software capabilities that should stay useful
across Agent Workspace deployments. Keep runtime state under `/config`.

## Custom-domain routing

Purpose: lightweight HTTP routing for subdomain-based service exposure.
`workspacectl` is the supported user and Agent interface; it installs and uses
the Caddy routing backend automatically.

Configure or migrate the root domain:

```bash
workspacectl network domain workspace.example.com
```

Current routing model:

```text
ping-code.h1.fliaping.com:7555       -> code-server
ping-<port>.h1.fliaping.com:7555     -> 127.0.0.1:<port>
api-ping-<port>.h1.fliaping.com:7555 -> 127.0.0.1:<port>
```

`PROXY_HOST_PREFIXES` accepts multiple comma-separated prefixes. Gateway auth is
handled outside Caddy, so Caddy treats all prefixes uniformly.

Common commands:

```bash
workspacectl routes
workspacectl proxy add app 127.0.0.1:3000
workspacectl proxy remove app
workspacectl proxy check
tail -f /config/proxyctl/access.log
```

The persisted `/config/proxyctl` directory is an internal implementation detail.
It contains Caddy and routing state, but no separate CLI is required.

## Tailscale userspace network

Purpose: private tailnet access without opening a public port or granting the
container `NET_ADMIN`.

```bash
agent-workspace-manager install tailscale
workspacectl tailscale login
workspacectl tailscale serve
systemctl --user status tailscaled-workspace.service
```

Runtime, identity, and logs persist under `/config/opt/tailscale`,
`/config/.local/share/tailscale`, and `/config/.local/log/user-systemd`.

## DeepSeek Harness

Purpose: official plugin-based DeepSeek coding Agent with Web and headless
surfaces.

```bash
agent-workspace-manager install agent deepseek-harness
systemctl --user status deepseek-harness.service
deepseek-harness headless "inspect this workspace"
```

The Web UI is loopback-only on `127.0.0.1:3080` and opens through the existing
code-server gateway session at `/proxy/3080/`. Runtime state and credentials
persist under `/config/.dsh`; the official UI keeps stored API keys write-only.

## code-server

Purpose: browser-based VS Code environment and workspace access.

Service:

```bash
systemctl --user status code-server.service
systemctl --user restart code-server.service
```

Main URL:

```text
https://ping-code.h1.fliaping.com:7555
```

Auth is disabled in code-server; authentication is expected at the gateway.

## Desktop browser control

Purpose: let a trusted Agent inspect and operate the Chromium window already in
use on the Selkies desktop, including its current tabs and signed-in state.

```bash
workspacectl browser status
workspacectl browser setup
workspacectl browser approve
```

The setup command adds `chrome-devtools-mcp` to installed Agents with
consent-based auto-connect and opens `chrome://inspect/#remote-debugging` in the
desktop browser. The user enables remote debugging there and approves each Agent
connection. It does not restart Chromium, copy its profile, contend with
`SingletonLock`, or publish a debugging port outside the container.

An approved Agent receives the browser profile's live tabs, cookies, local
storage, and authenticated sessions. Keep this capability opt-in and grant it
only to trusted Agents.

## User Service Manager

Purpose: persistent service control inside the container without full systemd.

Unit files live in:

```text
/config/.config/systemd/user
```

Common commands:

```bash
systemctl --user status <service>
systemctl --user restart <service>
systemctl --user show <service> --property ActiveState,SubState,MainPID,Result
tail -n 100 /config/.local/log/user-systemd/<service>.log
```

## Custom s6 Services

Purpose: persistent s6 service definitions that survive container rebuilds.

Put service directories under:

```text
/config/custom-services.d/<name>/run
```

The startup registration flow recreates runtime links under `/run/service`.

## Code-Server Extensions

Purpose: in-browser operational tools.

Install or refresh:

```bash
agent-workspace-manager install code-server-extensions
```

Current reusable extensions:

- `control-center`: unified onboarding and daily control for Agents, services,
  desktop, custom-domain and Tailscale access, proxy routes, and diagnostics.
- `selkies-desktop`: embedded desktop integration opened from Control Center.

Legacy `service-manager` and `caddy-proxy-manager` sources remain available for
focused development, but the normal installer removes their separate Activity
Bar entries after installing Control Center.

## Homebrew

Purpose: persistent user-space package manager for optional tools.

Path:

```text
/config/.linuxbrew
```

Use:

```bash
brew install <package>
brew list
```

## Node Runtime

Purpose: persistent JavaScript runtime and global tools.

Path:

```text
/config/node
```

Use normal Node/npm commands after the runtime is on `PATH`.
