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

DPI="${SELKIES_SCALING_DPI:-96}"

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
            # Insert DPI property inside existing Xft element
            sed -i "/<property name=\"Xft\"/a\\      <property name=\"DPI\" type=\"int\" value=\"$DPI\"/>" "$XSETTINGS_XML"
        fi
        # Update cursor size
        if grep -q 'name="CursorThemeSize"' "$XSETTINGS_XML"; then
            sed -i "s|name=\"CursorThemeSize\" type=\"[^\"]*\" value=\"[^\"]*\"|name=\"CursorThemeSize\" type=\"int\" value=\"$CURSOR_SIZE\"|" "$XSETTINGS_XML"
        elif grep -q 'name="Gtk"' "$XSETTINGS_XML"; then
            sed -i "/<property name=\"Gtk\"/a\\      <property name=\"CursorThemeSize\" type=\"int\" value=\"$CURSOR_SIZE\"/>" "$XSETTINGS_XML"
        fi
    else
        # Create a minimal xsettings.xml with DPI and cursor size
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
  <property name="Gtk" type="empty">
    <property name="CursorThemeSize" type="int" value="$CURSOR_SIZE"/>
  </property>
</channel>
EOF
    fi
    chown -R abc:abc "${HOME}/.config/xfce4"
    echo "[set-dpi] XFCE xsettings.xml: DPI=$DPI, CursorThemeSize=$CURSOR_SIZE"
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
fi

echo "[set-dpi] Done (DPI=$DPI, Scale=${SCALE_FACTOR}x, Cursor=${CURSOR_SIZE}px)"
