#!/usr/bin/env python3
"""Stable JSON inspection backend for Agent Workspace Control Center."""

from __future__ import annotations

import ast
import concurrent.futures
import datetime as dt
import functools
import json
import os
import pathlib
import pwd
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # Python 3.10 foundation images
    tomllib = None  # type: ignore[assignment]


CONFIG_ROOT = pathlib.Path(os.environ.get("AGENT_WORKSPACE_CONFIG_ROOT", "/config"))
WORKSPACE_ROOT = pathlib.Path(
    os.environ.get("AGENT_WORKSPACE_ROOT", str(CONFIG_ROOT / "Workspace"))
)
STATE_ROOT = CONFIG_ROOT / ".local/state/agent-workspace"
VERSION_CACHE_FILE = STATE_ROOT / "command-versions-v1.json"
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
    {
        "id": "deepseek-harness",
        "label": "DeepSeek Harness",
        "binary": "deepseek-harness",
        "install_name": "deepseek-harness",
        "launch": "deepseek-harness web --no-open --port 3080",
        "accent": "green",
        "surface": "web",
        "web_path": "/proxy/3080/",
        "service": "deepseek-harness",
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


def cached_command_versions(paths: list[str]) -> list[str]:
    """Cache slow CLI --version probes while invalidating changed executables."""
    try:
        loaded = json.loads(VERSION_CACHE_FILE.read_text(encoding="utf-8"))
        entries = loaded.get("entries", {}) if isinstance(loaded, dict) else {}
    except (OSError, json.JSONDecodeError):
        entries = {}
    if not isinstance(entries, dict):
        entries = {}

    now = time.time()
    try:
        ttl = max(30, int(os.environ.get("AGENT_WORKSPACE_VERSION_CACHE_TTL", "3600")))
    except ValueError:
        ttl = 3600
    versions = [""] * len(paths)
    missing: list[tuple[int, str, str]] = []
    current_entries: dict[str, dict[str, Any]] = {}

    for index, path in enumerate(paths):
        if not path:
            continue
        try:
            executable = pathlib.Path(path).resolve()
            stat = executable.stat()
            fingerprint = f"{executable}:{stat.st_mtime_ns}:{stat.st_size}"
        except OSError:
            fingerprint = path
        cached = entries.get(path, {})
        checked_at = cached.get("checked_at", 0) if isinstance(cached, dict) else 0
        try:
            cache_age = now - float(checked_at or 0)
        except (TypeError, ValueError):
            cache_age = float("inf")
        if (
            isinstance(cached, dict)
            and cached.get("fingerprint") == fingerprint
            and isinstance(cached.get("version"), str)
            and cache_age <= ttl
        ):
            versions[index] = cached["version"]
            current_entries[path] = cached
        else:
            missing.append((index, path, fingerprint))

    if missing:
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(4, len(missing))
        ) as executor:
            probed = list(executor.map(command_version, (item[1] for item in missing)))
        for (index, path, fingerprint), version in zip(missing, probed):
            versions[index] = version
            current_entries[path] = {
                "fingerprint": fingerprint,
                "version": version,
                "checked_at": now,
            }

        try:
            VERSION_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
            temporary = VERSION_CACHE_FILE.with_name(
                f".{VERSION_CACHE_FILE.name}.{os.getpid()}.tmp"
            )
            temporary.write_text(
                json.dumps({"entries": current_entries}, ensure_ascii=False),
                encoding="utf-8",
            )
            temporary.chmod(0o600)
            temporary.replace(VERSION_CACHE_FILE)
        except OSError:
            pass

    return versions


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
    discovered = [
        (definition, command_path(str(definition["binary"])))
        for definition in AGENT_DEFINITIONS
    ]
    versions = cached_command_versions([path for _, path in discovered])

    rows: list[dict[str, Any]] = []
    for (definition, path), version in zip(discovered, versions):
        row = dict(definition)
        row.update(
            {
                "state": "ready" if path else "missing",
                "installed": bool(path),
                "path": path,
                "version": version,
                "selected": selected == definition["id"],
            }
        )
        rows.append(row)
    return rows


