# Tailscale userspace network

This optional capability installs Tailscale's official static binaries under
`/config/opt/tailscale` and runs `tailscaled` without `/dev/net/tun` or
`NET_ADMIN`. Durable identity is stored in `/config/.local/share/tailscale`.

Install and connect interactively:

```bash
agent-workspace-manager install tailscale
tailscale up --hostname=agent-workspace --accept-dns=false
```

The login URL stays in the terminal; auth keys are never stored by Control
Center. After sign-in, expose the complete code-server workspace (including
its `/proxy/3000` Selkies route) only to the tailnet:

```bash
tailscale serve --bg http://127.0.0.1:8443
tailscale serve status --json
```

The local SOCKS5 and HTTP proxy is `127.0.0.1:1055`. The client wrapper always
uses the private daemon socket at `/config/.local/run/tailscale/tailscaled.sock`.
