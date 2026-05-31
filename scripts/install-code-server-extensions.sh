#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_DIR="${CODE_SERVER_EXTENSIONS_DIR:-/config/.local/share/code-server/extensions}"

install_extension() {
    local name="$1"
    local source="${PACKAGE_ROOT}/extensions/${name}"
    local package_name
    local publisher
    local version
    local target

    if [[ ! -f "${source}/package.json" ]]; then
        echo "[extensions] missing package.json: ${source}" >&2
        return 1
    fi

    package_name="$(node -e "process.stdout.write(require('${source}/package.json').name)")"
    publisher="$(node -e "process.stdout.write(require('${source}/package.json').publisher || 'agent-workspace')")"
    version="$(node -e "process.stdout.write(require('${source}/package.json').version)")"
    target="${EXTENSIONS_DIR}/${publisher}.${package_name}-${version}"

    mkdir -p "${EXTENSIONS_DIR}"
    rm -rf "${target}"
    ln -s "${source}" "${target}"
    echo "[extensions] installed ${name} -> ${target}"
}

install_extension "service-manager"
install_extension "caddy-proxy-manager"