def skill_metadata(skill_file: pathlib.Path) -> tuple[str, str]:
    name = skill_file.parent.name
    description = ""
    try:
        text = skill_file.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return name, description
    if not text.startswith("---"):
        return name, description
    for line in text.splitlines()[1:]:
        if line.strip() == "---":
            break
        key, separator, value = line.partition(":")
        if not separator:
            continue
        clean = value.strip().strip("\"'")
        if key.strip() == "name" and clean:
            name = clean
        elif key.strip() == "description" and clean not in {">", "|"}:
            description = clean
    return name, description


def global_skills() -> dict[str, Any]:
    locations = (
        ("shared", CONFIG_ROOT / ".agents/skills", ""),
        ("agent", CONFIG_ROOT / ".codex/skills", "codex"),
        ("agent", CONFIG_ROOT / ".claude/skills", "claude-code"),
        ("agent", CONFIG_ROOT / ".hermes/skills", "hermes"),
        ("agent", CONFIG_ROOT / ".dsh/skills", "deepseek-harness"),
    )
    rows: dict[str, dict[str, Any]] = {}
    for scope, root, agent in locations:
        if not root.is_dir():
            continue
        try:
            candidates = sorted(root.iterdir(), key=lambda item: item.name.lower())
        except OSError:
            continue
        for candidate in candidates:
            if candidate.name.startswith("."):
                continue
            skill_file = candidate / "SKILL.md"
            if not skill_file.is_file():
                continue
            name, description = skill_metadata(skill_file)
            if not re.fullmatch(r"[A-Za-z0-9_.@-]+", name):
                name = candidate.name
            row = rows.setdefault(
                name,
                {
                    "id": name,
                    "name": name,
                    "description": description,
                    "path": str(candidate),
                    "scope": scope,
                    "agents": [],
                    "shared": scope == "shared",
                },
            )
            if scope == "shared":
                row.update({"path": str(candidate), "scope": "shared", "shared": True})
                # Codex natively scans $HOME/.agents/skills.
                if "codex" not in row["agents"]:
                    row["agents"].append("codex")
                # DeepSeek Harness natively scans the same shared root.
                if "deepseek-harness" not in row["agents"]:
                    row["agents"].append("deepseek-harness")
            if agent and agent not in row["agents"]:
                row["agents"].append(agent)
            if not row["description"] and description:
                row["description"] = description

    agent_order = {"codex": 0, "claude-code": 1, "hermes": 2, "deepseek-harness": 3}
    result = sorted(rows.values(), key=lambda item: item["name"].lower())
    for row in result:
        row["agents"].sort(key=lambda item: agent_order[item])
    shared_count = sum(1 for row in result if row["shared"])
    return {
        "manager": "npx skills",
        "root": str(CONFIG_ROOT / ".agents/skills"),
        "items": result,
        "count": len(result),
        "shared_count": shared_count,
    }


def safe_mcp_url(value: str) -> str:
    try:
        parsed = urllib.parse.urlsplit(value)
        port = f":{parsed.port}" if parsed.port else ""
    except ValueError:
        return "Remote endpoint"
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return "Remote endpoint"
    path = parsed.path.rstrip("/")
    return f"{parsed.scheme}://{parsed.hostname}{port}{path}"


def mcp_config_summary(config: Any) -> dict[str, Any]:
    if not isinstance(config, dict):
        return {"transport": "unknown", "detail": "Configured", "enabled": True, "manager": "native"}
    url = str(config.get("url", ""))
    if url:
        return {
            "transport": str(config.get("transport") or config.get("type") or "http"),
            "detail": safe_mcp_url(url),
            "enabled": config.get("enabled", True) is not False,
            "manager": "native",
        }
    command = str(config.get("command", ""))
    args = config.get("args", [])
    count = len(args) if isinstance(args, list) else 0
    executable = pathlib.Path(command).name if command else "STDIO command"
    manager = (
        "mcpm"
        if executable == "mcpm" and isinstance(args, list) and args[:1] == ["run"]
        else "native"
    )
    return {
        "transport": "stdio",
        "detail": f"{executable} ({count} argument{'s' if count != 1 else ''})",
        "enabled": config.get("enabled", True) is not False,
        "manager": manager,
    }


