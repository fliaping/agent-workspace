#!/bin/bash
# ============================================================
# set-dpi.sh — Pre-DE DPI configuration (LXQt / XFCE / KDE)
#
# Runs via /custom-cont-init.d/ BEFORE xsettingsd and DE start.
# Reads SELKIES_SCALING_DPI and pre-configures DPI for the
# detected desktop environment so it launches with proper
# HiDPI scaling from the start.
#
# Without this, Selkies only applies DPI after a web client
# connects, leaving WM decorations and panels at 96 DPI.
#
# DE detection (same order as Selkies set_dpi):
#   KDE      → .Xresources + .xsettingsd + kdeglobals + kcmfonts
#   XFCE     → xfconf xsettings.xml (xfconf-query not available yet)
#   LXQt     → .Xresources + .xsettingsd
# ============================================================

# If SELKIES_SCALING_DPI is not set, skip all DPI configuration
# and let Selkies handle DPI dynamically (matching official webtop behavior).
if [ -z "${SELKIES_SCALING_DPI}" ]; then
    echo "[set-dpi] SELKIES_SCALING_DPI not set, skipping (Selkies will auto-detect)"
    exit 0
fi

DPI="${SELKIES_SCALING_DPI}"

# Validate
if ! [[ "$DPI" =~ ^[0-9]+$ ]] || [ "$DPI" -le 0 ]; then
    echo "[set-dpi] Invalid SELKIES_SCALING_DPI=$DPI, using 96"
    DPI=96
fi

echo "[set-dpi] Setting DPI to $DPI"

SCALE_FACTOR=$(awk "BEGIN { printf \"%.1f\", $DPI / 96 }")
SCALE_INT=$(awk "BEGIN { v=$DPI/96; printf \"%d\", (v>=1.75) ? 2 : 1 }")
CURSOR_SIZE=$(awk "BEGIN { printf \"%d\", $DPI / 96 * 32 + 0.5 }")
XSETTINGS_DPI=$(( DPI * 1024 ))
# Gdk/UnscaledDPI = base DPI (before integer scale factor) * 1024
UNSCALED_DPI=$(( (DPI / SCALE_INT) * 1024 ))

# ── Common: .Xresources ────────────────────────────────────
# svc-de/run loads this via xrdb before starting the DE.
setup_xresources() {
    local XRES="${HOME}/.Xresources"
    if [ -f "$XRES" ]; then
        if grep -q "^Xft\.dpi:" "$XRES"; then
            sed -i "s/^Xft\.dpi:.*/Xft.dpi: $DPI/" "$XRES"
        else
            echo "Xft.dpi: $DPI" >> "$XRES"
        fi
    else
        cat > "$XRES" <<EOF
Xcursor.theme: breeze
Xft.dpi: $DPI
EOF
    fi
    chown abc:abc "$XRES"
    echo "[set-dpi] .Xresources: Xft.dpi=$DPI"
}

# ── Common: .xsettingsd ────────────────────────────────────
# Used by LXQt and KDE (xsettingsd runs for these DEs).
# XFCE's xsettingsd does "sleep infinity", so this has no effect on XFCE.
setup_xsettingsd() {
    local XSET="${HOME}/.xsettingsd"
    if [ -f "$XSET" ]; then
        if grep -q "^Xft/DPI" "$XSET"; then
            sed -i "s|^Xft/DPI.*|Xft/DPI $XSETTINGS_DPI|" "$XSET"
        else
            echo "Xft/DPI $XSETTINGS_DPI" >> "$XSET"
        fi
    else
        cat > "$XSET" <<EOF
Xft/Antialias 1
Xft/Hinting 1
Xft/HintStyle "hintfull"
Xft/RGBA "rgb"
Xft/DPI $XSETTINGS_DPI
Gdk/WindowScalingFactor $SCALE_INT
Gdk/UnscaledDPI $UNSCALED_DPI
EOF
    fi
    # Ensure Gdk entries exist (for pre-existing files)
    if ! grep -q "^Gdk/WindowScalingFactor" "$XSET"; then
        echo "Gdk/WindowScalingFactor $SCALE_INT" >> "$XSET"
    else
        sed -i "s|^Gdk/WindowScalingFactor.*|Gdk/WindowScalingFactor $SCALE_INT|" "$XSET"
    fi
    if ! grep -q "^Gdk/UnscaledDPI" "$XSET"; then
        echo "Gdk/UnscaledDPI $UNSCALED_DPI" >> "$XSET"
    else
        sed -i "s|^Gdk/UnscaledDPI.*|Gdk/UnscaledDPI $UNSCALED_DPI|" "$XSET"
    fi
    chown abc:abc "$XSET"
    echo "[set-dpi] .xsettingsd: Xft/DPI=$XSETTINGS_DPI, Gdk/WindowScalingFactor=$SCALE_INT, Gdk/UnscaledDPI=$UNSCALED_DPI"
}

