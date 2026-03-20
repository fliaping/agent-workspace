#!/bin/bash
# ============================================================
# watch-dpi.sh — Dynamic DPI watcher
#
# Monitors ~/.xsettingsd for changes (written by Selkies when
# a web client connects with a different DPI). When DPI changes,
# dynamically updates:
#   - LXQt panel size and icon size
#   - Openbox theme padding (regenerate HiDPI theme)
#
# Runs as an s6 service after DE starts.
# ============================================================

XSET="${HOME}/.xsettingsd"
LAST_DPI=0

# Wait for the file and DE to be ready
for i in $(seq 1 30); do
    [ -f "$XSET" ] && break
    sleep 2
done
[ -f "$XSET" ] || { echo "[watch-dpi] $XSET not found, exiting"; exit 0; }

# Read initial DPI
read_dpi() {
    local raw
    raw=$(grep "^Xft/DPI" "$XSET" 2>/dev/null | awk '{print $2}')
    if [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
        echo $(( raw / 1024 ))
    else
        echo 0
    fi
}

LAST_DPI=$(read_dpi)
echo "[watch-dpi] Initial DPI: $LAST_DPI, watching $XSET for changes"

# ── Update functions ────────────────────────────────────────

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

    # Find current theme
    local ob_rc="${HOME}/.config/openbox/rc.xml"
    [ -f "$ob_rc" ] || ob_rc="/etc/xdg/openbox/rc.xml"
    local current_theme
    current_theme=$(grep -oP '<name>\K[^<]+' "$ob_rc" 2>/dev/null | head -1)
    [ -z "$current_theme" ] && return

    # Determine base theme name (strip -HiDPI suffix if present)
    local base_theme="${current_theme%-HiDPI}"

    if [ "$dpi" -le 96 ]; then
        # Restore original theme
        if [ "$current_theme" != "$base_theme" ] && [ -f "${HOME}/.config/openbox/rc.xml" ]; then
            sed -i "s|<name>${current_theme}</name>|<name>${base_theme}</name>|" \
                "${HOME}/.config/openbox/rc.xml"
            DISPLAY=:1 openbox --reconfigure 2>/dev/null
            echo "[watch-dpi] Openbox: restored theme $base_theme"
        fi
        return
    fi

    # Create/update HiDPI theme
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

    # Apply HiDPI theme if not already active
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

    if grep -q "^font_dpi=" "$session_conf"; then
        sed -i "s|^font_dpi=.*|font_dpi=$dpi|" "$session_conf"
    fi
    if grep -q "^QT_FONT_DPI=" "$session_conf"; then
        sed -i "s|^QT_FONT_DPI=.*|QT_FONT_DPI=$dpi|" "$session_conf"
    fi
}

# ── Main watch loop ─────────────────────────────────────────

while true; do
    # Wait for file modification
    inotifywait -qq -e modify "$XSET" 2>/dev/null || { sleep 5; continue; }

    # Small delay to let Selkies finish writing
    sleep 0.3

    NEW_DPI=$(read_dpi)
    if [ "$NEW_DPI" -gt 0 ] && [ "$NEW_DPI" != "$LAST_DPI" ]; then
        echo "[watch-dpi] DPI changed: $LAST_DPI → $NEW_DPI"
        LAST_DPI=$NEW_DPI

        # Detect DE and apply
        if command -v startplasma-x11 >/dev/null 2>&1; then
            : # KDE handles its own scaling
        elif command -v xfce4-session >/dev/null 2>&1; then
            : # XFCE uses xfconf, Selkies handles it
        else
            # LXQt/Openbox
            update_lxqt_panel "$NEW_DPI"
            update_lxqt_session "$NEW_DPI"
            update_openbox_theme "$NEW_DPI"
        fi
    fi
done
