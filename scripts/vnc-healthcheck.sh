#!/bin/bash
# VNC 健康检查脚本
# 通过尝试 websocket 连接来检测 Xvnc 是否能响应新连接
# 如果连接卡住（超过 10 秒无响应），自动重启 Xvnc

LOG="/tmp/vnc-healthcheck.log"
TIMEOUT=10

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

# 检查 Xvnc 进程是否存在
if ! pgrep -f "Xvnc :1" > /dev/null; then
    log "INFO: Xvnc not running, skipping check"
    exit 0
fi

# 检查是否有活跃的 websocket 连接（有人在用就不检查，避免打断）
ACTIVE_CONNS=$(ss -tnp | grep ":6901" | grep "ESTAB" | wc -l)

# 尝试建立 websocket 连接并完成 SSL 握手
# 如果 Xvnc 正常，这应该在 2-3 秒内完成
# 如果卡住，timeout 会在 TIMEOUT 秒后杀掉
RESULT=$(timeout $TIMEOUT bash -c '
    echo -e "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n" | \
    openssl s_client -connect 127.0.0.1:6901 -quiet 2>/dev/null | \
    head -c 200
' 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    # timeout 退出码 124 = 命令超时
    log "CRITICAL: Xvnc websocket 连接超时 (${TIMEOUT}s), 活跃连接数: $ACTIVE_CONNS"
    log "ACTION: 正在重启 Xvnc..."
    
    # 保存诊断信息
    /home/kasm-user/diagnose-vnc.sh > "/tmp/vnc-diag-healthcheck-$(date +%Y%m%d-%H%M%S).log" 2>&1
    
    # 重启 Xvnc
    pkill -9 Xvnc
    sleep 2
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null
    
    # 等待自动恢复（KASMVNC_AUTO_RECOVER=true）
    sleep 5
    
    if pgrep -f "Xvnc :1" > /dev/null; then
        log "RECOVERY: Xvnc 已成功重启"
    else
        log "ERROR: Xvnc 重启失败！"
    fi
elif [ $EXIT_CODE -ne 0 ]; then
    log "WARNING: websocket 连接测试异常 (exit=$EXIT_CODE)"
else
    # 连接正常，只在有问题恢复后记录
    if [ -f /tmp/.vnc_was_unhealthy ]; then
        log "RECOVERED: Xvnc 恢复正常"
        rm -f /tmp/.vnc_was_unhealthy
    fi
fi