def load_codex_mcp() -> dict[str, Any]:
    path = CONFIG_ROOT / ".codex/config.toml"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    if tomllib is not None:
        try:
            loaded = tomllib.loads(text)
            servers = loaded.get("mcp_servers", {})
            return servers if isinstance(servers, dict) else {}
        except tomllib.TOMLDecodeError:
            return {}

    servers: dict[str, Any] = {}
    current: dict[str, Any] | None = None
    for line in text.splitlines():
        section = re.match(r"^\[mcp_servers\.([A-Za-z0-9_.@-]+)]\s*$", line.strip())
        if section:
            current = servers.setdefault(section.group(1), {})
            continue
        if line.startswith("["):
            current = None
            continue
        if current is None or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key not in {"command", "url", "args", "enabled"}:
            continue
        try:
            current[key] = ast.literal_eval(value) if value not in {"true", "false"} else value == "true"
        except (SyntaxError, ValueError):
            pass
    return servers


def load_claude_mcp() -> dict[str, Any]:
    path = CONFIG_ROOT / ".claude.json"
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    servers = loaded.get("mcpServers", {}) if isinstance(loaded, dict) else {}
    return servers if isinstance(servers, dict) else {}


def load_hermes_mcp() -> dict[str, Any]:
    path = CONFIG_ROOT / ".hermes/config.yaml"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    try:
        import yaml  # type: ignore[import-not-found]

        loaded = yaml.safe_load(text) or {}
        servers = loaded.get("mcp_servers", {}) if isinstance(loaded, dict) else {}
        return servers if isinstance(servers, dict) else {}
    except Exception:  # noqa: BLE001 - resilient optional YAML inspection
        # Minimal name-only fallback for foundation images without PyYAML.
        servers: dict[str, Any] = {}
        in_section = False
        for line in text.splitlines():
            if line == "mcp_servers:":
                in_section = True
                continue
            if in_section and line and not line.startswith(" "):
                break
            match = re.match(r"^  ([A-Za-z0-9_.@-]+):\s*$", line) if in_section else None
            if match:
                servers[match.group(1)] = {}
        return servers


def load_deepseek_mcp() -> dict[str, Any]:
    path = CONFIG_ROOT / ".local/share/agent-workspace/deepseek-mcp.json"
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    servers = loaded.get("servers", {}) if isinstance(loaded, dict) else {}
    return servers if isinstance(servers, dict) else {}


def global_mcp() -> dict[str, Any]:
    definitions = (
        ("codex", "Codex", "codex", load_codex_mcp()),
        ("claude-code", "Claude Code", "claude", load_claude_mcp()),
        ("hermes", "Hermes Agent", "hermes", load_hermes_mcp()),
        (
            "deepseek-harness",
            "DeepSeek Harness",
            "deepseek-harness",
            load_deepseek_mcp(),
        ),
    )
    rows: dict[str, dict[str, Any]] = {}
    support = []
    for agent_id, label, binary, configs in definitions:
        support.append(
            {
                "id": agent_id,
                "label": label,
                "installed": bool(command_path(binary)),
                "configured": len(configs),
            }
        )
        for name, config in configs.items():
            if not re.fullmatch(r"[A-Za-z0-9_.@-]+", str(name)):
                continue
            summary = mcp_config_summary(config)
            row = rows.setdefault(
                str(name),
                {"id": str(name), "name": str(name), "agents": [], "global": False},
            )
            row["agents"].append({"id": agent_id, "label": label, **summary})
    result = sorted(rows.values(), key=lambda item: item["name"].lower())
    for row in result:
        row["global"] = len(row["agents"]) > 1
        row["managed"] = any(item["manager"] == "mcpm" for item in row["agents"])
        transports = {item["transport"] for item in row["agents"]}
        details = {item["detail"] for item in row["agents"]}
        row["transport"] = next(iter(transports)) if len(transports) == 1 else "mixed"
        row["detail"] = next(iter(details)) if len(details) == 1 else "Per-Agent configuration"
        row["enabled"] = any(item["enabled"] for item in row["agents"])
    return {
        "manager": {
            "id": "mcpm",
            "label": "MCPM",
            "installed": bool(command_path("mcpm")),
            "path": command_path("mcpm"),
        },
        "items": result,
        "count": len(result),
        "global_count": sum(1 for row in result if row["global"]),
        "agents": support,
    }


