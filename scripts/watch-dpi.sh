#!/bin/bash
# ============================================================
# watch-dpi.sh — Dynamic DPI watcher
#
# Monitors DPI changes from Selkies and dynamically adjusts
# DE-specific settings (panel size, icon size, WM theme).
#
# Selkies writes DPI via:
#   KDE/LXQt → .xsettingsd (via _run_xrdb)
#   XFCE     → xfconf-query (persisted to xsettings.xml)
#
# Runs as an s6 service after DE starts.
# ============================================================

LAST_DPI=0

# ── Detect DE ───────────────────────────────────────────────
if command -v startplasma-x11 >/dev/null 2>&1; then
    DE="kde"
elif command -v xfce4-session >/dev/null 2>&1; then
    DE="xfce"
else
    DE="lxqt"
fi
echo "[watch-dpi] Detected DE: $DE"

# ── Watch target ────────────────────────────────────────────
# Selkies writes different files per DE
if [ "$DE" = "xfce" ]; then
    WATCH_FILE="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
else
    WATCH_FILE="${HOME}/.xsettingsd"
fi

# Wait for the file to exist
for i in $(seq 1 30); do
    [ -f "$WATCH_FILE" ] && break
    sleep 2
done
[ -f "$WATCH_FILE" ] || { echo "[watch-dpi] $WATCH_FILE not found, exiting"; exit 0; }

