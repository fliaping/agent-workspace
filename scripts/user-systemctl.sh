#!/bin/bash
# ============================================================
# user-systemctl.sh — systemctl wrapper with --user support
#
# docker-systemctl-replacement does not support --user mode.
# This wrapper intercepts --user calls and manages user-level
# services (~/.config/systemd/user/) directly:
#   enable/disable  — symlink in default.target.wants
#   start/stop      — background process with PID tracking
#   restart         — stop + start
#   status          — check PID liveness
#   is-enabled      — check if symlink exists
#   is-active       — check if process is running
#   daemon-reload   — no-op
#
# Restart=always/on-failure support:
#   A background supervisor monitors the process and restarts
#   it automatically on exit, honoring RestartSec. This enables
#   programs like OpenClaw to self-update and rely on automatic
#   restart after exiting.
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
USER_PID_DIR="${HOME}/.local/run/user-systemd"
USER_LOG_DIR="${HOME}/.local/log/user-systemd"

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
    grep '^Environment=' "$1" 2>/dev/null | sed 's/^Environment=//'
}

get_description() {
    grep '^Description=' "$1" 2>/dev/null | head -1 | sed 's/^Description=//'
}

is_running() {
    local pid_file="$USER_PID_DIR/${1}.pid"
    [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

parse_restart_policy() {
    grep '^Restart=' "$1" 2>/dev/null | head -1 | sed 's/^Restart=//'
}

parse_restart_sec() {
    local val
    val=$(grep '^RestartSec=' "$1" 2>/dev/null | head -1 | sed 's/^RestartSec=//')
    echo "${val:-1}"
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

    local log_file="$USER_LOG_DIR/${name}.log"
    local restart_policy
    restart_policy=$(parse_restart_policy "$unit_file")
    local restart_sec
    restart_sec=$(parse_restart_sec "$unit_file")

    # Kill any leftover supervisor for this unit
    local supervisor_pid_file="$USER_PID_DIR/${name}.supervisor.pid"
    if [ -f "$supervisor_pid_file" ]; then
        kill "$(cat "$supervisor_pid_file")" 2>/dev/null
        rm -f "$supervisor_pid_file"
    fi

    if [ "$restart_policy" = "always" ] || [ "$restart_policy" = "on-failure" ]; then
        # Start a supervisor that monitors and restarts the process
        _start_supervised "$name" "$unit_file" "$exec_cmd" "$log_file" "$restart_sec" "$restart_policy" &
        disown
        # Wait for supervisor to write PID file (up to 3s)
        local waited=0
        while [ ! -f "$USER_PID_DIR/${name}.pid" ] && [ $waited -lt 30 ]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        if [ -f "$USER_PID_DIR/${name}.pid" ]; then
            echo "Started ${name}.service (PID $(cat "$USER_PID_DIR/${name}.pid"))"
        else
            echo "Started ${name}.service (supervisor launched)"
        fi
    else
        # Simple start without supervision
        _start_process "$name" "$unit_file" "$exec_cmd" "$log_file"
    fi
}

_start_process() {
    local name="$1" unit_file="$2" exec_cmd="$3" log_file="$4"
    (
        while IFS= read -r line; do
            line="${line#Environment=}"
            case "$line" in \"*\") line="${line:1:${#line}-2}" ;; esac
            export "$line"
        done < <(grep '^Environment=' "$unit_file" 2>/dev/null)
        exec $exec_cmd
    ) >> "$log_file" 2>&1 &
    local pid=$!
    echo "$pid" > "$USER_PID_DIR/${name}.pid"
    echo "Started ${name}.service (PID $pid)"
}

_start_supervised() {
    local name="$1" unit_file="$2" exec_cmd="$3" log_file="$4"
    local restart_sec="$5" restart_policy="$6"
    local pid_file="$USER_PID_DIR/${name}.pid"
    local supervisor_pid_file="$USER_PID_DIR/${name}.supervisor.pid"
    local stop_file="$USER_PID_DIR/${name}.stop"

    # Record supervisor PID
    echo $$ > "$supervisor_pid_file"
    # Remove any leftover stop signal
    rm -f "$stop_file"

    while true; do
        # Launch the actual process
        (
            while IFS= read -r line; do
                line="${line#Environment=}"
                case "$line" in \"*\") line="${line:1:${#line}-2}" ;; esac
                export "$line"
            done < <(grep '^Environment=' "$unit_file" 2>/dev/null)
            exec $exec_cmd
        ) >> "$log_file" 2>&1 &
        local child_pid=$!
        echo "$child_pid" > "$pid_file"

        # Wait for process to exit
        wait "$child_pid" 2>/dev/null
        local exit_code=$?

        # Check if stop was requested (do_stop sets this flag)
        if [ -f "$stop_file" ]; then
            rm -f "$stop_file" "$supervisor_pid_file"
            exit 0
        fi

        # on-failure: only restart on non-zero exit
        if [ "$restart_policy" = "on-failure" ] && [ "$exit_code" -eq 0 ]; then
            echo "[supervisor] ${name}.service exited cleanly (code 0), not restarting" >> "$log_file"
            rm -f "$pid_file" "$supervisor_pid_file"
            exit 0
        fi

        echo "[supervisor] ${name}.service exited (code $exit_code), restarting in ${restart_sec}s..." >> "$log_file"
        sleep "$restart_sec"

        # Re-check stop flag after sleep
        if [ -f "$stop_file" ]; then
            rm -f "$stop_file" "$supervisor_pid_file"
            exit 0
        fi

        # Re-read unit file in case it was updated (e.g., after openclaw update)
        exec_cmd=$(parse_exec_start "$unit_file")
        if [ -z "$exec_cmd" ]; then
            echo "[supervisor] ${name}.service: ExecStart missing after re-read, stopping" >> "$log_file"
            rm -f "$pid_file" "$supervisor_pid_file"
            exit 1
        fi
    done
}

do_stop() {
    local name="$1"
    local pid_file="$USER_PID_DIR/${name}.pid"
    local supervisor_pid_file="$USER_PID_DIR/${name}.supervisor.pid"
    local stop_file="$USER_PID_DIR/${name}.stop"

    # Signal supervisor to stop (before killing the process)
    if [ -f "$supervisor_pid_file" ]; then
        touch "$stop_file"
    fi

    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            for _ in 1 2 3 4 5; do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.5
            done
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
            echo "Stopped ${name}.service (PID $pid)"
        else
            echo "${name}.service was not running"
        fi
        rm -f "$pid_file"
    else
        echo "${name}.service is not running"
    fi

    # Kill supervisor after process is stopped
    if [ -f "$supervisor_pid_file" ]; then
        kill "$(cat "$supervisor_pid_file")" 2>/dev/null
        rm -f "$supervisor_pid_file" "$stop_file"
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
        if $has_now; then do_start "$unit_base"; fi
        ;;

    disable)
        [ -z "$unit_base" ] && echo "Usage: systemctl --user disable <unit>" && exit 1
        rm -f "$USER_WANTS_DIR/${unit_base}.service"
        echo "Removed $USER_WANTS_DIR/${unit_base}.service"
        ;;

    status)
        if [ -z "$unit_base" ]; then
            # systemctl --user status (no unit) — return OK for compatibility
            echo "● user-systemd - active"
            exit 0
        fi
        unit_file=$(find_unit_file "$unit_base")
        desc=$(get_description "$unit_file" 2>/dev/null || echo "$unit_base")
        if is_running "$unit_base"; then
            echo "● ${unit_base}.service - $desc"
            echo "     Active: active (running)"
            echo "     PID: $(cat "$USER_PID_DIR/${unit_base}.pid")"
        else
            echo "● ${unit_base}.service - $desc"
            echo "     Active: inactive (dead)"
        fi
        ;;

    is-enabled)
        [ -z "$unit_base" ] && exit 1
        if [ -L "$USER_WANTS_DIR/${unit_base}.service" ]; then
            echo "enabled"
        else
            echo "disabled"
            exit 1
        fi
        ;;

    is-active)
        [ -z "$unit_base" ] && exit 1
        if is_running "$unit_base"; then
            echo "active"
        else
            echo "inactive"
            exit 1
        fi
        ;;

    show)
        [ -z "$unit_base" ] && exit 1
        # Parse --property flag (handles both --property=X and --property X)
        props=""
        i=0
        while [ $i -lt ${#args[@]} ]; do
            case "${args[$i]}" in
                --property=*) props="${args[$i]#--property=}" ;;
                --property)   i=$((i+1)); props="${args[$i]}" ;;
            esac
            i=$((i+1))
        done
        pid_val=0
        active_state="inactive"
        sub_state="dead"
        if is_running "$unit_base"; then
            pid_val=$(cat "$USER_PID_DIR/${unit_base}.pid")
            active_state="active"
            sub_state="running"
        fi
        if [ -n "$props" ]; then
            IFS=',' read -ra prop_list <<< "$props"
            for p in "${prop_list[@]}"; do
                case "$p" in
                    ActiveState)    echo "ActiveState=$active_state" ;;
                    SubState)       echo "SubState=$sub_state" ;;
                    MainPID)        echo "MainPID=$pid_val" ;;
                    ExecMainStatus) echo "ExecMainStatus=0" ;;
                    ExecMainCode)   echo "ExecMainCode=0" ;;
                    *)              echo "$p=" ;;
                esac
            done
        else
            echo "ActiveState=$active_state"
            echo "SubState=$sub_state"
            echo "MainPID=$pid_val"
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
        echo "Supported: start, stop, restart, enable, disable, status, show, is-enabled, is-active, daemon-reload, list-unit-files"
        exit 1
        ;;
esac
