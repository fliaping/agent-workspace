#!/bin/bash
# Chrome 进程监控脚本
# 防止 Chrome 进程泄漏导致容器卡死

MAX_CHROME_PROCS=50
MAX_SWAP_USAGE=90

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cleanup_chrome() {
    local zombie_count=$(ps aux | grep -c "[c]hrome.*<defunct>" || echo 0)
    if [ "$zombie_count" -gt 0 ]; then
        log "发现 $zombie_count 个 Chrome 僵尸进程"
        pkill -9 -f "chrome.*<defunct>" 2>/dev/null || true
    fi
    
    local chrome_count=$(ps aux | grep -c "[c]hrome" || echo 0)
    if [ "$chrome_count" -gt "$MAX_CHROME_PROCS" ]; then
        log "Chrome 进程数 $chrome_count，超过阈值"
        ps aux | grep "[c]hrome" | awk '{print $2}' | head -n -30 | xargs kill -9 2>/dev/null || true
    fi
}

check_resources() {
    local swap_info=$(free | grep Swap)
    local swap_total=$(echo "$swap_info" | awk '{print $2}')
    local swap_used=$(echo "$swap_info" | awk '{print $3}')
    
    if [ "$swap_total" -gt 0 ]; then
        local swap_pct=$((swap_used * 100 / swap_total))
        if [ "$swap_pct" -gt "$MAX_SWAP_USAGE" ]; then
            log "Swap 使用率 ${swap_pct}%"
            cleanup_chrome
            sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        fi
    fi
}

log "Chrome 监控脚本已启动"
while true; do
    cleanup_chrome
    check_resources
    sleep 300
done
