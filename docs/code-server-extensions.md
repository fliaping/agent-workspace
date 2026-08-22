# code-server Extensions

Agent Workspace includes two optional code-server extensions:

- `extensions/service-manager`: unified s6 and systemd service view.
- `extensions/caddy-proxy-manager`: proxyctl-managed Caddy route view.
- `extensions/selkies-desktop`: one-click Selkies desktop with persistent
  client-side HiDPI, DPI, browser storage, zoom, and layout defaults.

Install them inside a running container:

```bash
agent-workspace-manager install code-server-extensions
```

The installer packages the sources with VSCE and installs the resulting VSIX
files through code-server's official CLI. Installed extensions are stored under:

```text
/config/.local/share/code-server/extensions
```

Reload the code-server window after installing:

```text
Developer: Reload Window
```

Extension JavaScript changes can keep the current extension version. Changes to
`package.json` contributions such as views, commands, or menus must increment
the extension version before installation. Official VSIX installation updates
code-server's extension registry and invalidates its manifest cache, so a full
code-server service restart is not required.

The extensions are plain JavaScript; VSIX packaging is handled by the installer.
Validate changes with:

```bash
node --check extensions/service-manager/extension.js
node --check extensions/caddy-proxy-manager/extension.js
node --check extensions/selkies-desktop/extension.js
```