# ── XFCE: pre-populate xfconf XML ──────────────────────────
# At init time, xfconfd is not running yet so xfconf-query won't work.
# We write the xfconf XML directly. xfconfd reads this on startup.
setup_xfce() {
    local XFCE_DIR="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"
    local XSETTINGS_XML="${XFCE_DIR}/xsettings.xml"

    mkdir -p "$XFCE_DIR"

    if [ -f "$XSETTINGS_XML" ]; then
        # Update existing DPI value if present, otherwise inject it
        if grep -q 'name="DPI"' "$XSETTINGS_XML"; then
            sed -i "s|name=\"DPI\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"DPI\" type=\"int\" value=\"$DPI\"|" "$XSETTINGS_XML"
        elif grep -q 'name="Xft"' "$XSETTINGS_XML"; then
            sed -i "/<property name=\"Xft\"/a\\      <property name=\"DPI\" type=\"int\" value=\"$DPI\"/>" "$XSETTINGS_XML"
        fi
        # Update Gdk/WindowScalingFactor
        if grep -q 'name="WindowScalingFactor"' "$XSETTINGS_XML"; then
            sed -i "s|name=\"WindowScalingFactor\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"WindowScalingFactor\" type=\"int\" value=\"$SCALE_INT\"|" "$XSETTINGS_XML"
        elif grep -q 'name="Gdk"' "$XSETTINGS_XML"; then
            sed -i "/<property name=\"Gdk\"/a\\      <property name=\"WindowScalingFactor\" type=\"int\" value=\"$SCALE_INT\"/>" "$XSETTINGS_XML"
        else
            sed -i "/<\/channel>/i\\  <property name=\"Gdk\" type=\"empty\">\n    <property name=\"WindowScalingFactor\" type=\"int\" value=\"$SCALE_INT\"/>\n    <property name=\"UnscaledDPI\" type=\"int\" value=\"$UNSCALED_DPI\"/>\n  </property>" "$XSETTINGS_XML"
        fi
        # Update Gdk/UnscaledDPI
        if grep -q 'name="UnscaledDPI"' "$XSETTINGS_XML"; then
            sed -i "s|name=\"UnscaledDPI\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"UnscaledDPI\" type=\"int\" value=\"$UNSCALED_DPI\"|" "$XSETTINGS_XML"
        fi
        # Update cursor size
        if grep -q 'name="CursorThemeSize"' "$XSETTINGS_XML"; then
            sed -i "s|name=\"CursorThemeSize\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"CursorThemeSize\" type=\"int\" value=\"$CURSOR_SIZE\"|" "$XSETTINGS_XML"
        elif grep -q 'name="Gtk"' "$XSETTINGS_XML"; then
            sed -i "/<property name=\"Gtk\"/a\\      <property name=\"CursorThemeSize\" type=\"int\" value=\"$CURSOR_SIZE\"/>" "$XSETTINGS_XML"
        fi
    else
        # Create xsettings.xml with DPI, Gdk scaling, and cursor size
        cat > "$XSETTINGS_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xsettings" version="1.0">
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="$DPI"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintfull"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
  <property name="Gdk" type="empty">
    <property name="WindowScalingFactor" type="int" value="$SCALE_INT"/>
    <property name="UnscaledDPI" type="int" value="$UNSCALED_DPI"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeSize" type="int" value="$CURSOR_SIZE"/>
  </property>
</channel>
EOF
    fi
    chown -R abc:abc "${HOME}/.config/xfce4"
    echo "[set-dpi] XFCE xsettings.xml: DPI=$DPI, WindowScalingFactor=$SCALE_INT, UnscaledDPI=$UNSCALED_DPI"

    # Scale XFCE panel size and icon size in xfconf XML
    # Default: panel size=26, icon-size=16 (designed for 96 DPI)
    local PANEL_SIZE=$(awk "BEGIN { printf \"%d\", 26 * $DPI / 96 + 0.5 }")
    local PANEL_ICON_SIZE=$(awk "BEGIN { printf \"%d\", 16 * $DPI / 96 + 0.5 }")

    local PANEL_XML="${XFCE_DIR}/xfce4-panel.xml"
    if [ -f "$PANEL_XML" ]; then
        # Update existing size value
        if grep -q 'name="size"' "$PANEL_XML"; then
            sed -i "s|name=\"size\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"size\" type=\"uint\" value=\"$PANEL_SIZE\"|" "$PANEL_XML"
        fi
        if grep -q 'name="icon-size"' "$PANEL_XML"; then
            sed -i "s|name=\"icon-size\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"icon-size\" type=\"uint\" value=\"$PANEL_ICON_SIZE\"|" "$PANEL_XML"
        fi
        chown -R abc:abc "${HOME}/.config/xfce4"
    fi
    echo "[set-dpi] XFCE panel: size=$PANEL_SIZE, icon-size=$PANEL_ICON_SIZE"
}

