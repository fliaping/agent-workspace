# Selkies Desktop

code-server extension for opening the local Selkies desktop with one click.

The extension:

- opens Selkies through the code-server same-origin `/proxy/3000/` route;
- opens a dedicated main-editor panel by default instead of Simple Browser;
- retains the panel while hidden and restores it with the workspace;
- provides reload, 50%-125% zoom, reset-to-100%, and external-open controls;
- can prefer VS Code's Integrated Browser if a future code-server host exposes it;
- writes HiDPI and UI DPI client preferences through a temporary same-origin
  bootstrap page before Selkies loads;
- adds a `Selkies` status-bar button;
- opens the desktop once after the extension is first installed.

No Selkies or nginx server files are modified. The bootstrap HTTP listener binds
to `127.0.0.1` on an ephemeral port and lives only inside the extension host.

## Commands

- `Selkies Desktop: Open`
- `Selkies Desktop: Reapply Client Defaults`

## Defaults

```text
URL:          https://ping-code.h1.fliaping.com:7555/proxy/3000/
Page zoom:    80%
Browser mode: dedicated panel
HiDPI:        enabled
UI DPI:       96 (100%)
Open startup: first installation only
```
