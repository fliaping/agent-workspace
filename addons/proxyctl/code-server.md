# code-server Integration

code-server is installed independently through `addons/code-server`. This
keeps IDE upgrades and rollback separate from Caddy.

For a public wildcard domain, configure the matching proxy domain while
installing code-server:

```bash
CODE_SERVER_PROXY_DOMAIN='{{port}}.dev.example.com' \
CODE_SERVER_CERT=false \
agent-workspace-manager install code-server
```

The default `PROXY_PORT_ROUTING=code-server` sends numeric subdomains through
code-server, preserving its password authentication. `direct` routing is only
appropriate when an upstream gateway authenticates every matching hostname:

```bash
PROXY_PORT_ROUTING=direct
```
