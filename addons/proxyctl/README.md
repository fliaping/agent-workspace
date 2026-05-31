# Lightweight Subdomain Proxy

This package implements a small HTTP-only subdomain proxy for a single LinuxServer.io-style container.

Architecture:

```text
external gateway
  *.dev.example.com -> this container :80

Caddy
  named routes     -> direct upstreams managed by proxyctl
  code subdomain   -> code-server
  wildcard fallback -> code-server port proxy

code-server --proxy-domain dev.example.com
  3000.dev.example.com -> 127.0.0.1:3000
```

## Install Layout

Copy or mount this repository into the container, for example:

```text
/config/proxyctl/package
```

Install everything on this host:

```bash
PROXY_ROOT_DOMAIN=ping-dev.h1.fliaping.com ./install.sh
```

The installer:

```text
1. Copies this package to /config/proxyctl/package
2. Installs caddy to /config/proxyctl/bin/caddy
3. Installs code-server under /config/proxyctl/code-server-<version>
4. Registers persistent user services in /config/.config/systemd/user
5. Initializes Caddy through proxyctl
```

Only `/config` is required for persistence. On container rebuild, the image's existing
`systemctl-services` s6 service starts enabled user services from
`/config/.config/systemd/user/default.target.wants`.

The installer also puts the runtime binaries in:

```text
/config/proxyctl/bin
```

Add this directory to `PATH` for interactive shells:

```bash
export PATH="/config/proxyctl/bin:$PATH"
```

The current install writes that line to `/config/.bashrc` and `/config/.profile`.

Manual CLI install:

```bash
ln -sf /config/proxyctl/package/bin/proxyctl /usr/local/bin/proxyctl
chmod +x /config/proxyctl/package/bin/proxyctl
```

Persistent custom s6 services should live under `/config`, so they survive
container rebuilds:

```text
/config/custom-services.d/<service-name>/run
```

The base image should include `scripts/register-config-services.sh` and link it
into LinuxServer's custom-init directory:

```dockerfile
RUN mkdir -p /custom-cont-init.d \
    && ln -sf /usr/local/bin/register-config-services.sh /custom-cont-init.d/zz-register-config-services.sh
```

At startup it scans `/config/custom-services.d`, recreates `/run/service`
symlinks, and asks s6 to rescan. This avoids bind-mounting `/custom-cont-init.d`
or replacing image-provided init scripts.

For LinuxServer.io `code-server`, also set:

```bash
PROXY_DOMAIN=dev.example.com
```

That causes code-server to use subdomain port proxying for hosts like `3000.dev.example.com`.

This installation starts code-server with:

```bash
--auth none
```

Authentication is expected to happen at the upstream gateway.

## Environment

Required:

```bash
PROXY_ROOT_DOMAIN=dev.example.com
```

Recommended:

```bash
CODE_SERVER_TARGET=127.0.0.1:8443
CODE_SERVER_PROXY_DOMAIN=ping-dev.h1.fliaping.com:7555
CODE_SERVER_SUBDOMAIN=code
CADDY_ADMIN=http://127.0.0.1:2019
PROXY_LISTEN=:8080
```

For the current deployment, the external gateway uses:

```text
https://*.ping-dev.h1.fliaping.com:7555 -> host:8050 -> container:8080
```

So Caddy listens on container port `8080`, while code-server advertises port-proxy
URLs with the external `:7555` port.

Security defaults:

```bash
PROXY_ALLOWED_TARGETS=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
PROXY_ALLOW_TARGET_HOSTNAMES=0
```

## Initialize

After Caddy is running:

```bash
proxyctl init
```

This creates:

```text
code.dev.example.com -> 127.0.0.1:8443
*.dev.example.com    -> 127.0.0.1:8443
```

The wildcard lets code-server handle port subdomains like `3000.dev.example.com`.

## Manage Named Services

Add or replace:

```bash
proxyctl add app 127.0.0.1:3000
proxyctl add api 127.0.0.1:8080
```

Remove:

```bash
proxyctl remove app
```

Inspect:

```bash
proxyctl list
proxyctl check
proxyctl render
```

Service status:

```bash
systemctl --user status proxy-caddy.service
systemctl --user status code-server.service
```

Restart services:

```bash
systemctl --user restart proxy-caddy.service
systemctl --user restart code-server.service
```

## Futu OpenD

OpenD is stored outside Downloads in a persistent runtime directory:

```text
/config/futu-opend
```

The custom s6 service uses:

```text
/config/custom-services.d/futu-opend/run
```

`/run/service` is recreated at runtime. The image-level startup hook is:

```text
/custom-cont-init.d/zz-register-config-services.sh
```

That hook scans `/config/custom-services.d`, then recreates runtime links like:

```text
/run/service/futu-opend -> /config/custom-services.d/futu-opend
```

For container rebuilds, `/config` is enough:

```text
./home -> /config
```

Configure credentials in `/config/futu-opend/FutuOpenD.xml`, then restart with:

```bash
s6-svc -r /run/service/futu-opend
```

## code-server Service Manager Extension

This package includes a code-server extension for managing local `s6` and
`systemd` services from one sidebar view:

```text
extensions/service-manager
```

The extension is installed in the current container with:

```bash
/config/.local/share/code-server/extensions/agent-workspace.unified-service-manager-0.1.0 \
  -> /config/agent-workspace-manager/source/extensions/service-manager
```

It discovers `s6` services from `/run/service`, user `systemd` services from
`systemctl --user list-unit-files`, and system `systemd` services from
`systemctl list-unit-files`. Use the `Services` activity bar item to refresh,
start, stop, restart, and inspect services.

`Show Details` includes description, active status, main PID, listening TCP
ports discovered from `/proc`, process information, and recent logs. Logs use
`journalctl` when available and fall back to known `/config` log files in this
container.

## code-server Caddy Proxy Extension

This package also includes a code-server extension for managing Caddy routes
through `proxyctl`:

```text
extensions/caddy-proxy-manager
```

The extension is installed in the current container with:

```text
/config/.local/share/code-server/extensions/agent-workspace.caddy-proxy-manager-0.1.0
-> /config/agent-workspace-manager/source/extensions/caddy-proxy-manager
```

It reads `/config/proxyctl/env` and `/config/proxyctl/routes.json`, then uses
`/config/proxyctl/bin/proxyctl` for route changes. It can add/remove routes,
run health checks, render the generated Caddy config, show access/service logs,
roll back the last route change, and open public route URLs.

Rollback the last named-route change:

```bash
proxyctl rollback
```

## AI Tool Contract

Automation should only call:

```bash
proxyctl add <subdomain> <host:port>
proxyctl remove <subdomain>
proxyctl list
proxyctl check
```

It should not edit Caddy files directly.
