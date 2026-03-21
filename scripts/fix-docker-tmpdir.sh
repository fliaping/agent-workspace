#!/bin/bash
# fix-docker-tmpdir.sh — Fix containerd overlay mount failures in DinD mode
#
# Problem:
#   LinuxServer webtop sets TMPDIR to a path under /config (bind mount).
#   Containerd uses TMPDIR for overlay mount assembly (os.MkdirTemp),
#   but overlay-on-bind-mount fails with "invalid argument".
#
# Fix:
#   Wrap dockerd so it always runs with TMPDIR=/tmp (container root fs,
#   which supports overlay mounts).
#
# Runs as custom-cont-init.d script (before services start).

[ "$START_DOCKER" != "true" ] && exit 0

DOCKERD=$(command -v dockerd 2>/dev/null)
[ -z "$DOCKERD" ] && exit 0

# Already wrapped?
[ -f "${DOCKERD}.real" ] && exit 0

echo "[fix-docker-tmpdir] Wrapping dockerd to use TMPDIR=/tmp..."

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

echo "[fix-docker-tmpdir] Done"