# ── Read DPI functions ──────────────────────────────────────
read_dpi_xsettingsd() {
    local raw
    raw=$(grep "^Xft/DPI" "${HOME}/.xsettingsd" 2>/dev/null | awk '{print $2}')
    if [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
        echo $(( raw / 1024 ))
    else
        echo 0
    fi
}

read_dpi_xfce() {
    # Always use xfconf-query for XFCE (as abc user for correct D-Bus session).
    # Reading xsettings.xml is unreliable because xfconfd doesn't flush to disk immediately,
    # causing stale reads and feedback loops.
    local val
    val=$(su abc -s /bin/bash -c "DISPLAY=:1 xfconf-query -c xsettings -p /Xft/DPI" 2>/dev/null)
    if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
        echo "$val"
    else
        echo 0
    fi
}

read_dpi() {
    if [ "$DE" = "xfce" ]; then
        read_dpi_xfce
    else
        read_dpi_xsettingsd
    fi
}

LAST_DPI=$(read_dpi)
echo "[watch-dpi] Initial DPI: $LAST_DPI, watching $WATCH_FILE"

# ── LXQt update functions ──────────────────────────────────

update_lxqt_panel() {
    local dpi=$1
    local panel_conf="${HOME}/.config/lxqt/panel.conf"
    [ -f "$panel_conf" ] || return

    local panel_size=$(awk "BEGIN { printf \"%d\", 32 * $dpi / 96 + 0.5 }")
    local icon_size=$(awk "BEGIN { printf \"%d\", 22 * $dpi / 96 + 0.5 }")

    sed -i "s|^panelSize=.*|panelSize=$panel_size|" "$panel_conf"
    sed -i "s|^iconSize=.*|iconSize=$icon_size|" "$panel_conf"

    # Restart panel to pick up changes
    if pgrep -x lxqt-panel >/dev/null 2>&1; then
        pkill -x lxqt-panel
        sleep 0.5
        su abc -s /bin/bash -c "DISPLAY=:1 lxqt-panel &" 2>/dev/null
    fi
    echo "[watch-dpi] LXQt panel: panelSize=$panel_size, iconSize=$icon_size"
}

update_openbox_theme() {
    local dpi=$1

    local ob_rc="${HOME}/.config/openbox/rc.xml"
    [ -f "$ob_rc" ] || ob_rc="/etc/xdg/openbox/rc.xml"
    local current_theme
    current_theme=$(grep -oP '<name>\K[^<]+' "$ob_rc" 2>/dev/null | head -1)
    [ -z "$current_theme" ] && return

    local base_theme="${current_theme%-HiDPI}"

    if [ "$dpi" -le 96 ]; then
        if [ "$current_theme" != "$base_theme" ] && [ -f "${HOME}/.config/openbox/rc.xml" ]; then
            sed -i "s|<name>${current_theme}</name>|<name>${base_theme}</name>|" \
                "${HOME}/.config/openbox/rc.xml"
            DISPLAY=:1 openbox --reconfigure 2>/dev/null
            echo "[watch-dpi] Openbox: restored $base_theme"
        fi
        return
    fi

    local src="/usr/share/themes/${base_theme}/openbox-3"
    [ -d "$src" ] || return
    local dst="${HOME}/.themes/${base_theme}-HiDPI/openbox-3"
    mkdir -p "$dst"
    cp "$src"/* "$dst/" 2>/dev/null

    local ratio=$(awk "BEGIN { printf \"%.0f\", $dpi / 96 }")
    if [ -f "$dst/themerc" ]; then
        local pw ph bw
        pw=$(grep -oP '^padding\.width:\s*\K\d+' "$dst/themerc" || echo 4)
        ph=$(grep -oP '^padding\.height:\s*\K\d+' "$dst/themerc" || echo 2)
        bw=$(grep -oP '^border\.width:\s*\K\d+' "$dst/themerc" || echo 1)
        sed -i "s/^padding\.width:.*/padding.width: $(( pw * ratio ))/" "$dst/themerc"
        sed -i "s/^padding\.height:.*/padding.height: $(( ph * ratio ))/" "$dst/themerc"
        sed -i "s/^border\.width:.*/border.width: $(( bw * ratio ))/" "$dst/themerc"
    fi
    chown -R abc:abc "${HOME}/.themes"

    if [ "$current_theme" != "${base_theme}-HiDPI" ]; then
        mkdir -p "${HOME}/.config/openbox"
        [ -f "${HOME}/.config/openbox/rc.xml" ] || cp /etc/xdg/openbox/rc.xml "${HOME}/.config/openbox/rc.xml"
        sed -i "s|<name>${current_theme}</name>|<name>${base_theme}-HiDPI</name>|" \
            "${HOME}/.config/openbox/rc.xml"
    fi
    DISPLAY=:1 openbox --reconfigure 2>/dev/null
    echo "[watch-dpi] Openbox: ${base_theme}-HiDPI (padding ${ratio}x)"
}

update_lxqt_session() {
    local dpi=$1
    local session_conf="${HOME}/.config/lxqt/session.conf"
    [ -f "$session_conf" ] || return
    grep -q "^font_dpi=" "$session_conf" && sed -i "s|^font_dpi=.*|font_dpi=$dpi|" "$session_conf"
    grep -q "^QT_FONT_DPI=" "$session_conf" && sed -i "s|^QT_FONT_DPI=.*|QT_FONT_DPI=$dpi|" "$session_conf"
}

update_lxqt_gtk_scaling() {
    local dpi=$1
    local xset="${HOME}/.xsettingsd"
    [ -f "$xset" ] || return

    local scale_int=$(awk "BEGIN { v=$dpi/96; printf \"%d\", (v>=1.75) ? 2 : 1 }")
    local unscaled_dpi=$(( (dpi / scale_int) * 1024 ))

    # Update or add Gdk/WindowScalingFactor in .xsettingsd
    if grep -q "^Gdk/WindowScalingFactor" "$xset"; then
        sed -i "s|^Gdk/WindowScalingFactor.*|Gdk/WindowScalingFactor $scale_int|" "$xset"
    else
        echo "Gdk/WindowScalingFactor $scale_int" >> "$xset"
    fi
    if grep -q "^Gdk/UnscaledDPI" "$xset"; then
        sed -i "s|^Gdk/UnscaledDPI.*|Gdk/UnscaledDPI $unscaled_dpi|" "$xset"
    else
        echo "Gdk/UnscaledDPI $unscaled_dpi" >> "$xset"
    fi
    chown abc:abc "$xset"

    # Signal xsettingsd to reload (SIGHUP)
    pkill -HUP xsettingsd 2>/dev/null
    echo "[watch-dpi] LXQt GTK scaling: WindowScalingFactor=$scale_int, UnscaledDPI=$unscaled_dpi"
}

# ── XFCE update functions ──────────────────────────────────

update_xfce_panel() {
    local dpi=$1
    which xfconf-query >/dev/null 2>&1 || return

    local scale_ratio=$(awk "BEGIN { printf \"%.4f\", $dpi / 96 }")
    local scale_int=$(awk "BEGIN { v=$dpi/96; printf \"%d\", (v>=1.75) ? 2 : 1 }")
    local unscaled_dpi=$(( (dpi / scale_int) * 1024 ))

    # Scale panel sizes: divide by scale_int to compensate for WSF doubling
    # Physical size = panel_size * WSF = base * (dpi/96), linear across all scales
    local panel1_size=$(awk "BEGIN { printf \"%d\", 26 * $scale_ratio / $scale_int + 0.5 }")
    local panel1_icon=$(awk "BEGIN { printf \"%d\", 16 * $scale_ratio / $scale_int + 0.5 }")
    local panel2_size=$(awk "BEGIN { printf \"%d\", 48 * $scale_ratio / $scale_int + 0.5 }")

    # Find the desktop's DBUS session (from xfce4-session process)
    local xfce_pid dbus_addr
    xfce_pid=$(pgrep -u abc -f xfce4-session 2>/dev/null | head -1)
    dbus_addr=$(strings /proc/$xfce_pid/environ 2>/dev/null | grep "^DBUS_SESSION_BUS_ADDRESS=" | head -1)

    # Set xfconf values — xfce4-panel listens to xfconf changes live, no restart needed
    su abc -s /bin/bash -c "
        export DISPLAY=:1
        export $dbus_addr
        # GTK3 integer scaling — controls widget/menu/content size
        # Must reset to 1 at 100% (DPI≤96), set to 2 at 200%+ (DPI≥168)
        xfconf-query -c xsettings -p /Gdk/WindowScalingFactor \
            -s $scale_int --create -t int 2>/dev/null
        xfconf-query -c xsettings -p /Gdk/UnscaledDPI \
            -s $unscaled_dpi --create -t int 2>/dev/null
        # Panel-1 (top bar) — must use uint type to match XFCE schema
        xfconf-query -c xfce4-panel -p /panels/panel-1/size \
            -s $panel1_size --create -t uint 2>/dev/null
        xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size \
            -s $panel1_icon --create -t uint 2>/dev/null
        # Panel-2 (bottom dock)
        xfconf-query -c xfce4-panel -p /panels/panel-2/size \
            -s $panel2_size --create -t uint 2>/dev/null
        # xfwm4 title font — keep base size, HiDPI theme handles visual scaling
        xfconf-query -c xfwm4 -p /general/title_font \
            -s 'Sans Bold 9' --create -t string 2>/dev/null
        # xfwm4 theme: switch to HiDPI variant based on DPI
        # Default (21x29 buttons), Default-hdpi (33x43), Default-xhdpi (44x58)
        if [ $dpi -gt 144 ]; then
            xfconf-query -c xfwm4 -p /general/theme -s Default-xhdpi 2>/dev/null
        elif [ $dpi -gt 96 ]; then
            xfconf-query -c xfwm4 -p /general/theme -s Default-hdpi 2>/dev/null
        else
            xfconf-query -c xfwm4 -p /general/theme -s Default 2>/dev/null
        fi
        # xfwm4 needs --replace to pick up theme change
        xfwm4 --replace >/dev/null 2>&1 &
    " 2>/dev/null

    # Determine which theme was selected for logging
    local xfwm_theme="Default"
    [ "$dpi" -gt 144 ] && xfwm_theme="Default-xhdpi"
    [ "$dpi" -gt 96 ] && [ "$dpi" -le 144 ] && xfwm_theme="Default-hdpi"
    echo "[watch-dpi] XFCE: DPI=$dpi, panel1=$panel1_size, panel2=$panel2_size, icon=$panel1_icon, xfwm4Theme=$xfwm_theme"
}

update_xfwm4_font() {
    # Handled in update_xfce_panel now
    :
}

# ── KDE update functions ───────────────────────────────────

update_kde_scaling() {
    local dpi=$1
    # KDE scaling is handled by Selkies via Xft/DPI in .xsettingsd.
    # Ensure KDE's own ScaleFactor stays at 1.0 and forceFontDPI at 0
    # to prevent double-scaling (Selkies DPI * KDE ScaleFactor).
    local kdeglobals="${HOME}/.config/kdeglobals"
    if [ -f "$kdeglobals" ] && grep -q "^ScaleFactor=" "$kdeglobals"; then
        local cur_sf=$(grep "^ScaleFactor=" "$kdeglobals" | head -1 | cut -d= -f2)
        if [ "$cur_sf" != "1.0" ] && [ "$cur_sf" != "1" ]; then
            sed -i "s|^ScaleFactor=.*|ScaleFactor=1.0|" "$kdeglobals"
            echo "[watch-dpi] KDE: reset ScaleFactor from $cur_sf to 1.0"
        fi
    fi
    local kcmfonts="${HOME}/.config/kcmfonts"
    if [ -f "$kcmfonts" ] && grep -q "^forceFontDPI=" "$kcmfonts"; then
        local cur_dpi=$(grep "^forceFontDPI=" "$kcmfonts" | head -1 | cut -d= -f2)
        if [ "$cur_dpi" != "0" ]; then
            sed -i "s|^forceFontDPI=.*|forceFontDPI=0|" "$kcmfonts"
            echo "[watch-dpi] KDE: reset forceFontDPI from $cur_dpi to 0"
        fi
    fi
    echo "[watch-dpi] KDE: DPI=$dpi (Selkies xsettingsd handles scaling)"
}

# ── Main watch loop ─────────────────────────────────────────
# XFCE: Selkies sets DPI via xfconf-query, which updates xfconfd in memory
# but may NOT immediately flush to xsettings.xml. So inotifywait on the file
# is unreliable for XFCE. Use a hybrid approach:
#   - XFCE: poll xfconf-query every 2 seconds
#   - Others: inotifywait on file changes (original behavior)

if [ "$DE" = "xfce" ]; then
    echo "[watch-dpi] XFCE mode: polling xfconf-query every 2s"
    while true; do
        sleep 2
        NEW_DPI=$(read_dpi)
        if [ "$NEW_DPI" -gt 0 ] && [ "$NEW_DPI" != "$LAST_DPI" ]; then
            echo "[watch-dpi] DPI changed: $LAST_DPI → $NEW_DPI"
            LAST_DPI=$NEW_DPI
            update_xfce_panel "$NEW_DPI"
        fi
    done
else
    while true; do
        inotifywait -qq -e modify -e close_write "$WATCH_FILE" 2>/dev/null || { sleep 5; continue; }
        sleep 0.3
        NEW_DPI=$(read_dpi)
        if [ "$NEW_DPI" -gt 0 ] && [ "$NEW_DPI" != "$LAST_DPI" ]; then
            echo "[watch-dpi] DPI changed: $LAST_DPI → $NEW_DPI"
            LAST_DPI=$NEW_DPI
            case "$DE" in
                kde)
                    update_kde_scaling "$NEW_DPI"
                    ;;
                *)  # lxqt
                    update_lxqt_gtk_scaling "$NEW_DPI"
                    update_lxqt_panel "$NEW_DPI"
                    update_lxqt_session "$NEW_DPI"
                    update_openbox_theme "$NEW_DPI"
                    ;;
            esac
        fi
    done
fi
