# Lightweight Subdomain Proxy

`proxyctl` manages a small Caddy-based HTTP router for a single Agent Workspace
container. It keeps configuration under `/config/proxyctl` and exposes a narrow
CLI so agents do not edit Caddy JSON directly.

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
proxyctl init
```

Inspect:

```bash
proxyctl list
proxyctl check
proxyctl render
```

Manage named routes:

```bash
proxyctl add app 127.0.0.1:3000
proxyctl add dashboard 127.0.0.1:9119 --upstream-host 127.0.0.1
proxyctl remove app
proxyctl rollback
```

Use `--upstream-host` for loopback services that validate the HTTP `Host`
header. The setting is stored with the route and survives `proxyctl init`.

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
