#!/usr/bin/env bash
set -euo pipefail

ROOT_DOMAIN="${PROXY_ROOT_DOMAIN:-}"
INSTALL_ROOT="${INSTALL_ROOT:-/config/proxyctl}"
PACKAGE_DIR="${PACKAGE_DIR:-$INSTALL_ROOT/package}"
CADDY_VERSION="${CADDY_VERSION:-v2.11.3}"
BIN_DIR="$INSTALL_ROOT/bin"

install_caddy() {
  local tag version arch url tmp
  tag="$CADDY_VERSION"
  version="${tag#v}"
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "unsupported Caddy architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  url="https://github.com/caddyserver/caddy/releases/download/$tag/caddy_${version}_linux_${arch}.tar.gz"
  tmp="$(mktemp -d)"
  curl -fL -A proxyctl-installer "$url" -o "$tmp/caddy.tar.gz"
  tar -xzf "$tmp/caddy.tar.gz" -C "$tmp" caddy
  mkdir -p "$BIN_DIR"
  install -m 0755 "$tmp/caddy" "$BIN_DIR/caddy"
  rm -rf -- "$tmp"
}

install_package() {
  mkdir -p "$PACKAGE_DIR"
  find "$PACKAGE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  tar \
    --exclude './.git' \
    --exclude './.codex' \
    --exclude './.agents' \
    --exclude './__pycache__' \
    --exclude './*/__pycache__' \
    -cf - . | tar -xf - -C "$PACKAGE_DIR"
  chmod +x "$PACKAGE_DIR/bin/run-caddy" "$PACKAGE_DIR/install.sh"
  mkdir -p "$BIN_DIR"
  cp "$PACKAGE_DIR/bin/run-caddy" "$BIN_DIR/run-caddy"
  chmod +x "$BIN_DIR/run-caddy"
}

install_services() {
  mkdir -p "$INSTALL_ROOT"
  cp "$PACKAGE_DIR/caddy/bootstrap.json" "$INSTALL_ROOT/bootstrap.json"
  mkdir -p /config/.config/systemd/user/default.target.wants
  cp "$PACKAGE_DIR/systemd/user/proxy-caddy.service" /config/.config/systemd/user/proxy-caddy.service
  ln -sfn /config/.config/systemd/user/proxy-caddy.service /config/.config/systemd/user/default.target.wants/proxy-caddy.service
}

write_env() {
  if [[ -f "$INSTALL_ROOT/env" && "${PROXY_RECONFIGURE:-false}" != "true" ]]; then
    echo "[routing] preserving existing config: $INSTALL_ROOT/env"
    return
  fi
  cat >"$INSTALL_ROOT/env" <<EOF
PROXY_ROOT_DOMAIN="$ROOT_DOMAIN"
PROXY_HOST_PREFIXES="${PROXY_HOST_PREFIXES:-}"
PROXY_PORT_ROUTING="${PROXY_PORT_ROUTING:-code-server}"
CODE_SERVER_TARGET="127.0.0.1:8443"
CODE_SERVER_SUBDOMAIN="code"
CODE_SERVER_PROXY_DOMAIN="${CODE_SERVER_PROXY_DOMAIN:-}"
CADDY_ADMIN="http://127.0.0.1:2019"
PROXY_LISTEN=":80"
EOF
}

fix_ownership() {
  if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
    chown -R abc:abc "$INSTALL_ROOT"
    chown abc:abc /config/.config/systemd/user/proxy-caddy.service
    chown -h abc:abc /config/.config/systemd/user/default.target.wants/proxy-caddy.service
  fi
}

start_services() {
  if [[ "$(id -u)" == "0" ]] && command -v s6-setuidgid >/dev/null 2>&1; then
    s6-setuidgid abc systemctl --user daemon-reload || true
    s6-setuidgid abc systemctl --user restart proxy-caddy.service
  else
    systemctl --user daemon-reload || true
    systemctl --user restart proxy-caddy.service
  fi
}

initialize_proxy() {
  local workspace_ctl
  set -a
  . "$INSTALL_ROOT/env"
  set +a
  workspace_ctl="$(command -v workspacectl 2>/dev/null || true)"
  if [[ -z "$workspace_ctl" && -x /config/bin/workspacectl ]]; then
    workspace_ctl=/config/bin/workspacectl
  fi
  if [[ -z "$workspace_ctl" ]]; then
    echo "workspacectl is required to initialize custom-domain routing" >&2
    return 1
  fi
  for _ in $(seq 1 30); do
    if curl -fsS "$CADDY_ADMIN/config/" >/dev/null 2>&1; then
      "$workspace_ctl" proxy init
      return
    fi
    sleep 1
  done
  echo "Caddy Admin API did not become ready at $CADDY_ADMIN" >&2
  return 1
}

main() {
  if [[ -z "$ROOT_DOMAIN" ]]; then
    echo "PROXY_ROOT_DOMAIN is required (for example: dev.example.com)" >&2
    exit 1
  fi
  command -v curl >/dev/null
  command -v jq >/dev/null
  command -v tar >/dev/null
  if grep -Eq '^[[:space:]]*cert:[[:space:]]*true' /config/.config/code-server/config.yaml 2>/dev/null; then
    echo "code-server uses TLS, but custom-domain routing expects a loopback HTTP upstream" >&2
    echo "reinstall it with CODE_SERVER_CERT=false CODE_SERVER_RECONFIGURE=true" >&2
    exit 1
  fi
  install_package
  install_caddy
  install_services
  write_env
  fix_ownership
  start_services
  initialize_proxy
  echo "installed custom-domain routing for *.$ROOT_DOMAIN"
}

main "$@"
