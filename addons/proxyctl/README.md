# Custom-domain Routing Backend

Agent Workspace uses a small Caddy-based HTTP router for optional custom-domain
access. Users and agents manage it through `workspacectl`; configuration and
runtime files remain under `/config/proxyctl` for upgrade compatibility.

## Routing Model

Example public routes:

```text
https://code.dev.example.com       -> code-server 127.0.0.1:8443
https://3000.dev.example.com       -> code-server's authenticated port proxy
```

`PROXY_PORT_ROUTING=code-server` is the secure default: numeric development
ports stay behind code-server authentication. Set it to `direct` only when an
upstream gateway authenticates every matching hostname.

## Environment

```bash
PROXY_ROOT_DOMAIN=dev.example.com
PROXY_HOST_PREFIXES=
PROXY_PORT_ROUTING=code-server
PROXY_LISTEN=:80
PROXY_ACCESS_LOG=/config/proxyctl/access.log
CADDY_ADMIN=http://127.0.0.1:2019
CODE_SERVER_TARGET=127.0.0.1:8443
CODE_SERVER_SUBDOMAIN=code
CODE_SERVER_PROXY_DOMAIN={{port}}.dev.example.com
```

Legacy `PROXY_HOST_PREFIX` and `PROXY_API_HOST_PREFIX` are still accepted, but
new deployments should use `PROXY_HOST_PREFIXES`.

For a trusted gateway that already authenticates `ping-*` and `api-ping-*`, a
deployment can instead use:

```bash
PROXY_HOST_PREFIXES=ping,api-ping
PROXY_PORT_ROUTING=direct
CODE_SERVER_AUTH=none
CODE_SERVER_ALLOW_NO_AUTH=true
CODE_SERVER_CERT=false
CODE_SERVER_PROXY_DOMAIN=ping-{{port}}.example.com
```

## Commands

Initialize or reload Caddy from current state:

```bash
workspacectl proxy init
```

Inspect:

```bash
workspacectl routes
workspacectl proxy check
workspacectl proxy render
```

Manage named routes:

```bash
workspacectl proxy add app 127.0.0.1:3000
workspacectl proxy add dashboard 127.0.0.1:9119 --upstream-host 127.0.0.1
workspacectl proxy remove app
workspacectl network domain workspace.example.com
workspacectl proxy rollback
```

`workspacectl network domain` safely migrates managed route hostnames, updates
the root domain, keeps a backup, and schedules the required code-server restart.

Use `--upstream-host` for loopback services that validate the HTTP `Host`
header. The setting is stored with the route and survives
`workspacectl proxy init`.

Logs:

```bash
tail -f /config/proxyctl/access.log
tail -n 100 /config/.local/log/user-systemd/proxy-caddy.log
```

Services:

```bash
systemctl --user status proxy-caddy.service
systemctl --user restart proxy-caddy.service
systemctl --user status code-server.service
```

## Persistence

Only `/config` is required for persistence:

```text
/config/proxyctl
/config/.config/systemd/user
/config/.local/share/code-server
```
