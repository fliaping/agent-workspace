#!/usr/bin/env python3
"""Connect trusted Agents to the Chromium window used in the Selkies desktop."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import socket
import subprocess
import sys
from collections.abc import Sequence


CONFIG_ROOT = pathlib.Path(os.environ.get("AGENT_WORKSPACE_CONFIG_ROOT", "/config"))
PROFILE_ROOT = pathlib.Path(
    os.environ.get("AGENT_WORKSPACE_BROWSER_PROFILE", str(CONFIG_ROOT / ".config/chromium"))
)
DEBUG_PAGE = "chrome://inspect/#remote-debugging"
MIN_AUTO_CONNECT_VERSION = 144
AGENT_BINARIES = {
    "codex": "codex",
    "claude-code": "claude",
    "hermes": "hermes",
    "deepseek-harness": "deepseek-harness",
}


def run(args: Sequence[str], timeout: float = 30) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.setdefault("HOME", str(CONFIG_ROOT))
    return subprocess.run(
        list(args),
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )


def browser_binary() -> str:
    configured = os.environ.get("AGENT_WORKSPACE_BROWSER_BIN", "").strip()
    if configured:
        return configured
    return (
        shutil.which("chromium")
        or shutil.which("google-chrome")
        or ""
    )


def browser_launcher() -> str:
    return shutil.which("wrapped-chromium") or browser_binary()


def browser_version(binary: str) -> tuple[str, int]:
    if not binary:
        return "", 0
    try:
        result = run([binary, "--version"], timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return "", 0
    version = (result.stdout or result.stderr).strip()
    match = re.search(r"\b(\d+)(?:\.\d+){2,3}\b", version)
    return version, int(match.group(1)) if match else 0


def chromium_processes() -> list[int]:
    processes = []
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
            processes.append(int(entry.name))
    return sorted(processes)


def devtools_endpoint() -> tuple[bool, int]:
    path = PROFILE_ROOT / "DevToolsActivePort"
    try:
        lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
        port = int(lines[0])
    except (OSError, ValueError, IndexError):
        return False, 0
    if port < 1 or port > 65535:
        return False, 0
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.5):
            return True, port
    except OSError:
        return False, port


def configured_agents() -> list[str]:
    markers = {
        "codex": CONFIG_ROOT / ".codex/config.toml",
        "claude-code": CONFIG_ROOT / ".claude.json",
        "hermes": CONFIG_ROOT / ".hermes/config.yaml",
        "deepseek-harness": CONFIG_ROOT / ".local/share/agent-workspace/deepseek-mcp.json",
    }
    configured = []
    for agent, path in markers.items():
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if "chrome-devtools" in content:
            configured.append(agent)
    return configured


def state() -> dict[str, object]:
    binary = browser_binary()
    version, major = browser_version(binary)
    processes = chromium_processes()
    debugging, port = devtools_endpoint()
    agents = configured_agents()
    supported = major >= MIN_AUTO_CONNECT_VERSION
    if not binary or not supported:
        status = "unsupported"
    elif not agents:
        status = "needs-setup"
    elif not processes:
        status = "not-running"
    elif not debugging:
        status = "needs-approval"
    else:
        status = "ready"
    return {
        "installed": bool(binary),
        "supported": supported,
        "state": status,
        "binary": binary,
        "version": version,
        "major_version": major,
        "profile": str(PROFILE_ROOT),
        "running": bool(processes),
        "pids": processes,
        "remote_debugging": debugging,
        "debug_port": port,
        "mcp_agents": agents,
        "mcp_configured": bool(agents),
        "connection_mode": "consent-based-auto-connect",
        "exposed": False,
    }


def print_status(as_json: bool) -> int:
    current = state()
    if as_json:
        print(json.dumps(current, ensure_ascii=False, separators=(",", ":")))
        return 0
    print("Desktop browser control")
    print(f"  browser:          {current['version'] or 'not installed'}")
    print(f"  running:          {'yes' if current['running'] else 'no'}")
    print(f"  user profile:     {current['profile']}")
    print(f"  Agent MCP:        {', '.join(current['mcp_agents']) if current['mcp_agents'] else 'not configured'}")
    print(f"  user approval:    {'active' if current['remote_debugging'] else 'required'}")
    print("  network exposure: none (local browser consent bridge)")
    if current["state"] == "ready":
        print("Ready: trusted Agents can request access to the user's open tabs.")
    elif current["state"] == "needs-approval":
        print(f"Next: open {DEBUG_PAGE}, enable Remote debugging, then approve the Agent prompt.")
    elif current["state"] == "needs-setup":
        print("Next: workspacectl browser setup")
    elif current["state"] == "not-running":
        print("Next: start Chromium in the Selkies desktop, then enable browser control.")
    else:
        print(f"Chromium {MIN_AUTO_CONNECT_VERSION}+ is required for consent-based auto-connect.")
    return 0


def open_debug_page() -> int:
    binary = browser_launcher()
    if not binary:
        print("Chromium is not installed", file=sys.stderr)
        return 1
    log_path = CONFIG_ROOT / ".local/log/agent-workspace-browser.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault("HOME", str(CONFIG_ROOT))
    if not env.get("DISPLAY"):
        env["DISPLAY"] = ":1"
    try:
        with log_path.open("ab") as output:
            subprocess.Popen(
                [binary, DEBUG_PAGE],
                stdin=subprocess.DEVNULL,
                stdout=output,
                stderr=subprocess.STDOUT,
                env=env,
                start_new_session=True,
                close_fds=True,
            )
    except OSError as exc:
        print(f"Could not open Chromium: {exc}", file=sys.stderr)
        return 1
    print(f"Opened {DEBUG_PAGE} in the desktop browser")
    return 0


def setup() -> int:
    binary = browser_binary()
    version, major = browser_version(binary)
    if not binary or major < MIN_AUTO_CONNECT_VERSION:
        print(
            f"Chromium {MIN_AUTO_CONNECT_VERSION}+ is required; found {version or 'no browser'}",
            file=sys.stderr,
        )
        return 1
    agents = [agent for agent, command in AGENT_BINARIES.items() if shutil.which(command)]
    if not agents:
        print("Install and sign in to at least one Agent before enabling browser control", file=sys.stderr)
        return 1
    helper = pathlib.Path(__file__).resolve().with_name("workspacectl-resources.py")
    if not helper.is_file():
        print(f"MCP resource helper is unavailable: {helper}", file=sys.stderr)
        return 1
    command_line = (
        "npx --yes chrome-devtools-mcp@latest --auto-connect "
        f"--user-data-dir={PROFILE_ROOT} --no-usage-statistics"
    )
    result = subprocess.run(
        [
            sys.executable,
            str(helper),
            "mcp",
            "add",
            "chrome-devtools",
            "--transport",
            "stdio",
            "--command-line",
            command_line,
            "--agents",
            ",".join(agents),
        ],
        check=False,
    )
    if result.returncode != 0:
        return result.returncode
    opened = open_debug_page()
    print("Browser control is configured without closing or copying the user's browser profile.")
    print("In Chromium, enable Remote debugging and click Allow when the Agent requests access.")
    print("Start a new Agent session after changing MCP configuration.")
    print("Security: an approved Agent can read and operate all tabs and logged-in sessions in this profile.")
    return opened


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="workspacectl browser")
    commands = root.add_subparsers(dest="command", required=True)
    status = commands.add_parser("status", help="show desktop browser control readiness")
    status.add_argument("--json", action="store_true")
    commands.add_parser("setup", help="configure global Agent MCP and open Chromium approval settings")
    commands.add_parser("approve", help="open Chromium's remote-debugging approval page")
    return root


def main(argv: list[str]) -> int:
    args = parser().parse_args(argv)
    if args.command == "status":
        return print_status(args.json)
    if args.command == "setup":
        return setup()
    return open_debug_page()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
