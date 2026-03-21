#!/bin/bash
# fix-docker-env.sh — Fix DinD data-root and TMPDIR for container environment
#
# 1. Set Docker data-root to ~/docker-data (persistent across container recreate)
# 2. Wrap dockerd with TMPDIR=/tmp to fix containerd overlay mount failures
#    (LinuxServer webtop sets TMPDIR under /config, a bind mount where
#    overlay-on-bind-mount fails with "invalid argument")
#
# Runs as custom-cont-init.d script (before services start).

[ "$START_DOCKER" != "true" ] && exit 0

DOCKERD=$(command -v dockerd 2>/dev/null)
[ -z "$DOCKERD" ] && exit 0

# ── Configure Docker daemon data-root ────────────────────────
DOCKER_DATA="${HOME}/docker-data"
mkdir -p "$DOCKER_DATA" /etc/docker

# Write daemon.json (preserve existing keys if present)
if [ ! -f /etc/docker/daemon.json ]; then
    cat > /etc/docker/daemon.json << EOF
{
    "data-root": "${DOCKER_DATA}"
}
EOF
    echo "[fix-docker-env] Created /etc/docker/daemon.json (data-root: ${DOCKER_DATA})"
else
    # Ensure data-root is set (don't overwrite if already configured)
    if ! grep -q '"data-root"' /etc/docker/daemon.json 2>/dev/null; then
        # Insert data-root into existing JSON
        sed -i 's|^{|{\n    "data-root": "'"${DOCKER_DATA}"'",|' /etc/docker/daemon.json
        echo "[fix-docker-env] Added data-root to existing daemon.json"
    else
        echo "[fix-docker-env] daemon.json already has data-root configured"
    fi
fi

# ── Wrap dockerd to fix TMPDIR ───────────────────────────────
# Already wrapped?
if [ -f "${DOCKERD}.real" ]; then
    echo "[fix-docker-env] dockerd already wrapped"
    exit 0
fi

echo "[fix-docker-env] Wrapping dockerd to use TMPDIR=/tmp..."

mv "$DOCKERD" "${DOCKERD}.real"
cat > "$DOCKERD" << 'WRAPPER'
#!/bin/bash
# Wrapper: ensure containerd uses /tmp for overlay mounts, not /config/.XDG
export TMPDIR=/tmp
export DOCKER_TMPDIR=/tmp/docker-tmp
mkdir -p /tmp/docker-tmp
exec "$(dirname "$0")/dockerd.real" "$@"
WRAPPER
chmod +x "$DOCKERD"

echo "[fix-docker-env] Done"
