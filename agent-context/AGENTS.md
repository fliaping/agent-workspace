# Agent Workspace Container

You are running inside an Agent Workspace container. Treat `/config` as the
only durable filesystem area; image-layer paths such as `/etc`, `/usr/local`,
and `/run` can be replaced when the container is rebuilt.

- User projects live under `/config/Workspace`.
- Put persistent app state in `/config/.config`, `/config/.local`, or a named
  `/config/opt/<app>` directory.
- Start with `workspacectl info` to see privileges and the Docker boundary.
- Use `workspacectl services`, `workspacectl service ...`, and
  `workspacectl logs ...` for persistent user services.
- Use `workspacectl s6 ...` for image-provided s6 services.
- Use `workspacectl ports` and `workspacectl routes` for network inspection.
- Use `workspacectl install ...` for optional Agent Workspace capabilities.
- The container user may have passwordless `sudo`; use it only when an
  image-layer change is truly necessary.
- A mounted `/var/run/docker.sock` can grant control outside this container.
  Inspect the active Docker mode before using it.

Preserve existing user files and unrelated working-tree changes. Prefer
reversible operations and verify service, port, and route changes after making
them.
