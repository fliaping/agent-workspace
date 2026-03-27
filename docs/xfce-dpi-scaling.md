# XFCE DPI Scaling in Selkies/Webtop

## Key Architecture
- Selkies sets DPI via `xfconf-query` for XFCE (not file writes)
- xfconfd stores settings in memory; XML flush to disk is unreliable
- Selkies runs via `s6-setuidgid abc` WITHOUT `DBUS_SESSION_BUS_ADDRESS`
- This causes xfconf-query to connect to a separate xfconfd instance

## Solutions Applied

### DBUS Isolation Fix
- `xfconf-query-wrapper.sh`: finds DBUS from `xfce4-session` process via `/proc/PID/environ`
- Installed as `/usr/bin/xfconf-query` (real binary moved to `.real`)

### watch-dpi.sh XFCE Mode
- **Polling** xfconf-query every 2s (NOT inotifywait on XML file)
- Must find DBUS from xfce4-session and export in `su abc` shell
- Panel sizes: `xfconf-query -c xfce4-panel -p /panels/panel-N/size -t uint` (NOT int!)
- xfce4-panel listens to xfconf changes live — no restart needed
- xfwm4 titlebar: switch theme (Default / Default-hdpi / Default-xhdpi) based on DPI
  - These themes have pre-scaled button PNGs (21x29 / 33x43 / 44x58)
  - Keep title font at base 9pt — theme handles visual scaling
  - `xfwm4 --replace` needed to apply theme change

### set-dpi.sh
- Skip all DPI config when `SELKIES_SCALING_DPI` not set (match official webtop)
- When set: pre-populate xfconf XML for panel size/icon-size

## Pitfalls
- Setting `Gdk/WindowScalingFactor` via watch-dpi causes feedback loops (panels grow then shrink)
- `xfce4-panel --quit` may connect to wrong DBUS, use `killall` if restart needed
- Font scaling + HiDPI theme = double scaling (font overflows titlebar)
