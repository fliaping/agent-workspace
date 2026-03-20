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
    # Parse DPI from xsettings.xml: <property name="DPI" type="int" value="192"/>
    local val
    val=$(grep -oP 'name="DPI"[^/]*value="\K[0-9]+' "$WATCH_FILE" 2>/dev/null | head -1)
    if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
        echo "$val"
    else
        # Fallback: try xfconf-query (as session user for D-Bus access)
        val=$(su abc -s /bin/bash -c "DISPLAY=:1 xfconf-query -c xsettings -p /Xft/DPI" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
            echo "$val"
        else
            echo 0
        fi
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

# ── XFCE update functions ──────────────────────────────────

update_xfce_panel() {
    local dpi=$1
    which xfconf-query >/dev/null 2>&1 || return

    local scale_int=$(awk "BEGIN { v=$dpi/96; printf \"%d\", (v>=1.75) ? 2 : 1 }")
    local unscaled_dpi=$(( (dpi / scale_int) * 1024 ))
    local dpi_scale=$(awk "BEGIN { printf \"%.1f\", 1.0 / $scale_int }")

    # Update xfconf Gdk scaling
    su abc -s /bin/bash -c "
        export DISPLAY=:1
        xfconf-query -c xsettings -p /Gdk/WindowScalingFactor \
            -s $scale_int --create -t int 2>/dev/null
        xfconf-query -c xsettings -p /Gdk/UnscaledDPI \
            -s $unscaled_dpi --create -t int 2>/dev/null
    " 2>/dev/null

    # Update env vars for new processes
    cat > /etc/profile.d/hidpi.sh <<ENVEOF
export GDK_SCALE=$scale_int
export GDK_DPI_SCALE=$dpi_scale
ENVEOF
    local S6_ENV="/run/s6/container_environment"
    [ -d "$S6_ENV" ] || S6_ENV="/var/run/s6/container_environment"
    if [ -d "$S6_ENV" ]; then
        echo "$scale_int" > "$S6_ENV/GDK_SCALE"
        echo "$dpi_scale" > "$S6_ENV/GDK_DPI_SCALE"
    fi

    # Restart panel and xfwm4 with updated GDK_SCALE
    su abc -s /bin/bash -c "
        export DISPLAY=:1
        export GDK_SCALE=$scale_int
        export GDK_DPI_SCALE=$dpi_scale
        xfce4-panel --quit 2>/dev/null; sleep 0.5
        nohup xfce4-panel >/dev/null 2>&1 &
        xfwm4 --replace >/dev/null 2>&1 &
    " 2>/dev/null
    echo "[watch-dpi] XFCE: GDK_SCALE=$scale_int, restarted panel+xfwm4"
}

update_xfwm4_font() {
    # No-op: GDK_SCALE handles font/widget scaling for XFCE
    :
}

# ── KDE update functions ───────────────────────────────────

update_kde_scaling() {
    local dpi=$1
    local scale=$(awk "BEGIN { printf \"%.1f\", $dpi / 96 }")

    # Update kdeglobals
    local kdeglobals="${HOME}/.config/kdeglobals"
    if [ -f "$kdeglobals" ]; then
        if grep -q "^\[KScreen\]" "$kdeglobals"; then
            sed -i "/^\[KScreen\]/,/^\[/{s|^ScaleFactor=.*|ScaleFactor=$scale|}" "$kdeglobals"
            if ! grep -A 20 "^\[KScreen\]" "$kdeglobals" | grep -q "^ScaleFactor="; then
                sed -i "/^\[KScreen\]/a ScaleFactor=$scale" "$kdeglobals"
            fi
        else
            printf "\n[KScreen]\nScaleFactor=%s\n" "$scale" >> "$kdeglobals"
        fi
    fi

    # Update kcmfonts
    local kcmfonts="${HOME}/.config/kcmfonts"
    if [ -f "$kcmfonts" ]; then
        if grep -q "^forceFontDPI=" "$kcmfonts"; then
            sed -i "s|^forceFontDPI=.*|forceFontDPI=$dpi|" "$kcmfonts"
        fi
    fi
    echo "[watch-dpi] KDE: ScaleFactor=$scale, forceFontDPI=$dpi"

    # Restart plasmashell and KWin to apply
    if pgrep -x plasmashell >/dev/null 2>&1; then
        echo "[watch-dpi] KDE: restarting plasmashell + kwin..."
        DISPLAY=:1 su abc -s /bin/bash -c '
            kquitapp5 plasmashell 2>/dev/null; sleep 1; kstart5 plasmashell 2>/dev/null &
            kwin_x11 --replace 2>/dev/null &
        ' 2>/dev/null
        echo "[watch-dpi] KDE: restart complete"
    fi
}

# ── Main watch loop ─────────────────────────────────────────

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
            xfce)
                update_xfce_panel "$NEW_DPI"
                update_xfwm4_font "$NEW_DPI"
                ;;
            *)  # lxqt
                update_lxqt_panel "$NEW_DPI"
                update_lxqt_session "$NEW_DPI"
                update_openbox_theme "$NEW_DPI"
                ;;
        esac
    fi
done
