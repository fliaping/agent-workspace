#!/bin/bash
# ============================================================
# xfconf-query-wrapper.sh
#
# Wrapper for xfconf-query that ensures it connects to the
# correct DBUS session (the one used by the XFCE desktop).
#
# Problem: Selkies runs as abc user via s6-setuidgid but without
# DBUS_SESSION_BUS_ADDRESS. When it calls xfconf-query, a new
# xfconfd instance is spawned, separate from the desktop's.
# Changes go to the wrong xfconfd and have no effect on XFCE.
#
# Solution: Find the DBUS session from xfce4-session process
# and export it before calling the real xfconf-query.
# ============================================================

# If DBUS_SESSION_BUS_ADDRESS is already set, just pass through
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
    exec /usr/bin/xfconf-query.real "$@"
fi

# Find DBUS session from xfce4-session process (owned by abc)
XFCE_PID=$(pgrep -u abc -f xfce4-session 2>/dev/null | head -1)
if [ -n "$XFCE_PID" ]; then
    DBUS=$(strings /proc/$XFCE_PID/environ 2>/dev/null | grep "^DBUS_SESSION_BUS_ADDRESS=" | head -1)
    if [ -n "$DBUS" ]; then
        export "$DBUS"
    fi
fi

exec /usr/bin/xfconf-query.real "$@"
