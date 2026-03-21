#!/bin/bash
# ============================================================
# user-systemctl.sh — systemctl wrapper with --user support
#
# docker-systemctl-replacement does not support --user mode.
# This wrapper intercepts --user calls and manages user-level
# services (~/.config/systemd/user/) directly:
#   enable/disable — symlink in default.target.wants
#   start/stop     — background process with PID tracking
#   restart        — stop + start
#   status         — check PID liveness
#   daemon-reload  — no-op
#
# System-level calls (without --user) pass through to the
# real docker-systemctl-replacement at /usr/bin/systemctl.py.
#
# Installed as /usr/local/bin/systemctl (higher PATH priority
# than /usr/bin/systemctl).
# ============================================================

REAL_SYSTEMCTL=/usr/bin/systemctl.py
USER_UNIT_DIR="${HOME}/.config/systemd/user"
USER_WANTS_DIR="${USER_UNIT_DIR}/default.target.wants"
USER_PID_DIR="/tmp/user-systemd-pids"
USER_LOG_DIR="/tmp/user-systemd-logs"

# ── Parse --user flag ─────────────────────────────────────────
has_user=false
args=()
for arg in "$@"; do
    if [ "$arg" = "--user" ]; then
        has_user=true
    else
        args+=("$arg")
    fi
done

# System-level: pass through to docker-systemctl-replacement
if ! $has_user; then
    exec "$REAL_SYSTEMCTL" "$@"
fi

# ── User-level handling ───────────────────────────────────────
mkdir -p "$USER_UNIT_DIR" "$USER_WANTS_DIR" "$USER_PID_DIR" "$USER_LOG_DIR"

# Parse action and unit from remaining args (skip flags like --now)
action=""
unit=""
has_now=false
for arg in "${args[@]}"; do
    case "$arg" in
        --now) has_now=true ;;
        -*)    ;;  # skip other flags
        *)
            if [ -z "$action" ]; then
                action="$arg"
            elif [ -z "$unit" ]; then
                unit="$arg"
            fi
            ;;
    esac
done

unit_base="${unit%.service}"

find_unit_file() {
    local name="$1"
    local f="$USER_UNIT_DIR/${name}.service"
    [ -f "$f" ] && echo "$f" && return
    f="$USER_UNIT_DIR/${name}"
    [ -f "$f" ] && echo "$f" && return
}

parse_exec_start() {
    grep '^ExecStart=' "$1" 2>/dev/null | head -1 | sed 's/^ExecStart=//'
}

parse_env_vars() {
    # Collect Environment= lines into export statements
    grep '^Environment=' "$1" 2>/dev/null | sed 's/^Environment=//' | while IFS= read -r line; do
        echo "$line"
    done
}

get_description() {
    grep '^Description=' "$1" 2>/dev/null | head -1 | sed 's/^Description=//'
}

is_running() {
    local pid_file="$USER_PID_DIR/${1}.pid"
    [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

do_start() {
    local name="$1"
    local unit_file
    unit_file=$(find_unit_file "$name")
    [ -z "$unit_file" ] && echo "Failed to start ${name}.service: Unit not found." && return 1

    if is_running "$name"; then
        echo "${name}.service is already running (PID $(cat "$USER_PID_DIR/${name}.pid"))"
        return 0
    fi

    local exec_cmd
    exec_cmd=$(parse_exec_start "$unit_file")
    [ -z "$exec_cmd" ] && echo "No ExecStart in $unit_file" && return 1

    # Build environment
    local env_file="$USER_PID_DIR/${name}.env"
    : > "$env_file"
    parse_env_vars "$unit_file" >> "$env_file"

    local log_file="$USER_LOG_DIR/${name}.log"

    # Start process with environment
    (
        set -a
        [ -s "$env_file" ] && . "$env_file"
        set +a
        exec $exec_cmd
    ) >> "$log_file" 2>&1 &
    local pid=$!
    echo "$pid" > "$USER_PID_DIR/${name}.pid"
    rm -f "$env_file"
    echo "Started ${name}.service (PID $pid)"
}

do_stop() {
    local name="$1"
    local pid_file="$USER_PID_DIR/${name}.pid"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            # Wait briefly for graceful shutdown
            for _ in 1 2 3 4 5; do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.5
            done
            # Force kill if still alive
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
            echo "Stopped ${name}.service (PID $pid)"
        else
            echo "${name}.service was not running"
        fi
        rm -f "$pid_file"
    else
        echo "${name}.service is not running"
    fi
}

# ── Dispatch action ───────────────────────────────────────────
case "$action" in
    start)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user start <unit>" && exit 1
        do_start "$unit_base"
        ;;

    stop)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user stop <unit>" && exit 1
        do_stop "$unit_base"
        ;;

    restart)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user restart <unit>" && exit 1
        do_stop "$unit_base"
        sleep 1
        do_start "$unit_base"
        ;;

    enable)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user enable <unit>" && exit 1
        unit_file=$(find_unit_file "$unit_base")
        [ -z "$unit_file" ] && echo "Unit ${unit_base}.service not found." && exit 1
        ln -sf "$unit_file" "$USER_WANTS_DIR/$(basename "$unit_file")"
        echo "Created symlink $USER_WANTS_DIR/$(basename "$unit_file")"
        $has_now && do_start "$unit_base"
        ;;

    disable)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user disable <unit>" && exit 1
        rm -f "$USER_WANTS_DIR/${unit_base}.service"
        echo "Removed $USER_WANTS_DIR/${unit_base}.service"
        ;;

    status)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user status <unit>" && exit 1
        unit_file=$(find_unit_file "$unit_base")
        desc=$(get_description "$unit_file" 2>/dev/null || echo "$unit_base")
        if is_running "$unit_base"; then
            local_pid=$(cat "$USER_PID_DIR/${unit_base}.pid")
            echo "● ${unit_base}.service - $desc"
            echo "     Active: active (running)"
            echo "     PID: $local_pid"
        else
            echo "● ${unit_base}.service - $desc"
            echo "     Active: inactive (dead)"
        fi
        ;;

    daemon-reload)
        # No-op for user mode
        ;;

    list-unit-files)
        echo "UNIT FILE                          STATE"
        for f in "$USER_UNIT_DIR"/*.service; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            if [ -L "$USER_WANTS_DIR/$name" ]; then
                echo "$name    enabled"
            else
                echo "$name    disabled"
            fi
        done
        ;;

    *)
        echo "Unsupported user-mode action: $action"
        echo "Supported: start, stop, restart, enable, disable, status, daemon-reload, list-unit-files"
        exit 1
        ;;
esac
