#!/usr/bin/env bash
set -euo pipefail

ROOT_DOMAIN="${PROXY_ROOT_DOMAIN:-ping-dev.h1.fliaping.com}"
INSTALL_ROOT="${INSTALL_ROOT:-/config/proxyctl}"
PACKAGE_DIR="${PACKAGE_DIR:-$INSTALL_ROOT/package}"
CADDY_VERSION="${CADDY_VERSION:-v2.11.3}"
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-v4.122.0}"
BIN_DIR="$INSTALL_ROOT/bin"

require_root() {
  if [[ "$(id -u)" != "0" ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

github_latest() {
  local repo="$1"
  curl -fsSL -A proxyctl-installer "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name'
}

asset_url() {
  local repo="$1"
  local pattern="$2"
  curl -fsSL -A proxyctl-installer "https://api.github.com/repos/$repo/releases/latest" \
    | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' \
    | head -n 1
}

install_caddy() {
  local tag version url tmp
  tag="$CADDY_VERSION"
  version="${tag#v}"
  url="https://github.com/caddyserver/caddy/releases/download/$tag/caddy_${version}_linux_amd64.tar.gz"
  tmp="$(mktemp -d)"
  curl -fL -A proxyctl-installer "$url" -o "$tmp/caddy.tar.gz"
  tar -xzf "$tmp/caddy.tar.gz" -C "$tmp" caddy
  mkdir -p "$BIN_DIR"
  install -m 0755 "$tmp/caddy" "$BIN_DIR/caddy"
  ln -sfn "$BIN_DIR/caddy" /usr/local/bin/caddy
  rm -rf "$tmp"
}

install_code_server() {
  local tag version url tmp target
  tag="$CODE_SERVER_VERSION"
  version="${tag#v}"
  url="https://github.com/coder/code-server/releases/download/$tag/code-server-${version}-linux-amd64.tar.gz"
  tmp="$(mktemp -d)"
  curl -fL -A proxyctl-installer "$url" -o "$tmp/code-server.tar.gz"
  tar -xzf "$tmp/code-server.tar.gz" -C "$tmp"
  target="$INSTALL_ROOT/code-server-$version"
  rm -rf "$target"
  mv "$tmp/code-server-$version-linux-amd64" "$target"
  mkdir -p "$BIN_DIR"
  ln -sfn "$target/bin/code-server" "$BIN_DIR/code-server"
  ln -sfn "$BIN_DIR/code-server" /usr/local/bin/code-server
  rm -rf "$tmp"
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
  chmod +x "$PACKAGE_DIR/bin/proxyctl" "$PACKAGE_DIR/install.sh"
  mkdir -p "$BIN_DIR"
  cp "$PACKAGE_DIR/bin/proxyctl" "$BIN_DIR/proxyctl"
  cp "$PACKAGE_DIR/bin/run-code-server" "$BIN_DIR/run-code-server"
  cp "$PACKAGE_DIR/bin/run-caddy" "$BIN_DIR/run-caddy"
  chmod +x "$BIN_DIR/proxyctl" "$BIN_DIR/run-code-server" "$BIN_DIR/run-caddy"
}

install_services() {
  mkdir -p "$INSTALL_ROOT"
  cp "$PACKAGE_DIR/caddy/bootstrap.json" "$INSTALL_ROOT/bootstrap.json"
  mkdir -p /config/.config/systemd/user/default.target.wants
  cp "$PACKAGE_DIR/systemd/user/proxy-caddy.service" /config/.config/systemd/user/proxy-caddy.service
  cp "$PACKAGE_DIR/systemd/user/code-server.service" /config/.config/systemd/user/code-server.service
  ln -sfn /config/.config/systemd/user/proxy-caddy.service /config/.config/systemd/user/default.target.wants/proxy-caddy.service
  ln -sfn /config/.config/systemd/user/code-server.service /config/.config/systemd/user/default.target.wants/code-server.service
  chown -R abc:abc /config/.config/systemd "$INSTALL_ROOT"
  ln -sfn "$BIN_DIR/proxyctl" /usr/local/bin/proxyctl
}

write_env() {
  cat >/etc/profile.d/proxyctl.sh <<EOF
export PROXY_ROOT_DOMAIN="$ROOT_DOMAIN"
export CODE_SERVER_TARGET="127.0.0.1:8443"
export CODE_SERVER_SUBDOMAIN="code"
export CADDY_ADMIN="http://127.0.0.1:2019"
export PROXY_LISTEN=":80"
EOF
  cat >"$INSTALL_ROOT/env" <<EOF
PROXY_ROOT_DOMAIN="$ROOT_DOMAIN"
CODE_SERVER_TARGET="127.0.0.1:8443"
CODE_SERVER_SUBDOMAIN="code"
CADDY_ADMIN="http://127.0.0.1:2019"
PROXY_LISTEN=":80"
EOF
}

start_services() {
  s6-setuidgid abc systemctl --user daemon-reload || true
  s6-setuidgid abc systemctl --user restart proxy-caddy.service
  s6-setuidgid abc systemctl --user restart code-server.service
}

initialize_proxy() {
  set -a
  . "$INSTALL_ROOT/env"
  set +a
  for _ in $(seq 1 30); do
    if curl -fsS "$CADDY_ADMIN/config/" >/dev/null 2>&1; then
      proxyctl init
      return
    fi
    sleep 1
  done
  echo "Caddy Admin API did not become ready at $CADDY_ADMIN" >&2
  return 1
}

main() {
  require_root "$@"
  command -v curl >/dev/null
  command -v jq >/dev/null
  command -v tar >/dev/null
  install_package
  install_caddy
  install_code_server
  install_services
  write_env
  start_services
  initialize_proxy
  echo "installed proxyctl for *.$ROOT_DOMAIN"
  echo "code-server password: $(cat "$INSTALL_ROOT/code-server-password")"
}

main "$@"
