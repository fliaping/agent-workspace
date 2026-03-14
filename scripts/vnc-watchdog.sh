#!/bin/bash
# VNC 看门狗 - 后台运行，每 2 分钟检查一次
# 启动方式: nohup ~/vnc-watchdog.sh &
# 停止方式: pkill -f vnc-watchdog

INTERVAL=120  # 秒
PIDFILE="/tmp/vnc-watchdog.pid"

# 防止重复运行
if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    echo "Watchdog already running (PID $(cat $PIDFILE))"
    exit 0
fi
echo $$ > "$PIDFILE"

trap 'rm -f $PIDFILE; exit 0' SIGINT SIGTERM

echo "[$(date)] VNC Watchdog started (PID $$, interval ${INTERVAL}s)"

while true; do
    /home/kasm-user/vnc-healthcheck.sh
    sleep $INTERVAL
done
