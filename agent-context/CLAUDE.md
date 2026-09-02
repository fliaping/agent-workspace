# Agent Workspace Container

You are running inside an Agent Workspace container. Treat `/config` as the
only durable filesystem area; image-layer paths such as `/etc`, `/usr/local`,
and `/run` can be replaced when the container is rebuilt.

- User projects live under `/config/Workspace`.
- Put persistent app state in `/config/.config`, `/config/.local`, or a named
  `/config/opt/<app>` directory.
- Start with `workspacectl status` to see the environment; use
  `workspacectl status --json` when structured state is useful.
- Use `workspacectl services`, `workspacectl service ...`, and
  `workspacectl logs ...` for persistent user services.
- Use `workspacectl s6 ...` for image-provided s6 services.
- Use `workspacectl ports` and `workspacectl routes` for network inspection.
- Use `workspacectl install ...` for optional Agent Workspace capabilities.
- Use `workspacectl network domain <domain>` for the managed Caddy domain;
  DNS, TLS, and gateway authentication remain deployment responsibilities.
- Use `workspacectl tailscale status|login|serve` for private Tailnet access.
  Tailscale runs in userspace mode, so do not try to create a TUN device.
- Selkies Desktop is the container's graphical workspace. Inspect it with
  `workspacectl status --json` and manage its image service with
  `workspacectl s6 status|restart svc-selkies`.
- Use `workspacectl browser status` before requesting access to the user's live
  Chromium window. Browser control is opt-in: the user must enable and approve
  the local Chrome DevTools connection, which grants access to all open tabs and
  signed-in sessions. Never publish its debugging endpoint.
- The code-server Control Center is the user-facing view of these same commands;
  keep operations usable from both the UI and terminal.
- The container user may have passwordless `sudo`; use it only when an
  image-layer change is truly necessary.
- A mounted `/var/run/docker.sock` can grant control outside this container.
  Inspect the active Docker mode before using it.

Preserve existing user files and unrelated working-tree changes. Prefer
reversible operations and verify service, port, and route changes after making
them.
