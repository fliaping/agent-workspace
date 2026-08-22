# Common Software

This document records reusable software capabilities that should stay useful
across Agent Workspace deployments. Keep runtime state under `/config`.

## proxyctl + Caddy

Purpose: lightweight HTTP routing for subdomain-based service exposure.

Install or refresh:

```bash
agent-workspace-manager install proxyctl
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
proxyctl list
proxyctl add app 127.0.0.1:3000
proxyctl remove app
proxyctl check
tail -f /config/proxyctl/access.log
```

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
  proxy routes, access, and diagnostics.
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
