# Desktop Computer Use

`agent-desktop-bridge` controls the same Wayland framebuffer used by the active
Selkies session. PixelFlux exposes its native Computer Use API on internal port
`8764`; the bridge listens on `127.0.0.1:8765`, adds a persistent
pause state, active-session reporting, validation, and emergency stop.

Install and inspect it through the normal control surface:

```bash
agent-workspace-manager install computer-use
workspacectl desktop status
workspacectl desktop screenshot --output /config/Downloads/desktop.png
workspacectl desktop emergency-stop
workspacectl desktop resume
```

On an older running image, installation stages `PIXELFLUX_CU=8764` for the
next Selkies start. The bridge unit's environment does not configure Selkies.
If status reports `native-backend-disabled`, save desktop work, then run
`sudo -n s6-svc -r /run/service/svc-selkies`. This can terminate the nested KDE
session and its applications; installation does not restart it automatically.
For an unattended initial setup, explicitly set `AGENT_DESKTOP_RESTART_SELKIES=1`.
New images have the setting in Dockerfile ENV; rebuilding from an older image
requires adding `PIXELFLUX_CU=8764` to the container environment.

If the bridge's default port `8765` is occupied, write a free port number to
`/config/.config/agent-workspace/desktop-bridge-port` and restart
`agent-desktop-bridge.service`. The CLI and MCP adapter read the same persistent
setting. Explicit `AGENT_DESKTOP_BRIDGE_PORT` / `AGENT_DESKTOP_BRIDGE_URL`
environment overrides still take precedence. Reconnect Agent MCP sessions after
updating an older adapter that does not support this setting.

The installer registers `/config/bin/agent-desktop-mcp` with every installed
Codex, Claude Code, Hermes, and DeepSeek Harness client. Agents receive tools
for screenshot/crop, cursor position, move, click, drag, scroll, keys, text,
window discovery/focus, status, emergency stop, and resume.

The bridge is a trusted-single-user boundary, not a sandbox between processes
inside the container. Any trusted Agent with desktop access can see sensitive
content and send input. Upstream PixelFlux binds `8764` to the container
interface, so never publish either port or join an untrusted Docker network. Prefer managed
Chromium CDP for web pages and use this capability only for native GUI apps.

Wayland toplevel enumeration is compositor-dependent. The bridge always marks
its XWayland-derived window list as partial. Visual focus (screenshot, then
focus by coordinate) works on every backend; XWayland IDs and Wayland
title/app-id matching are used when the compositor exposes them.
