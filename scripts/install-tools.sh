#!/bin/bash
# ============================================================
# install-tools.sh
# Dev tools installer with China/international mirror support
#
# USE_CHINA_MIRROR controls mirror selection (default: false)
#   USE_CHINA_MIRROR=false ./install-tools.sh   # international
#   USE_CHINA_MIRROR=true  ./install-tools.sh   # China mirrors
# ============================================================

set -e

# ============================================================
# Global config
# ============================================================
USE_CHINA_MIRROR="${USE_CHINA_MIRROR:-false}"
GO_VERSION="${GO_VERSION:-go1.22.4}"
NODE_VERSION="${NODE_VERSION:-22}"

# Detect system architecture
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
    amd64|x86_64)
        GO_ARCH="linux-amd64"
        NODE_ARCH="linux-x64"
        ;;
    arm64|aarch64)
        GO_ARCH="linux-arm64"
        NODE_ARCH="linux-arm64"
        ;;
    *)
        echo "[ERROR] Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# ============================================================
# Colored output
# ============================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============================================================
# Mirror configuration (China vs international)
# ============================================================
if [ "$USE_CHINA_MIRROR" = "true" ]; then
    info "Mode: China mirrors"
    GO_DOWNLOAD_URL="https://mirrors.aliyun.com/golang/${GO_VERSION}.${GO_ARCH}.tar.gz"
    NODE_INDEX_URL="https://npmmirror.com/mirrors/node/index.json"
    NODE_DIST_BASE="https://npmmirror.com/mirrors/node"
    NPM_REGISTRY="https://registry.npmmirror.com"
    PYPI_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    GITHUB_RAW_BASE="https://gh-proxy.org/https://raw.githubusercontent.com"
    RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rustup"
    RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rustup/rustup"
    HOMEBREW_INSTALL_URL="https://mirrors.ustc.edu.cn/misc/brew-install.sh"
    HOMEBREW_BREW_GIT_REMOTE_VALUE="https://mirrors.ustc.edu.cn/brew.git"
    HOMEBREW_CORE_GIT_REMOTE_VALUE="https://mirrors.ustc.edu.cn/homebrew-core.git"
else
    info "Mode: International mirrors"
    GO_DOWNLOAD_URL="https://go.dev/dl/${GO_VERSION}.${GO_ARCH}.tar.gz"
    NODE_INDEX_URL="https://nodejs.org/dist/index.json"
    NODE_DIST_BASE="https://nodejs.org/dist"
    NPM_REGISTRY="https://registry.npmjs.org"
    PYPI_INDEX_URL="https://pypi.org/simple"
    GITHUB_RAW_BASE="https://raw.githubusercontent.com"
    RUSTUP_DIST_SERVER=""
    RUSTUP_UPDATE_ROOT=""
    HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    HOMEBREW_BREW_GIT_REMOTE_VALUE=""
    HOMEBREW_CORE_GIT_REMOTE_VALUE=""
fi

info "USE_CHINA_MIRROR=${USE_CHINA_MIRROR}, GO_VERSION=${GO_VERSION}, NODE_VERSION=${NODE_VERSION}, ARCH=${ARCH}"

