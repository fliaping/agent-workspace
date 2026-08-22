#!/usr/bin/env python3
"""Stable JSON inspection backend for Agent Workspace Control Center."""

from __future__ import annotations

import datetime as dt
import functools
import json
import os
import pathlib
import pwd
import shutil
import socket
import subprocess
import sys
from typing import Any


CONFIG_ROOT = pathlib.Path(os.environ.get("AGENT_WORKSPACE_CONFIG_ROOT", "/config"))
WORKSPACE_ROOT = pathlib.Path(
    os.environ.get("AGENT_WORKSPACE_ROOT", str(CONFIG_ROOT / "Workspace"))
)
STATE_ROOT = CONFIG_ROOT / ".local/state/agent-workspace"
USER_UNIT_ROOT = CONFIG_ROOT / ".config/systemd/user"
LOG_ROOT = CONFIG_ROOT / ".local/log/user-systemd"
SOURCE_ROOT = pathlib.Path(
    os.environ.get(
        "AGENT_WORKSPACE_SOURCE_DIR",
        str(CONFIG_ROOT / "agent-workspace-manager/source"),
    )
)

AGENT_DEFINITIONS = (
    {
        "id": "codex",
        "label": "Codex",
        "binary": "codex",
        "install_name": "codex",
        "launch": "codex",
        "accent": "violet",
    },
    {
        "id": "claude-code",
        "label": "Claude Code",
        "binary": "claude",
        "install_name": "claude-code",
        "launch": "claude",
        "accent": "amber",
    },
    {
        "id": "hermes",
        "label": "Hermes Agent",
        "binary": "hermes",
        "install_name": "hermes",
        "launch": "hermes setup --portal",
        "accent": "cyan",
    },
)