# ── KDE: pre-populate kdeglobals + kcmfonts ─────────────────
# KDE uses its own scaling system in addition to xrdb/xsettingsd.
setup_kde() {
    local KDE_DIR="${HOME}/.config"
    mkdir -p "$KDE_DIR"

    # kdeglobals: ScaleFactor for global UI scaling
    local KDEGLOBALS="${KDE_DIR}/kdeglobals"
    if [ -f "$KDEGLOBALS" ]; then
        if grep -q "^\[KScreen\]" "$KDEGLOBALS"; then
            # Update ScaleFactor in existing [KScreen] section
            sed -i "/^\[KScreen\]/,/^\[/{s|^ScaleFactor=.*|ScaleFactor=$SCALE_FACTOR|}" "$KDEGLOBALS"
            if ! grep -A 20 "^\[KScreen\]" "$KDEGLOBALS" | grep -q "^ScaleFactor="; then
                sed -i "/^\[KScreen\]/a ScaleFactor=$SCALE_FACTOR" "$KDEGLOBALS"
            fi
        else
            printf "\n[KScreen]\nScaleFactor=%s\n" "$SCALE_FACTOR" >> "$KDEGLOBALS"
        fi
    else
        cat > "$KDEGLOBALS" <<EOF
[KScreen]
ScaleFactor=$SCALE_FACTOR
EOF
    fi
    chown abc:abc "$KDEGLOBALS"

    # kcmfonts: forceFontDPI for font rendering
    local KCMFONTS="${KDE_DIR}/kcmfonts"
    if [ -f "$KCMFONTS" ]; then
        if grep -q "^forceFontDPI=" "$KCMFONTS"; then
            sed -i "s|^forceFontDPI=.*|forceFontDPI=$DPI|" "$KCMFONTS"
        elif grep -q "^\[General\]" "$KCMFONTS"; then
            sed -i "/^\[General\]/a forceFontDPI=$DPI" "$KCMFONTS"
        else
            printf "\n[General]\nforceFontDPI=%s\n" "$DPI" >> "$KCMFONTS"
        fi
    else
        cat > "$KCMFONTS" <<EOF
[General]
forceFontDPI=$DPI
EOF
    fi
    chown abc:abc "$KCMFONTS"
    echo "[set-dpi] KDE: ScaleFactor=$SCALE_FACTOR, forceFontDPI=$DPI"
}

# ── LXQt: pre-populate session.conf ─────────────────────────
# lxqt-session reads font_dpi from session.conf at startup.
setup_lxqt() {
    local LXQT_DIR="${HOME}/.config/lxqt"
    local SESSION_CONF="${LXQT_DIR}/session.conf"

    mkdir -p "$LXQT_DIR"

    if [ -f "$SESSION_CONF" ]; then
        if grep -q "^font_dpi=" "$SESSION_CONF"; then
            sed -i "s|^font_dpi=.*|font_dpi=$DPI|" "$SESSION_CONF"
        elif grep -q "^\[General\]" "$SESSION_CONF"; then
            sed -i "/^\[General\]/a font_dpi=$DPI" "$SESSION_CONF"
        else
            printf "\n[General]\nfont_dpi=%s\n" "$DPI" >> "$SESSION_CONF"
        fi
        # Ensure QT_FONT_DPI in [Environment] section
        if grep -q "^QT_FONT_DPI=" "$SESSION_CONF"; then
            sed -i "s|^QT_FONT_DPI=.*|QT_FONT_DPI=$DPI|" "$SESSION_CONF"
        elif grep -q "^\[Environment\]" "$SESSION_CONF"; then
            sed -i "/^\[Environment\]/a QT_FONT_DPI=$DPI" "$SESSION_CONF"
        else
            printf "\n[Environment]\nQT_FONT_DPI=%s\n" "$DPI" >> "$SESSION_CONF"
        fi
    else
        cat > "$SESSION_CONF" <<EOF
[General]
__userfile__=true
font_dpi=$DPI

[Environment]
QT_FONT_DPI=$DPI
EOF
    fi
    chown -R abc:abc "$LXQT_DIR"
    echo "[set-dpi] LXQt session.conf: font_dpi=$DPI, QT_FONT_DPI=$DPI"

    # Scale panel size and icon size based on DPI
    # Default: panelSize=32, iconSize=22 (designed for 96 DPI)
    local PANEL_CONF="${LXQT_DIR}/panel.conf"
    local PANEL_SIZE=$(awk "BEGIN { printf \"%d\", 32 * $DPI / 96 + 0.5 }")
    local ICON_SIZE=$(awk "BEGIN { printf \"%d\", 22 * $DPI / 96 + 0.5 }")
    if [ -f "$PANEL_CONF" ]; then
        if grep -q "^panelSize=" "$PANEL_CONF"; then
            sed -i "s|^panelSize=.*|panelSize=$PANEL_SIZE|" "$PANEL_CONF"
        fi
        if grep -q "^iconSize=" "$PANEL_CONF"; then
            sed -i "s|^iconSize=.*|iconSize=$ICON_SIZE|" "$PANEL_CONF"
        fi
    fi
    chown -R abc:abc "$LXQT_DIR"
    echo "[set-dpi] LXQt panel: panelSize=$PANEL_SIZE, iconSize=$ICON_SIZE"
}