# ============================================================
# Install Node.js (tarball)
# ============================================================
install_nodejs() {
    info "Installing Node.js v${NODE_VERSION}.x ..."

    local node_ver
    node_ver=$(curl -fsSL "${NODE_INDEX_URL}" | \
        python3 -c "
import sys, json
data = json.load(sys.stdin)
vers = [d['version'] for d in data
        if d['version'].startswith('v${NODE_VERSION}.')
        and (d.get('lts') or True)]
print(vers[0] if vers else '')
" 2>/dev/null)

    [ -z "$node_ver" ] && error "Failed to get Node.js v${NODE_VERSION} version info"

    local node_url="${NODE_DIST_BASE}/${node_ver}/node-${node_ver}-${NODE_ARCH}.tar.xz"
    info "Downloading Node.js ${node_ver}: ${node_url}"
    curl -fsSL "${node_url}" | tar -xJ -C /usr/local --strip-components=1

    # Use mirror registry during build for speed
    npm config set registry "${NPM_REGISTRY}" --global
    npm install -g pnpm typescript
    pnpm config set registry "${NPM_REGISTRY}"
    npm cache clean --force

    # Reset to official registry; runtime config via setup-mirror.sh
    npm config set registry "https://registry.npmjs.org" --global
    pnpm config set registry "https://registry.npmjs.org"

    success "Node.js ${node_ver} installed"
}

# ============================================================
# Install Go
# ============================================================
install_go() {
    info "Installing Go ${GO_VERSION} (${GO_ARCH}) ..."
    info "URL: ${GO_DOWNLOAD_URL}"

    rm -rf /usr/local/go
    curl -fsSL "${GO_DOWNLOAD_URL}" | tar -xz -C /usr/local

    success "Go $(/usr/local/go/bin/go version 2>/dev/null || echo 'installed')"
}

# ============================================================
# Install uv (Python package manager)
# ============================================================
install_uv() {
    info "Installing uv ..."

    if [ "$USE_CHINA_MIRROR" = "true" ]; then
        pip3 install --no-cache-dir uv textual --break-system-packages \
            --index-url "${PYPI_INDEX_URL}"
    else
        pip3 install --no-cache-dir uv textual --break-system-packages
    fi

    success "uv installed"
}

# ============================================================
# Install Rust (stable toolchain to /usr/local)
# ============================================================
install_rust() {
    info "Installing Rust (stable) ..."

    export RUSTUP_HOME=/usr/local/rustup
    export CARGO_HOME=/usr/local/cargo

    if [ -n "$RUSTUP_DIST_SERVER" ]; then
        export RUSTUP_DIST_SERVER
        export RUSTUP_UPDATE_ROOT
    fi

    curl -fsSL https://sh.rustup.rs | bash -s -- -y --default-toolchain stable --profile minimal --no-modify-path
    rm -rf /usr/local/rustup/toolchains/*/share/doc

    success "Rust $(/usr/local/cargo/bin/rustc --version 2>/dev/null || echo 'installed')"
}

# ============================================================
# Install Homebrew (as abc user to /home/linuxbrew/.linuxbrew)
# ============================================================
install_homebrew() {
    info "Installing Homebrew ..."

    mkdir -p /home/linuxbrew
    chown abc:abc /home/linuxbrew

    local brew_env="NONINTERACTIVE=1 HOME=/home/linuxbrew"
    if [ -n "$HOMEBREW_BREW_GIT_REMOTE_VALUE" ]; then
        brew_env="${brew_env} HOMEBREW_BREW_GIT_REMOTE=${HOMEBREW_BREW_GIT_REMOTE_VALUE}"
        brew_env="${brew_env} HOMEBREW_CORE_GIT_REMOTE=${HOMEBREW_CORE_GIT_REMOTE_VALUE}"
    fi

    su -s /bin/bash abc -c "${brew_env} /bin/bash -c \"\$(curl -fsSL ${HOMEBREW_INSTALL_URL})\""

    success "Homebrew $(/home/linuxbrew/.linuxbrew/bin/brew --version 2>/dev/null | head -1 || echo 'installed')"
}

# ============================================================
# Install docker-systemctl-replacement
# ============================================================
install_systemctl_replacement() {
    info "Installing docker-systemctl-replacement ..."

    local base="${GITHUB_RAW_BASE}/gdraheim/docker-systemctl-replacement/master/files/docker"
    wget -q "${base}/systemctl3.py"  -O /usr/bin/systemctl
    wget -q "${base}/journalctl3.py" -O /usr/bin/journalctl
    chmod +x /usr/bin/systemctl /usr/bin/journalctl

    success "docker-systemctl-replacement installed"
}

# ============================================================
# Generate locales (both en_US and zh_CN available at runtime)
# Runtime language is controlled by LC_ALL env var
# ============================================================
configure_locale() {
    info "Generating locales (en_US.UTF-8, zh_CN.UTF-8) ..."
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    update-locale LANG=en_US.UTF-8
    success "Locales generated (default: en_US.UTF-8, set LC_ALL to switch)"
}

# ============================================================
# Main
# ============================================================
main() {
    echo "========================================"
    echo "  install-tools.sh"
    echo "  USE_CHINA_MIRROR=${USE_CHINA_MIRROR}"
    echo "========================================"

    configure_locale
    install_nodejs
    install_go
    install_rust
    install_uv
    install_homebrew
    install_systemctl_replacement

    echo "========================================"
    success "All tools installed"
    echo "========================================"
}

main "$@"
