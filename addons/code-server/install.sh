#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${CONFIG_ROOT:-/config}"
CODE_SERVER_HOME="${CODE_SERVER_HOME:-${CONFIG_ROOT}/opt/code-server}"
CODE_SERVER_BIND="${CODE_SERVER_BIND:-0.0.0.0:8443}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"
CODE_SERVER_CERT="${CODE_SERVER_CERT:-true}"
CODE_SERVER_CONFIG="${CODE_SERVER_CONFIG:-${CONFIG_ROOT}/.config/code-server/config.yaml}"
CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-${PASSWORD:-}}"
CODE_SERVER_LOCALE="${CODE_SERVER_LOCALE:-en}"

if [[ "$CODE_SERVER_AUTH" != "password" && "$CODE_SERVER_AUTH" != "none" ]]; then
  echo "[code-server] CODE_SERVER_AUTH must be password or none" >&2
  exit 1
fi

if [[ "$CODE_SERVER_LOCALE" != "en" && "$CODE_SERVER_LOCALE" != "zh-cn" ]]; then
  echo "[code-server] CODE_SERVER_LOCALE must be en or zh-cn" >&2
  exit 1
fi

if [[ "$CODE_SERVER_AUTH" == "none" && "${CODE_SERVER_ALLOW_NO_AUTH:-false}" != "true" ]]; then
  echo "[code-server] refusing auth=none without CODE_SERVER_ALLOW_NO_AUTH=true" >&2
  echo "[code-server] use auth=none only behind a trusted authenticating gateway" >&2
  exit 1
fi

if [[ "$CODE_SERVER_AUTH" == "password" && -z "$CODE_SERVER_PASSWORD" ]]; then
  CODE_SERVER_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
  echo "[code-server] generated a password; read it from ${CODE_SERVER_CONFIG}" >&2
fi

install_runtime() {
  local installer
  installer="$(mktemp "${TMPDIR:-/tmp}/code-server-install.XXXXXX")"
  curl -fsSL https://code-server.dev/install.sh -o "$installer"
  local args=(--method=standalone --prefix="$CODE_SERVER_HOME")
  if [[ -n "${CODE_SERVER_VERSION:-}" ]]; then
    args+=(--version="$CODE_SERVER_VERSION")
  fi
  sh "$installer" "${args[@]}"
  rm -f -- "$installer"
}

write_config() {
  local config_dir
  config_dir="$(dirname "$CODE_SERVER_CONFIG")"
  mkdir -p "$config_dir"
  if [[ -f "$CODE_SERVER_CONFIG" && "${CODE_SERVER_RECONFIGURE:-false}" != "true" ]]; then
    echo "[code-server] preserving existing config: ${CODE_SERVER_CONFIG}"
    return
  fi

  umask 077
  {
    printf 'bind-addr: %s\n' "$CODE_SERVER_BIND"
    printf 'auth: %s\n' "$CODE_SERVER_AUTH"
    if [[ "$CODE_SERVER_AUTH" == "password" ]]; then
      printf 'password: '
      python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$CODE_SERVER_PASSWORD"
    fi
    printf 'cert: %s\n' "$CODE_SERVER_CERT"
    printf 'locale: %s\n' "$CODE_SERVER_LOCALE"
    if [[ -n "${CODE_SERVER_PROXY_DOMAIN:-}" ]]; then
      printf 'proxy-domain: %s\n' "$CODE_SERVER_PROXY_DOMAIN"
    fi
  } >"$CODE_SERVER_CONFIG"
}

install_service() {
  local unit_dir wants_dir
  unit_dir="${CONFIG_ROOT}/.config/systemd/user"
  wants_dir="${unit_dir}/default.target.wants"
  mkdir -p "$CODE_SERVER_HOME" "$unit_dir" "$wants_dir"
  install -m 0755 "$PACKAGE_ROOT/bin/run-code-server" "$CODE_SERVER_HOME/run-code-server"
  install -m 0644 "$PACKAGE_ROOT/systemd/user/code-server.service" "$unit_dir/code-server.service"
  ln -sfn "$unit_dir/code-server.service" "$wants_dir/code-server.service"
  if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
    chown -R abc:abc "$CODE_SERVER_HOME" "$(dirname "$CODE_SERVER_CONFIG")"
    chown abc:abc "$unit_dir/code-server.service"
    chown -h abc:abc "$wants_dir/code-server.service"
  fi
}

start_service() {
  if [[ "$(id -u)" == "0" ]] && command -v s6-setuidgid >/dev/null 2>&1; then
    s6-setuidgid abc systemctl --user daemon-reload || true
    s6-setuidgid abc systemctl --user restart code-server.service
  else
    systemctl --user daemon-reload || true
    systemctl --user restart code-server.service
  fi
}

install_runtime
write_config
install_service
start_service

echo "[code-server] installed at ${CODE_SERVER_HOME}"
echo "[code-server] listening on ${CODE_SERVER_BIND} with auth=${CODE_SERVER_AUTH}, cert=${CODE_SERVER_CERT}"
