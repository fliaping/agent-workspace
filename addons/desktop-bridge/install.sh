#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${CONFIG_ROOT:-/config}"
INSTALL_ROOT="${AGENT_DESKTOP_INSTALL_ROOT:-${CONFIG_ROOT}/opt/agent-desktop-bridge}"
UNIT_DIR="${CONFIG_ROOT}/.config/systemd/user"
WANTS_DIR="${UNIT_DIR}/default.target.wants"

mkdir -p "$INSTALL_ROOT/bin" "$UNIT_DIR" "$WANTS_DIR" "${CONFIG_ROOT}/bin" "${CONFIG_ROOT}/.local/bin" "${CONFIG_ROOT}/.local/state/agent-desktop-bridge"
install -m 0755 "$PACKAGE_ROOT/bin/agent-desktop-bridge" "$INSTALL_ROOT/bin/agent-desktop-bridge"
install -m 0755 "$PACKAGE_ROOT/bin/agent-desktop-mcp" "$INSTALL_ROOT/bin/agent-desktop-mcp"
install -m 0644 "$PACKAGE_ROOT/systemd/user/agent-desktop-bridge.service" "$UNIT_DIR/agent-desktop-bridge.service"
ln -sfn "$UNIT_DIR/agent-desktop-bridge.service" "$WANTS_DIR/agent-desktop-bridge.service"
for command in agent-desktop-bridge agent-desktop-mcp; do
  ln -sfn "$INSTALL_ROOT/bin/$command" "${CONFIG_ROOT}/bin/$command"
  ln -sfn "${CONFIG_ROOT}/bin/$command" "${CONFIG_ROOT}/.local/bin/$command"
done

if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
  chown -R abc:abc "$INSTALL_ROOT" "${CONFIG_ROOT}/.local/state/agent-desktop-bridge"
  chown abc:abc "$UNIT_DIR/agent-desktop-bridge.service"
  chown -h abc:abc "$WANTS_DIR/agent-desktop-bridge.service" "${CONFIG_ROOT}/bin/agent-desktop-bridge" "${CONFIG_ROOT}/bin/agent-desktop-mcp" "${CONFIG_ROOT}/.local/bin/agent-desktop-bridge" "${CONFIG_ROOT}/.local/bin/agent-desktop-mcp"
fi

# Activate the native backend immediately on older running images. Rebuilt
# images receive the same value from Dockerfile ENV.
if [[ -d /var/run/s6/container_environment ]] && command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  temporary="$(mktemp)"
  trap 'rm -f -- "$temporary"' EXIT
  printf '8764' >"$temporary"
  sudo -n install -m 0644 "$temporary" /var/run/s6/container_environment/PIXELFLUX_CU
fi

systemctl --user daemon-reload || true
systemctl --user enable agent-desktop-bridge.service
systemctl --user restart agent-desktop-bridge.service

if [[ -d /run/service/svc-selkies ]] && ! (exec 3<>/dev/tcp/127.0.0.1/8764) 2>/dev/null; then
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n s6-svc -r /run/service/svc-selkies || true
    echo "[desktop-bridge] restarted Selkies to enable its loopback Computer Use backend"
  else
    echo "[desktop-bridge] restart the container once to enable the Selkies backend"
  fi
fi

echo "[desktop-bridge] bridge installed on 127.0.0.1:8765"
echo "[desktop-bridge] native Selkies backend uses 127.0.0.1:8764"