def user_service_process(name: str) -> tuple[bool, int]:
    """Read the state maintained by Agent Workspace's systemctl --user shim."""
    pid_file = CONFIG_ROOT / ".local/run/user-systemd" / f"{name}.pid"
    try:
        pid = int(pid_file.read_text(encoding="utf-8").strip())
        os.kill(pid, 0)
    except (OSError, ValueError):
        return False, 0
    return True, pid


def systemd_user_services() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    wants = USER_UNIT_ROOT / "default.target.wants"
    if not USER_UNIT_ROOT.is_dir():
        return rows
    for unit in sorted(USER_UNIT_ROOT.glob("*.service")):
        name = unit.stem
        running, pid = user_service_process(name)
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
                "status": "running" if running else "inactive",
                "enabled": (wants / unit.name).is_symlink(),
                "pid": pid or None,
                "log": str(LOG_ROOT / f"{name}.log"),
            }
        )
    return rows


def s6_services() -> list[dict[str, Any]]:
    service_root = pathlib.Path("/run/service")
    if not service_root.is_dir():
        return []
    service_paths = sorted(
        (item for item in service_root.iterdir() if item.is_dir() and not item.name.startswith(".")),
        key=lambda item: item.name,
    )
    use_sudo = passwordless_sudo()

    def inspect(service: pathlib.Path) -> dict[str, Any]:
        args = ["s6-svstat", str(service)]
        if use_sudo:
            args = ["sudo", "-n", *args]
        result = run(args, timeout=3)
        raw = (result.stdout or result.stderr).strip()
        status = "running" if raw.startswith("up ") else "stopped"
        if result.returncode != 0:
            status = "unknown"
        return {
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

    if not service_paths:
        return []
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(8, len(service_paths))
    ) as executor:
        return list(executor.map(inspect, service_paths))


def services() -> list[dict[str, Any]]:
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        systemd_future = executor.submit(systemd_user_services)
        s6_future = executor.submit(s6_services)
        return systemd_future.result() + s6_future.result()


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
    caddy_present = (state_root / "bin/caddy").is_file()
    env_present = (state_root / "env").is_file()
    installed = caddy_present and env_present
    incomplete = caddy_present != env_present
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
        "installed": installed,
        "mode": "custom-domain" if installed else "incomplete" if incomplete else "local",
        "root_domain": env.get("PROXY_ROOT_DOMAIN", ""),
        "code_server_domain": env.get("CODE_SERVER_PROXY_DOMAIN", ""),
        "listen": env.get("PROXY_LISTEN", ""),
        "routes": route_rows,
    }


def desktop_capability(service_rows: list[dict[str, Any]]) -> dict[str, Any]:
    extension_root = CONFIG_ROOT / ".local/share/code-server/extensions"
    integration = bool(list(extension_root.glob("agent-workspace.selkies-desktop-*")))
    service = next((item for item in service_rows if item["id"] == "svc-selkies"), None)
    runtime = pathlib.Path("/run/service/svc-selkies").exists()
    running = bool(service and service["status"] == "running")
    return {
        "installed": integration,
        "runtime_available": runtime,
        "running": running,
        "state": "ready" if integration and running else "missing" if not integration else "stopped",
        "service": "svc-selkies",
        "local_url": "https://localhost:3001",
        "code_server_path": "/proxy/3000/",
        "install_target": "desktop",
    }


