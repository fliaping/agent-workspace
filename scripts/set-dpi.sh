#!/bin/bash
# ============================================================
# set-dpi.sh — Pre-DE DPI configuration
#
# Runs via /custom-cont-init.d/ BEFORE xsettingsd and DE start.
# Reads SELKIES_SCALING_DPI and writes correct DPI values to
# .Xresources and .xsettingsd so the desktop environment
# launches with proper HiDPI scaling from the start.
#
# Without this, Selkies only applies DPI after a web client
# connects, leaving WM decorations and panels at 96 DPI.
# ============================================================

DPI="${SELKIES_SCALING_DPI:-96}"

# Validate
if ! [[ "$DPI" =~ ^[0-9]+$ ]] || [ "$DPI" -le 0 ]; then
    echo "[set-dpi] Invalid SELKIES_SCALING_DPI=$DPI, using 96"
    DPI=96
fi

echo "[set-dpi] Setting DPI to $DPI"

# ── .Xresources ──────────────────────────────────────────────
# svc-de/run loads this via xrdb before starting the DE.
XRES="${HOME}/.Xresources"
if [ -f "$XRES" ]; then
    # Update existing Xft.dpi or append
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

# ── .xsettingsd ──────────────────────────────────────────────
# svc-xsettingsd only creates this if missing; we pre-create it.
XSETTINGS_DPI=$(( DPI * 1024 ))
XSET="${HOME}/.xsettingsd"
if [ -f "$XSET" ]; then
    if grep -q "^Xft/DPI" "$XSET"; then
        sed -i "s/^Xft\/DPI.*/Xft\/DPI $XSETTINGS_DPI/" "$XSET"
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
EOF
fi
chown abc:abc "$XSET"

echo "[set-dpi] Done: Xft.dpi=$DPI, Xft/DPI=$XSETTINGS_DPI"
