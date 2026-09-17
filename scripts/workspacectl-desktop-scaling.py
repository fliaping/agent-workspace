#!/usr/bin/env python3
"""Inspect and repair extra text scaling in the user's KDE Wayland session."""

from __future__ import annotations

import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

SCHEMA = "org.gnome.desktop.interface"
KEY = "text-scaling-factor"
ROOT = Path(os.environ.get("AGENT_WORKSPACE_CONFIG_ROOT", "/config"))
STATE = ROOT / ".local/share/agent-workspace/desktop-scaling"


def desktop_env(proc_root=Path("/proc")):
    # The nested compositor's parent display is not the application's display.
    # Read only our own Plasma session, including its actual session bus.
    keys = {"DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "XDG_SESSION_TYPE",
            "DBUS_SESSION_BUS_ADDRESS", "HOME", "XDG_CONFIG_HOME", "DCONF_PROFILE"}
    for process in sorted(proc_root.iterdir()):
        if not process.name.isdigit():
            continue
        try:
            if process.stat().st_uid != os.getuid() or (process / "comm").read_text().strip() != "plasmashell":
                continue
            values = dict(item.split("=", 1) for item in
                          (process / "environ").read_text().split(chr(0)) if "=" in item)
            if values.get("XDG_SESSION_TYPE") != "wayland" or not values.get("WAYLAND_DISPLAY"):
                continue
            if not values.get("DBUS_SESSION_BUS_ADDRESS"):
                continue
            env = dict(os.environ)
            # Do not inherit an agent terminal's unrelated dconf or XDG settings.
            for key in keys | {"GSETTINGS_BACKEND"}:
                env.pop(key, None)
            env.update({key: value for key, value in values.items() if key in keys})
            return env
        except (OSError, ValueError):
            continue
    raise RuntimeError("No current-user KDE Wayland session found; start the desktop first.")


def run(args, env):
    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Command failed: " + args[0])
    return result.stdout.strip()


def factor(value):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise ValueError("Text scale must be a finite positive number.")
    return result


def read_scale(env):
    return factor(run(["gsettings", "get", SCHEMA, KEY], env))


def status(env):
    scale = read_scale(env)
    info = run(["qdbus6", "org.kde.KWin", "/KWin", "supportInformation"], env)
    config = Path(env.get("XDG_CONFIG_HOME") or str(Path(env["HOME"]) / ".config"))
    return {"state": "aligned-text-scale" if scale == 1.0 else "extra-text-scale",
            "wayland_display": env["WAYLAND_DISPLAY"],
            "compositor_scales": [float(v) for v in re.findall(r"^Scale: ([0-9.]+)\s*$", info, re.M)],
            "text_scale": scale, "settings_file": str(config / "dconf/user"),
            "backup_available": (STATE / "original.json").is_file(),
            "note": "This checks desktop settings; verify application scaling across a live Selkies scale change."}


def change(action, env):
    if run(["gsettings", "writable", SCHEMA, KEY], env) != "true":
        raise RuntimeError("The desktop text scale is not writable.")
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        backup = STATE / "original.json"
        before = read_scale(env)
        if action == "restore":
            if not backup.exists():
                raise RuntimeError("No managed scaling backup is available.")
            target = factor(json.loads(backup.read_text())["text_scale"])
        else:
            target = 1.0
            if before != target and not backup.exists():
                # Persist the original before changing the desktop. Keep it on repeat repair.
                temporary = STATE / "original.json.tmp"
                temporary.write_text(json.dumps({"text_scale": before}, indent=2) + "\n")
                temporary.replace(backup)
        if before != target:
            run(["gsettings", "set", SCHEMA, KEY, str(target)], env)
        if read_scale(env) != target:
            raise RuntimeError("Desktop text scale did not retain the requested value.")
        if action == "restore":
            backup.unlink()
        return {"action": action, "previous_text_scale": before, "text_scale": target,
                "changed": before != target, "backup_available": backup.is_file()}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", default="status", choices=("status", "repair", "restore"))
    args = parser.parse_args(argv)
    try:
        env = desktop_env()
        value = status(env) if args.action == "status" else change(args.action, env)
        print(json.dumps(value, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Desktop scaling: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
