#!/usr/bin/env python3
"""Control agent-desktop-bridge through workspacectl."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request


CONFIG_ROOT = pathlib.Path(os.environ.get("AGENT_WORKSPACE_CONFIG_ROOT", "/config"))
URL = os.environ.get("AGENT_DESKTOP_BRIDGE_URL", "http://127.0.0.1:8765")


def request(path: str, payload: dict[str, object] | None = None) -> dict[str, object]:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        f"{URL}{path}", data=data,
        headers={"Content-Type": "application/json", "X-Agent-Session": "workspacectl"},
        method="POST" if data is not None else "GET",
    )
    with urllib.request.urlopen(req, timeout=40) as response:
        return json.loads(response.read())


def service(action: str) -> int:
    result = subprocess.run(["systemctl", "--user", action, "agent-desktop-bridge.service"], check=False)
    return result.returncode


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Manage desktop Computer Use")
    parser.add_argument("action", nargs="?", default="status", choices=("status", "setup", "start", "stop", "restart", "emergency-stop", "resume", "screenshot"))
    parser.add_argument("--output", default=str(CONFIG_ROOT / "Downloads/agent-desktop.png"))
    args = parser.parse_args(argv)
    if args.action == "setup":
        return subprocess.run(["agent-workspace-manager", "install", "computer-use"], check=False).returncode
    if args.action in {"start", "stop", "restart"}:
        return service(args.action)
    try:
        if args.action == "status": value = request("/v1/status")
        elif args.action == "emergency-stop": value = request("/v1/action", {"action": "emergency_stop", "reason": "stopped from workspacectl"})
        elif args.action == "resume": value = request("/v1/action", {"action": "resume"})
        else:
            value = request("/v1/action", {"action": "screenshot"})
            import base64
            output = pathlib.Path(args.output); output.parent.mkdir(parents=True, exist_ok=True); output.write_bytes(base64.b64decode(str(value["data"]))); value = {"result": "ok", "output": str(output)}
        print(json.dumps(value, ensure_ascii=False, indent=2))
        return 0
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print(f"desktop Computer Use is unavailable: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main(sys.argv[1:]))
