#!/bin/bash
# ============================================================
# fix-locale.sh — Fix LANGUAGE env to match LC_ALL
#
# LinuxServer sets LANGUAGE=en_US.UTF-8 by default, which
# overrides LC_ALL for GNU gettext message catalogs, causing
# applications to show English even when LC_ALL=zh_CN.UTF-8.
#
# This script derives LANGUAGE from LC_ALL so translations work.
# ============================================================

if [ -z "$LC_ALL" ] || [ "$LC_ALL" = "en_US.UTF-8" ]; then
    exit 0
fi

LANG_FULL=$(echo "$LC_ALL" | cut -d. -f1)   # e.g. zh_CN
LANG_SHORT=$(echo "$LANG_FULL" | cut -d_ -f1) # e.g. zh

echo "[fix-locale] Setting LANGUAGE=${LANG_FULL}:${LANG_SHORT} (from LC_ALL=$LC_ALL)"

cat > /etc/profile.d/fix-language.sh <<EOF
export LANGUAGE=${LANG_FULL}:${LANG_SHORT}
EOF
chmod +x /etc/profile.d/fix-language.sh

# Also export for current s6 services
export LANGUAGE="${LANG_FULL}:${LANG_SHORT}"
