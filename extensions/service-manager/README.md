# Unified Service Manager

code-server extension for inspecting and controlling local `s6` and `systemd` services.

It discovers:

- `s6` services from `/run/service`
- user `systemd` services from `systemctl --user list-unit-files`
- system `systemd` services from `systemctl list-unit-files`

Supported actions:

- Browse native sidebar views for Favorites, Running, and All services
- Add and remove persistent favorites
- Start
- Stop
- Restart
- Show details
- Refresh

Details include:

- Description
- Active status and unit/service path
- Main PID and process group where available
- Listening TCP ports discovered from `/proc`
- Process list/tree
- Recent logs from `journalctl` when available, with `/config` log-file fallbacks

The extension intentionally shells out to the local service managers, so permissions match the user running code-server.
