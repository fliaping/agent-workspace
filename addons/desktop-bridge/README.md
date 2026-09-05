# Desktop Computer Use

`agent-desktop-bridge` controls the same Wayland framebuffer used by the active
Selkies session. PixelFlux exposes its native Computer Use API on internal port
`8764`; the bridge listens on `127.0.0.1:8765`, adds a persistent
pause state, active-session reporting, validation, and emergency stop.

Install and inspect it through the normal control surface:

```bash
agent-workspace-manager install computer-use
workspacectl desktop status
workspacectl desktop emergency-stop
workspacectl desktop resume
```

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