# ── Openbox: create HiDPI theme ─────────────────────────────
# Openbox buttons and titlebar don't scale with DPI.
# We create a scaled copy of the current theme with larger padding.
setup_openbox_theme() {
    [ "$DPI" -le 96 ] && return 0

    # Find current theme name from rc.xml
    local OB_RC="${HOME}/.config/openbox/rc.xml"
    [ -f "$OB_RC" ] || OB_RC="/etc/xdg/openbox/rc.xml"
    local CURRENT_THEME
    CURRENT_THEME=$(grep -oP '<name>\K[^<]+' "$OB_RC" | head -1)
    [ -z "$CURRENT_THEME" ] && CURRENT_THEME="Clearlooks"

    # Skip if already a HiDPI theme
    case "$CURRENT_THEME" in *-HiDPI) return 0 ;; esac

    local SRC="/usr/share/themes/${CURRENT_THEME}/openbox-3"
    [ -d "$SRC" ] || return 0

    local DST="${HOME}/.themes/${CURRENT_THEME}-HiDPI/openbox-3"
    mkdir -p "$DST"
    cp "$SRC"/* "$DST/" 2>/dev/null

    # Scale padding proportionally
    local SCALE_RATIO
    SCALE_RATIO=$(awk "BEGIN { printf \"%.0f\", $DPI / 96 }")
    if [ -f "$DST/themerc" ]; then
        # Read current values, scale them
        local PW PH BW
        PW=$(grep -oP '^padding\.width:\s*\K\d+' "$DST/themerc" || echo 4)
        PH=$(grep -oP '^padding\.height:\s*\K\d+' "$DST/themerc" || echo 2)
        BW=$(grep -oP '^border\.width:\s*\K\d+' "$DST/themerc" || echo 1)
        sed -i "s/^padding\.width:.*/padding.width: $(( PW * SCALE_RATIO ))/" "$DST/themerc"
        sed -i "s/^padding\.height:.*/padding.height: $(( PH * SCALE_RATIO ))/" "$DST/themerc"
        sed -i "s/^border\.width:.*/border.width: $(( BW * SCALE_RATIO ))/" "$DST/themerc"
    fi
    chown -R abc:abc "${HOME}/.themes"

    # Apply the new theme in user rc.xml
    mkdir -p "${HOME}/.config/openbox"
    if [ ! -f "${HOME}/.config/openbox/rc.xml" ]; then
        cp /etc/xdg/openbox/rc.xml "${HOME}/.config/openbox/rc.xml"
    fi
    sed -i "s|<name>${CURRENT_THEME}</name>|<name>${CURRENT_THEME}-HiDPI</name>|" \
        "${HOME}/.config/openbox/rc.xml"
    chown -R abc:abc "${HOME}/.config/openbox"
    echo "[set-dpi] Openbox theme: ${CURRENT_THEME}-HiDPI (padding scaled ${SCALE_RATIO}x)"
}

# ── Detect DE and apply ─────────────────────────────────────
# Detection order matches Selkies: KDE → XFCE → Openbox (LXQt)
if command -v startplasma-x11 >/dev/null 2>&1; then
    echo "[set-dpi] Detected: KDE"
    setup_xresources
    setup_xsettingsd
    setup_kde
elif command -v xfce4-session >/dev/null 2>&1; then
    echo "[set-dpi] Detected: XFCE"
    setup_xresources
    setup_xfce
else
    echo "[set-dpi] Detected: LXQt/Openbox (default)"
    setup_xresources
    setup_xsettingsd
    setup_lxqt
    setup_openbox_theme
fi

echo "[set-dpi] Done (DPI=$DPI, Scale=${SCALE_FACTOR}x, Cursor=${CURSOR_SIZE}px)"
