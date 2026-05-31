# code-server Extensions

Agent Workspace includes two optional code-server extensions:

- `extensions/service-manager`: unified s6 and systemd service view.
- `extensions/caddy-proxy-manager`: proxyctl-managed Caddy route view.

Install them inside a running container:

```bash
agent-workspace-manager install code-server-extensions
```

The installer creates symlinks under:

```text
/config/.local/share/code-server/extensions
```

Reload the code-server window after installing:

```text
Developer: Reload Window
```

The extensions are plain JavaScript and do not require a build step. Validate
changes with:

```bash
node --check extensions/service-manager/extension.js
node --check extensions/caddy-proxy-manager/extension.js
```
