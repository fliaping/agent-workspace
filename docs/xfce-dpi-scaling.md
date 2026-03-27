# XFCE DPI Scaling in Selkies/Webtop

## Overview

When users adjust the "界面缩放比例" (UI scaling ratio) in the Selkies sidebar, all desktop elements should scale proportionally — panels, dock, window titlebars, menus, and content. This document describes the architecture and solutions implemented to achieve this.

## Architecture

### How Selkies Sets DPI

- Selkies sets DPI via `xfconf-query -c xsettings -p /Xft/DPI` for XFCE
- xfconfd stores settings **in memory**; XML flush to disk is unreliable and delayed
- Selkies runs via `s6-setuidgid abc` **without** `DBUS_SESSION_BUS_ADDRESS`

### The DBUS Isolation Problem

Selkies' `xfconf-query` calls connect to a **separate xfconfd instance** (not the desktop's), because it lacks the correct DBUS session address. Changes go to the wrong xfconfd and have no effect on the running XFCE desktop.

**Solution**: `xfconf-query-wrapper.sh` — installed as `/usr/bin/xfconf-query` (real binary moved to `.real`). The wrapper finds DBUS from the `xfce4-session` process via `/proc/PID/environ` and exports it before calling the real binary.

## Scripts

### set-dpi.sh (Pre-DE Init)

- Runs via `/custom-cont-init.d/` **before** DE starts
- Skips all DPI config when `SELKIES_SCALING_DPI` is not set (matches official webtop behavior)
- When set: pre-populates xfconf XML for panel size/icon-size with correct `uint` type

### watch-dpi.sh (Runtime DPI Watcher)

Runs as an s6 service, monitors DPI changes and dynamically adjusts desktop elements.

**XFCE mode** uses a hybrid approach:
- **Polling** `xfconf-query` every 2 seconds (NOT inotifywait on XML file, since xfconfd doesn't flush reliably)
- Finds DBUS session from `xfce4-session` and exports it in `su abc` shell

**What it adjusts on DPI change:**

| Element | Method | Details |
|---------|--------|---------|
| GTK3 widget scaling | `Gdk/WindowScalingFactor` | Integer scale: 1 (DPI≤168) or 2 (DPI≥168) |
| GTK3 font DPI | `Gdk/UnscaledDPI` | `(DPI / WSF) * 1024` — prevents double font scaling |
| Panel height | `xfce4-panel` xfconf `uint` | `base * ratio / WSF` — compensates for GTK doubling |
| Panel icon size | `xfce4-panel` xfconf `uint` | Same formula as panel height |
| Dock size | `xfce4-panel` panel-2 | Same formula |
| Window titlebar | xfwm4 theme switch | Default / Default-hdpi / Default-xhdpi |
| Title font | xfwm4 `title_font` | Fixed `Sans Bold 9` — HiDPI theme handles visual scaling |

**Panel size formula** (linear scaling, no jumps):

```
panel_size = base * (dpi / 96) / WindowScalingFactor
physical_size = panel_size * WSF = base * (dpi / 96)
```

| Scale | DPI | WSF | panel-1 size | Physical px |
|-------|-----|-----|-------------|-------------|
| 100%  | 96  | 1   | 26          | 26          |
| 125%  | 120 | 1   | 33          | 33          |
| 150%  | 144 | 1   | 39          | 39          |
| 175%  | 168 | 2   | 23          | 46          |
| 200%  | 192 | 2   | 26          | 52          |
| 300%  | 288 | 2   | 39          | 78          |

**xfwm4 theme selection:**

| DPI Range | Theme | Button Size |
|-----------|-------|-------------|
| ≤96       | Default | 21×29 px |
| 97–144    | Default-hdpi | 33×43 px |
| >144      | Default-xhdpi | 44×58 px |

## Key Technical Notes

- `xfce4-panel` listens to xfconf changes **live** — no restart needed for size changes
- `xfwm4 --replace` is needed to apply theme changes
- Panel size properties must use `uint` type (not `int`) to match XFCE schema
- `Gdk/WindowScalingFactor` is safe to set dynamically now because watch-dpi uses xfconf-query polling (not file-based inotifywait), avoiding feedback loops
- `UnscaledDPI` prevents double font scaling: GTK3 uses `UnscaledDPI` (not `Xft/DPI`) when `WindowScalingFactor > 1`

## Pitfalls (Solved)

| Problem | Cause | Solution |
|---------|-------|----------|
| xfconf-query changes have no effect | Selkies lacks DBUS → wrong xfconfd | xfconf-query-wrapper.sh |
| Panels grow then shrink | inotifywait + WindowScalingFactor feedback loop | Switch to xfconf-query polling |
| Title font overflows titlebar | Font scaled 2x + theme buttons 2x = mismatch | Keep font at base 9pt, let theme handle scaling |
| Panel too large at 200% | Panel size scaled 2x + WSF 2x = 4x | Divide panel size by WSF |
| `xfce4-panel --quit` doesn't work | Connects to wrong DBUS | Use `killall` or pass correct DBUS in shell |
| Reading xsettings.xml gives stale DPI | xfconfd doesn't flush to disk immediately | Read via `xfconf-query` instead |
