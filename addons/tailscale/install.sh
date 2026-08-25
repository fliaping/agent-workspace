#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${CONFIG_ROOT:-/config}"
INSTALL_ROOT="${TAILSCALE_HOME:-${CONFIG_ROOT}/opt/tailscale}"
STATE_DIR="${TAILSCALE_STATE_DIR:-${CONFIG_ROOT}/.local/share/tailscale}"
RUNTIME_DIR="${TAILSCALE_RUNTIME_DIR:-${CONFIG_ROOT}/.local/run/tailscale}"
PACKAGE_BASE_URL="${TAILSCALE_PACKAGE_BASE_URL:-https://pkgs.tailscale.com/stable}"

architecture() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo "unsupported Tailscale architecture: $(uname -m)" >&2; return 1 ;;
  esac
}

latest_version() {
  if [[ -n "${TAILSCALE_VERSION:-}" ]]; then
    printf '%s\n' "${TAILSCALE_VERSION#v}"
    return
  fi
  curl -fsSL "${PACKAGE_BASE_URL}/" \
    | sed -n "s/.*tailscale_\([0-9][0-9.]*\)_$(architecture)\.tgz.*/\1/p" \
    | head -n 1
}

install_runtime() (
  local arch version archive_url temporary extracted expected
  arch="$(architecture)"
  version="$(latest_version)"
  if [[ -z "$version" || ! "$version" =~ ^[0-9]+([.][0-9]+)+$ ]]; then
    echo "could not determine a stable Tailscale version" >&2
    return 1
  fi
  archive_url="${PACKAGE_BASE_URL}/tailscale_${version}_${arch}.tgz"
  temporary="$(mktemp -d "${TMPDIR:-/tmp}/agent-workspace-tailscale.XXXXXX")"
  trap 'rm -rf -- "$temporary"' EXIT
  curl -fL "$archive_url" -o "$temporary/tailscale.tgz"
  expected="$(curl -fsSL "${archive_url}.sha256" | awk 'NR == 1 {print $1}')"
  if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "invalid Tailscale checksum response" >&2
    return 1
  fi
  printf '%s  %s\n' "$expected" "$temporary/tailscale.tgz" | sha256sum -c -
  tar -xzf "$temporary/tailscale.tgz" -C "$temporary"
  extracted="$(find "$temporary" -mindepth 1 -maxdepth 1 -type d -name "tailscale_*_${arch}" | head -n 1)"
  if [[ -z "$extracted" || ! -x "$extracted/tailscale" || ! -x "$extracted/tailscaled" ]]; then
    echo "Tailscale archive did not contain expected binaries" >&2
    return 1
  fi
  mkdir -p "$INSTALL_ROOT/libexec"
  install -m 0755 "$extracted/tailscale" "$INSTALL_ROOT/libexec/tailscale"
  install -m 0755 "$extracted/tailscaled" "$INSTALL_ROOT/libexec/tailscaled"
  printf '%s\n' "$version" >"$INSTALL_ROOT/VERSION"
)

install_service() {
  local unit_dir wants_dir
  unit_dir="${CONFIG_ROOT}/.config/systemd/user"
  wants_dir="${unit_dir}/default.target.wants"
  mkdir -p "$INSTALL_ROOT" "$STATE_DIR" "$RUNTIME_DIR" "$unit_dir" "$wants_dir" "${CONFIG_ROOT}/bin" "${CONFIG_ROOT}/.local/bin"
  install -m 0755 "$PACKAGE_ROOT/bin/tailscale" "$INSTALL_ROOT/bin-tailscale"
  install -m 0755 "$PACKAGE_ROOT/bin/run-tailscaled" "$INSTALL_ROOT/run-tailscaled"
  install -m 0644 "$PACKAGE_ROOT/systemd/user/tailscaled-workspace.service" "$unit_dir/tailscaled-workspace.service"
  ln -sfn "$unit_dir/tailscaled-workspace.service" "$wants_dir/tailscaled-workspace.service"
  ln -sfn "$INSTALL_ROOT/bin-tailscale" "${CONFIG_ROOT}/bin/tailscale"
  ln -sfn "${CONFIG_ROOT}/bin/tailscale" "${CONFIG_ROOT}/.local/bin/tailscale"
  chmod 700 "$STATE_DIR" "$RUNTIME_DIR"
  if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
    chown -R abc:abc "$INSTALL_ROOT" "$STATE_DIR" "$RUNTIME_DIR"
    chown abc:abc "$unit_dir/tailscaled-workspace.service"
    chown -h abc:abc "$wants_dir/tailscaled-workspace.service" "${CONFIG_ROOT}/bin/tailscale" "${CONFIG_ROOT}/.local/bin/tailscale"
  fi
}

start_service() {
  if [[ "$(id -u)" == "0" ]] && command -v s6-setuidgid >/dev/null 2>&1; then
    s6-setuidgid abc systemctl --user daemon-reload || true
    s6-setuidgid abc systemctl --user enable --now tailscaled-workspace.service
  else
    systemctl --user daemon-reload || true
    systemctl --user enable --now tailscaled-workspace.service
  fi
}

command -v curl >/dev/null
command -v sha256sum >/dev/null
command -v tar >/dev/null
install_runtime
install_service
start_service

echo "[tailscale] installed $(cat "$INSTALL_ROOT/VERSION") in userspace mode"
echo "[tailscale] next: tailscale up --hostname=agent-workspace --accept-dns=false"
