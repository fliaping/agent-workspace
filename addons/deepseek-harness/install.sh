#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${CONFIG_ROOT:-/config}"
NODE_ROOT="${NODE_ROOT:-${CONFIG_ROOT}/node}"
NPM_BIN="${NPM_BIN:-${NODE_ROOT}/bin/npm}"
NPM_PREFIX="${DEEPSEEK_HARNESS_NPM_PREFIX:-${CONFIG_ROOT}/.npm-global}"
INSTALL_ROOT="${DEEPSEEK_HARNESS_HOME:-${CONFIG_ROOT}/opt/deepseek-harness}"
PACKAGE_SPEC="${DEEPSEEK_HARNESS_PACKAGE:-@deepseek-ai/dsh@latest}"
ALLOW_SCRIPTS="${DEEPSEEK_HARNESS_ALLOW_SCRIPTS:-@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs}"

if [[ ! -x "$NPM_BIN" ]]; then
  NPM_BIN="$(command -v npm || true)"
fi
if [[ -z "$NPM_BIN" || ! -x "$NPM_BIN" ]]; then
  echo "[deepseek-harness] persistent Node/npm runtime is required" >&2
  exit 1
fi

mkdir -p "$NPM_PREFIX" "$INSTALL_ROOT/bin" "$INSTALL_ROOT/lib" "${CONFIG_ROOT}/bin" "${CONFIG_ROOT}/.local/bin" "${CONFIG_ROOT}/.dsh"
npm_major="$($NPM_BIN --version | cut -d. -f1)"
npm_args=(install --global --prefix "$NPM_PREFIX")
if [[ "$npm_major" =~ ^[0-9]+$ ]] && (( npm_major >= 11 )); then
  # npm 11+ blocks dependency lifecycle scripts unless they are explicitly
  # allowed. Harness uses these packages for its local subprocess/PTY layer.
  npm_args+=("--allow-scripts=${ALLOW_SCRIPTS}")
fi
"$NPM_BIN" "${npm_args[@]}" "$PACKAGE_SPEC"

if [[ ! -x "$NPM_PREFIX/bin/dsh" ]]; then
  echo "[deepseek-harness] npm completed but dsh was not found" >&2
  exit 1
fi

install -m 0755 "$PACKAGE_ROOT/bin/deepseek-harness" "$INSTALL_ROOT/bin/deepseek-harness"
install -m 0755 "$PACKAGE_ROOT/lib/deepseek-harness-web-proxy.mjs" "$INSTALL_ROOT/lib/deepseek-harness-web-proxy.mjs"
ln -sfn "$INSTALL_ROOT/bin/deepseek-harness" "${CONFIG_ROOT}/bin/deepseek-harness"
ln -sfn "${CONFIG_ROOT}/bin/deepseek-harness" "${CONFIG_ROOT}/.local/bin/deepseek-harness"

if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
  chown -R abc:abc "$INSTALL_ROOT" "${CONFIG_ROOT}/.dsh"
  chown -h abc:abc "${CONFIG_ROOT}/bin/deepseek-harness" "${CONFIG_ROOT}/.local/bin/deepseek-harness"
fi

version="$($NPM_PREFIX/bin/dsh --version | head -n 1)"
echo "[deepseek-harness] installed official @deepseek-ai/dsh ${version}"
echo "[deepseek-harness] launch: deepseek-harness web --no-open --port 3080"
