#!/bin/bash
# hotfix-systemctl.sh — 热修复 systemctl --user wrapper
# 用法: docker exec agent-workspace bash /path/to/hotfix-systemctl.sh
#
# 修复:
# 1. 权限问题: PID/日志目录从 /tmp 移到 ~/.local (用户可写)
# 2. 新增 is-enabled / is-active 命令 (openclaw CLI 需要)
# 3. 修复带引号空格的 Environment 值 (如 "KEY=value with spaces")

set -e

cat > /usr/local/bin/systemctl << 'EOF'
#!/bin/bash
REAL_SYSTEMCTL=/usr/bin/systemctl.py
USER_UNIT_DIR="${HOME}/.config/systemd/user"
USER_WANTS_DIR="${USER_UNIT_DIR}/default.target.wants"
USER_PID_DIR="${HOME}/.local/run/user-systemd"
USER_LOG_DIR="${HOME}/.local/log/user-systemd"

has_user=false
args=()
for arg in "$@"; do
    if [ "$arg" = "--user" ]; then
        has_user=true
    else
        args+=("$arg")
    fi
done

if ! $has_user; then
    exec "$REAL_SYSTEMCTL" "$@"
fi

mkdir -p "$USER_UNIT_DIR" "$USER_WANTS_DIR" "$USER_PID_DIR" "$USER_LOG_DIR"

action=""
unit=""
has_now=false
for arg in "${args[@]}"; do
    case "$arg" in
        --now) has_now=true ;;
        -*)    ;;
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

    local log_file="$USER_LOG_DIR/${name}.log"

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

do_stop() {
    local name="$1"
    local pid_file="$USER_PID_DIR/${name}.pid"
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
}

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
    daemon-reload)
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
        echo "Supported: start, stop, restart, enable, disable, status, is-enabled, is-active, daemon-reload, list-unit-files"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/systemctl
rm -rf /tmp/user-systemd-pids /tmp/user-systemd-logs 2>/dev/null

echo "[hotfix] systemctl wrapper updated"
echo "[hotfix] Verify: systemctl --user start openclaw-gateway && sleep 1 && systemctl --user status openclaw-gateway"
