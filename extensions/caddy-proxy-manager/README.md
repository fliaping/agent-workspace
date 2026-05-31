# Caddy Proxy Manager

code-server extension for viewing and managing `proxyctl`-managed Caddy routes.

It reads state from `/config/proxyctl` and uses `/config/proxyctl/bin/proxyctl`
for mutations. It does not edit generated Caddy JSON directly.

Features:

- Show proxy environment and named routes
- Add a named route
- Remove a named route
- Run `proxyctl check`
- Show generated Caddy config
- Tail Caddy access logs and service logs
- Roll back the last route change
- Open a public route URL

After changes, reload code-server with `Developer: Reload Window`.