def browser_control_state() -> dict[str, Any]:
    binary = command_path("chromium") or command_path("google-chrome")
    version = command_version(binary) if binary else ""
    match = re.search(r"\b(\d+)(?:\.\d+){2,3}\b", version)
    major = int(match.group(1)) if match else 0
    profile = pathlib.Path(
        os.environ.get(
            "AGENT_WORKSPACE_BROWSER_PROFILE",
            str(CONFIG_ROOT / ".config/chromium"),
        )
    )
    pids = []
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            command = (entry / "cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        if not command:
            continue
        executable = pathlib.Path(command[0].decode(errors="ignore")).name
        if executable in {"chromium", "chrome", "google-chrome", "wrapped-chromium"}:
            pids.append(int(entry.name))

    debug_port = 0
    remote_debugging = False
    try:
        lines = [
            line.strip()
            for line in (profile / "DevToolsActivePort").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        debug_port = int(lines[0])
        with socket.create_connection(("127.0.0.1", debug_port), timeout=0.25):
            remote_debugging = True
    except (OSError, ValueError, IndexError):
        pass

    loaders = {
        "codex": load_codex_mcp,
        "claude-code": load_claude_mcp,
        "hermes": load_hermes_mcp,
        "deepseek-harness": load_deepseek_mcp,
    }
    mcp_agents = [agent for agent, loader in loaders.items() if "chrome-devtools" in loader()]
    supported = major >= 144
    if not binary or not supported:
        state = "unsupported"
    elif not mcp_agents:
        state = "needs-setup"
    elif not pids:
        state = "not-running"
    elif not remote_debugging:
        state = "needs-approval"
    else:
        state = "ready"
    return {
        "installed": bool(binary),
        "supported": supported,
        "state": state,
        "binary": binary,
        "version": version,
        "major_version": major,
        "profile": str(profile),
        "running": bool(pids),
        "pids": sorted(pids),
        "remote_debugging": remote_debugging,
        "debug_port": debug_port,
        "mcp_agents": mcp_agents,
        "mcp_configured": bool(mcp_agents),
        "connection_mode": "consent-based-auto-connect",
        "exposed": False,
    }


def tailscale_state() -> dict[str, Any]:
    binary = command_path("tailscale")
    base: dict[str, Any] = {
        "installed": bool(binary),
        "state": "optional" if not binary else "needs-login",
        "backend_state": "",
        "mode": "userspace",
        "hostname": "",
        "dns_name": "",
        "ips": [],
        "url": "",
        "serve_enabled": False,
        "proxy": "127.0.0.1:1055",
    }
    if not binary:
        return base
    managed_unit = USER_UNIT_ROOT / "tailscaled-workspace.service"
    if managed_unit.is_file() and not user_service_process(managed_unit.stem)[0]:
        base["backend_state"] = "Stopped"
        return base
    result = run([binary, "status", "--json"], timeout=6)
    try:
        loaded = json.loads(result.stdout)
    except json.JSONDecodeError:
        return base
    if not isinstance(loaded, dict):
        return base
    backend = str(loaded.get("BackendState", ""))
    self_node = loaded.get("Self", {}) if isinstance(loaded.get("Self"), dict) else {}
    dns_name = str(self_node.get("DNSName", "")).rstrip(".")
    raw_ips = self_node.get("TailscaleIPs") or []
    ips = [str(item) for item in raw_ips if isinstance(item, str)] if isinstance(raw_ips, list) else []
    base.update(
        {
            "state": "connected" if backend == "Running" else "needs-login",
            "backend_state": backend,
            "hostname": str(self_node.get("HostName", "")),
            "dns_name": dns_name,
            "ips": ips,
            "url": f"https://{dns_name}" if dns_name else "",
        }
    )
    if backend == "Running":
        serve = run([binary, "serve", "status", "--json"], timeout=6)
        try:
            serve_data = json.loads(serve.stdout)
        except json.JSONDecodeError:
            serve_data = {}
        base["serve_enabled"] = bool(serve_data)
    return base


def capability_state() -> list[dict[str, Any]]:
    extension_root = CONFIG_ROOT / ".local/share/code-server/extensions"
    control_center = bool(list(extension_root.glob("agent-workspace.control-center-*")))
    routing_caddy = (CONFIG_ROOT / "proxyctl/bin/caddy").is_file()
    routing_env = (CONFIG_ROOT / "proxyctl/env").is_file()
    routing_state = (
        "ready"
        if routing_caddy and routing_env
        else "needs-attention"
        if routing_caddy != routing_env
        else "optional"
    )
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
            "label": "Custom-domain routing",
            "state": routing_state,
            "detail": "Optional Caddy routing backend",
        },
        {
            "id": "mcpm",
            "label": "Global MCP manager",
            "state": "ready" if command_path("mcpm") else "optional",
            "detail": str(CONFIG_ROOT / "opt/mcpm"),
        },
        {
            "id": "desktop",
            "label": "Selkies Desktop",
            "state": "ready"
            if bool(list(extension_root.glob("agent-workspace.selkies-desktop-*")))
            and pathlib.Path("/run/service/svc-selkies").exists()
            else "optional",
            "detail": "Image runtime + code-server integration",
        },
        {
            "id": "tailscale",
            "label": "Tailscale network",
            "state": "ready" if command_path("tailscale") else "optional",
            "detail": str(CONFIG_ROOT / "opt/tailscale"),
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


def interface_locale() -> dict[str, Any]:
    aliases = {
        "en": "en",
        "en-us": "en",
        "english": "en",
        "zh": "zh-cn",
        "zh-cn": "zh-cn",
        "zh-hans": "zh-cn",
        "chinese": "zh-cn",
    }
    current = ""
    state_file = STATE_ROOT / "locale"
    try:
        current = aliases.get(
            state_file.read_text(encoding="utf-8").splitlines()[0].strip().lower(),
            "",
        )
    except (OSError, IndexError):
        pass
    if not current:
        config_file = CONFIG_ROOT / ".config/code-server/config.yaml"
        try:
            config = config_file.read_text(encoding="utf-8")
        except OSError:
            config = ""
        match = re.search(r"(?m)^\s*locale\s*:\s*['\"]?([^\s#'\"]+)", config)
        if match:
            current = aliases.get(match.group(1).strip().lower(), "")
    current = current or "en"
    labels = {"en": "English", "zh-cn": "简体中文"}
    return {
        "current": current,
        "label": labels[current],
        "supported": [
            {"id": locale, "label": label} for locale, label in labels.items()
        ],
        "restart_required": True,
    }


def snapshot() -> dict[str, Any]:
    collectors = {
        "revision": git_revision,
        "workspace": workspace_info,
        "bootstrap": bootstrap_state,
        "agents": agents,
        "skills": global_skills,
        "mcp": global_mcp,
        "services": services,
        "browser": browser_control_state,
        "tailscale": tailscale_state,
        "ports": ports,
        "network": routes,
        "capabilities": capability_state,
        "doctor": doctor,
        "access": access_info,
        "locale": interface_locale,
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = {
            name: executor.submit(collector) for name, collector in collectors.items()
        }
        collected = {name: future.result() for name, future in futures.items()}

    service_rows = collected["services"]
    agent_rows = collected["agents"]
    diagnostics = collected["doctor"]
    skill_rows = collected["skills"]
    mcp_rows = collected["mcp"]
    return {
        "schema_version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "revision": collected["revision"],
        "workspace": collected["workspace"],
        "bootstrap": collected["bootstrap"],
        "agents": agent_rows,
        "skills": skill_rows,
        "mcp": mcp_rows,
        "services": service_rows,
        "desktop": desktop_capability(service_rows),
        "browser": collected["browser"],
        "tailscale": collected["tailscale"],
        "ports": collected["ports"],
        "network": collected["network"],
        "capabilities": collected["capabilities"],
        "doctor": diagnostics,
        "access": collected["access"],
        "locale": collected["locale"],
        "summary": {
            "ready_agents": sum(1 for item in agent_rows if item["installed"]),
            "global_skills": skill_rows["shared_count"],
            "mcp_servers": mcp_rows["count"],
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
        "skills": global_skills,
        "mcp": global_mcp,
        "locale": interface_locale,
        "browser": browser_control_state,
        "tailscale": tailscale_state,
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
        payload = payload_for(command)
        if "--text" in argv:
            if command != "agents" or not isinstance(payload, list):
                raise ValueError("text output is only available for agents")
            for item in payload:
                label = str(item.get("label", item.get("id", "Agent")))
                if item.get("installed"):
                    detail = str(item.get("path", ""))
                    if item.get("version"):
                        detail += f" ({item['version']})"
                    print(f"{label:<16} {'ready':<10} {detail}")
                else:
                    install_name = item.get("install_name", item.get("id", ""))
                    print(
                        f"{label:<16} {'missing':<10} "
                        f"install: workspacectl install agent {install_name}"
                    )
        else:
            print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