def run(
    args: list[str],
    *,
    timeout: float = 5,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    merged_env.setdefault("HOME", str(CONFIG_ROOT))
    if env:
        merged_env.update(env)
    try:
        return subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=merged_env,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(args, 127, "", str(exc))


def command_path(name: str) -> str:
    return shutil.which(name) or ""


@functools.lru_cache(maxsize=1)
def passwordless_sudo() -> bool:
    return bool(command_path("sudo")) and run(["sudo", "-n", "true"], timeout=2).returncode == 0


def command_version(path: str) -> str:
    if not path:
        return ""
    result = run([path, "--version"], timeout=5)
    output = result.stdout.strip() or result.stderr.strip()
    return output.splitlines()[0] if output else ""


def is_writable(path: pathlib.Path) -> bool:
    return path.is_dir() and os.access(path, os.W_OK)


def git_revision() -> str:
    if not (SOURCE_ROOT / ".git").is_dir():
        return ""
    result = run(["git", "-C", str(SOURCE_ROOT), "rev-parse", "--short", "HEAD"])
    return result.stdout.strip() if result.returncode == 0 else ""


def docker_boundary() -> dict[str, Any]:
    docker = command_path("docker")
    socket_path = pathlib.Path("/var/run/docker.sock")
    if socket_path.is_socket():
        return {
            "mode": "socket",
            "state": "elevated",
            "label": "Docker socket connected",
            "detail": "The Agent may control containers reachable through the mounted socket.",
            "cli": docker,
            "daemon_reachable": True,
            "risk": "high",
        }
    if docker:
        result = run([docker, "info"], timeout=4)
        if result.returncode == 0:
            return {
                "mode": "isolated",
                "state": "ready",
                "label": "Isolated Docker available",
                "detail": "The Agent can create containers in the workspace Docker daemon.",
                "cli": docker,
                "daemon_reachable": True,
                "risk": "medium",
            }
        return {
            "mode": "unavailable",
            "state": "safe",
            "label": "Docker disabled",
            "detail": "The CLI is installed, but no Docker daemon is reachable.",
            "cli": docker,
            "daemon_reachable": False,
            "risk": "low",
        }
    return {
        "mode": "disabled",
        "state": "safe",
        "label": "Docker disabled",
        "detail": "No Docker CLI or daemon is available inside this workspace.",
        "cli": "",
        "daemon_reachable": False,
        "risk": "low",
    }


def workspace_info() -> dict[str, Any]:
    try:
        username = pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        username = str(os.getuid())
    sudo = run(["sudo", "-n", "true"], timeout=2).returncode == 0
    return {
        "user": username,
        "uid": os.getuid(),
        "gid": os.getgid(),
        "home": os.environ.get("HOME", str(CONFIG_ROOT)),
        "root": str(WORKSPACE_ROOT),
        "persistent_root": str(CONFIG_ROOT),
        "writable": is_writable(CONFIG_ROOT),
        "sudo": {
            "available": sudo,
            "label": "Passwordless container administration" if sudo else "Unavailable",
        },
        "docker": docker_boundary(),
    }


def agents() -> list[dict[str, Any]]:
    selected = os.environ.get("AGENT_WORKSPACE_AGENT", "")
    rows: list[dict[str, Any]] = []
    for definition in AGENT_DEFINITIONS:
        path = command_path(str(definition["binary"]))
        row = dict(definition)
        row.update(
            {
                "state": "ready" if path else "missing",
                "installed": bool(path),
                "path": path,
                "version": command_version(path),
                "selected": selected == definition["id"],
            }
        )
        rows.append(row)
    return rows


def systemd_user_services() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    wants = USER_UNIT_ROOT / "default.target.wants"
    if not USER_UNIT_ROOT.is_dir():
        return rows
    for unit in sorted(USER_UNIT_ROOT.glob("*.service")):
        name = unit.stem
        active = run(["systemctl", "--user", "is-active", unit.name], timeout=3)
        status = active.stdout.strip() or "inactive"
        if status not in {"active", "inactive", "failed", "activating", "deactivating"}:
            status = "active" if active.returncode == 0 else "inactive"
        pid_file = CONFIG_ROOT / ".local/run/user-systemd" / f"{name}.pid"
        pid = 0
        try:
            pid = int(pid_file.read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            pass
        description = ""
        try:
            for line in unit.read_text(encoding="utf-8").splitlines():
                if line.startswith("Description="):
                    description = line.partition("=")[2]
                    break
        except OSError:
            pass
        rows.append(
            {
                "id": name,
                "unit": unit.name,
                "name": description or name,
                "kind": "systemd",
                "scope": "user",
                "status": "running" if status == "active" else status,
                "enabled": (wants / unit.name).is_symlink(),
                "pid": (pid or None) if status == "active" else None,
                "log": str(LOG_ROOT / f"{name}.log"),
            }
        )
    return rows


def s6_services() -> list[dict[str, Any]]:
    service_root = pathlib.Path("/run/service")
    if not service_root.is_dir():
        return []
    rows: list[dict[str, Any]] = []
    for service in sorted(
        (item for item in service_root.iterdir() if item.is_dir() and not item.name.startswith(".")),
        key=lambda item: item.name,
    ):
        args = ["s6-svstat", str(service)]
        if passwordless_sudo():
            args = ["sudo", "-n", *args]
        result = run(args, timeout=3)
        raw = (result.stdout or result.stderr).strip()
        status = "running" if raw.startswith("up ") else "stopped"
        if result.returncode != 0:
            status = "unknown"
        rows.append(
            {
                "id": service.name,
                "unit": service.name,
                "name": service.name,
                "kind": "s6",
                "scope": "system",
                "status": status,
                "enabled": True,
                "pid": None,
                "detail": raw,
                "log": "",
            }
        )
    return rows


def services() -> list[dict[str, Any]]:
    return systemd_user_services() + s6_services()


def ports() -> list[dict[str, Any]]:
    if command_path("lsof"):
        result = run(["lsof", "-nP", "-iTCP", "-sTCP:LISTEN"], timeout=8)
        rows: list[dict[str, Any]] = []
        for line in result.stdout.splitlines()[1:]:
            columns = line.split(None, 8)
            if len(columns) < 9:
                continue
            address = columns[8].removesuffix(" (LISTEN)")
            rows.append(
                {
                    "command": columns[0],
                    "pid": int(columns[1]) if columns[1].isdigit() else None,
                    "user": columns[2],
                    "address": address,
                }
            )
        return rows
    return []


def parse_env_file(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return values
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("\"'")
    return values


def routes() -> dict[str, Any]:
    state_root = CONFIG_ROOT / "proxyctl"
    executable = state_root / "bin/proxyctl"
    env = parse_env_file(state_root / "env")
    public_port = env.get("PROXY_PUBLIC_PORT", "")
    if not public_port:
        proxy_domain = env.get("CODE_SERVER_PROXY_DOMAIN", "")
        maybe_port = proxy_domain.rpartition(":")[2]
        if maybe_port.isdigit():
            public_port = maybe_port
    route_rows: list[dict[str, Any]] = []
    try:
        loaded = json.loads((state_root / "routes.json").read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            loaded = loaded.get("routes", [])
        if isinstance(loaded, list):
            for item in loaded:
                if not isinstance(item, dict):
                    continue
                host = str(item.get("host", ""))
                scheme = env.get("PROXY_PUBLIC_SCHEME", "https")
                port = public_port
                public_url = f"{scheme}://{host}{f':{port}' if port else ''}" if host else ""
                route_rows.append(
                    {
                        # proxyctl stores canonical hostnames rather than a
                        # separate display name. It accepts the same hostname
                        # for removal, so keep that as the stable action key.
                        "name": str(item.get("name") or host),
                        "host": host,
                        "target": str(item.get("target", "")),
                        "public_url": public_url,
                    }
                )
    except (OSError, json.JSONDecodeError):
        pass
    return {
        "installed": executable.is_file(),
        "root_domain": env.get("PROXY_ROOT_DOMAIN", ""),
        "listen": env.get("PROXY_LISTEN", ""),
        "routes": route_rows,
    }


def capability_state() -> list[dict[str, Any]]:
    extension_root = CONFIG_ROOT / ".local/share/code-server/extensions"
    control_center = bool(list(extension_root.glob("agent-workspace.control-center-*")))
    return [
        {
            "id": "source",
            "label": "Application source",
            "state": "ready" if (SOURCE_ROOT / ".git").is_dir() else "missing",
            "detail": str(SOURCE_ROOT),
        },
        {
            "id": "code-server",
            "label": "code-server",
            "state": "ready" if (CONFIG_ROOT / "opt/code-server/bin/code-server").is_file() else "missing",
            "detail": str(CONFIG_ROOT / "opt/code-server"),
        },
        {
            "id": "control-center",
            "label": "Control Center",
            "state": "ready" if control_center else "missing",
            "detail": str(extension_root),
        },
        {
            "id": "proxyctl",
            "label": "Proxy routing",
            "state": "ready" if (CONFIG_ROOT / "proxyctl/bin/proxyctl").is_file() else "optional",
            "detail": str(CONFIG_ROOT / "proxyctl"),
        },
        {
            "id": "custom-services",
            "label": "Custom services",
            "state": "ready" if (CONFIG_ROOT / "custom-services.d").is_dir() else "missing",
            "detail": str(CONFIG_ROOT / "custom-services.d"),
        },
    ]


def bootstrap_state() -> dict[str, Any]:
    target = os.environ.get("AGENT_WORKSPACE_BOOTSTRAP", "remote")
    selected_agent = os.environ.get("AGENT_WORKSPACE_AGENT", "codex")
    foundation_marker = STATE_ROOT / f"bootstrap-{target}.complete"
    agent_marker = STATE_ROOT / f"agent-{selected_agent}.complete"
    onboarding_marker = STATE_ROOT / "onboarding-v1.complete"
    return {
        "target": target,
        "foundation_ready": foundation_marker.is_file(),
        "selected_agent": selected_agent,
        "agent_ready": selected_agent == "none" or agent_marker.is_file(),
        "onboarding": {
            "version": 1,
            "complete": onboarding_marker.is_file(),
            "marker": str(onboarding_marker),
        },
    }


def doctor() -> dict[str, Any]:
    checks = []
    for name in ("bash", "curl", "git", "jq", "tar", "node", "python3"):
        path = command_path(name)
        checks.append({"id": name, "state": "ready" if path else "missing", "detail": path})
    checks.extend(
        [
            {
                "id": "config-root",
                "state": "ready" if CONFIG_ROOT.is_dir() else "missing",
                "detail": str(CONFIG_ROOT),
            },
            {
                "id": "config-writable",
                "state": "ready" if is_writable(CONFIG_ROOT) else "failed",
                "detail": str(CONFIG_ROOT),
            },
        ]
    )
    return {
        "healthy": all(check["state"] == "ready" for check in checks),
        "checks": checks,
    }


def access_info() -> dict[str, str]:
    return {
        "hostname": socket.gethostname(),
        "desktop_local": "https://localhost:3001",
        "code_server_local": "https://localhost:8443",
        "workspace": str(WORKSPACE_ROOT),
    }


def snapshot() -> dict[str, Any]:
    service_rows = services()
    agent_rows = agents()
    diagnostics = doctor()
    return {
        "schema_version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "revision": git_revision(),
        "workspace": workspace_info(),
        "bootstrap": bootstrap_state(),
        "agents": agent_rows,
        "services": service_rows,
        "ports": ports(),
        "network": routes(),
        "capabilities": capability_state(),
        "doctor": diagnostics,
        "access": access_info(),
        "summary": {
            "ready_agents": sum(1 for item in agent_rows if item["installed"]),
            "running_services": sum(1 for item in service_rows if item["status"] == "running"),
            "service_count": len(service_rows),
            "healthy": diagnostics["healthy"],
        },
    }


def payload_for(command: str) -> Any:
    providers = {
        "status": snapshot,
        "info": workspace_info,
        "agents": agents,
        "services": services,
        "ports": ports,
        "routes": routes,
        "doctor": doctor,
    }
    if command not in providers:
        raise ValueError(f"unsupported JSON command: {command}")
    return providers[command]()


def main(argv: list[str]) -> int:
    command = argv[0] if argv else "status"
    try:
        print(json.dumps(payload_for(command), ensure_ascii=False, separators=(",", ":")))
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
