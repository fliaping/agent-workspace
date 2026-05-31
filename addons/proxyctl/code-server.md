# code-server Integration

Start code-server with a proxy domain that matches the wildcard domain routed to this machine.

Example:

```bash
code-server --proxy-domain dev.example.com
```

For the LinuxServer.io `code-server` image, set:

```bash
PROXY_DOMAIN=dev.example.com
```

Then:

```text
code.dev.example.com -> code-server itself
3000.dev.example.com -> code-server proxies to 127.0.0.1:3000
5173.dev.example.com -> code-server proxies to 127.0.0.1:5173
```

Named long-lived services should be registered with `proxyctl`:

```bash
proxyctl add app 127.0.0.1:3000
```

Named routes are placed before the wildcard route, so `app.dev.example.com` is handled by Caddy directly while numeric port subdomains continue to fall through to code-server.
