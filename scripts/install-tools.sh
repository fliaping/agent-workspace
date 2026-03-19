#!/bin/bash
# ============================================================
# install-tools.sh
# 开发工具安装脚本，支持国内/国外两种镜像源
# 参考 Dockerfile_zh（国内源）和 Dockerfile_en（国际源）
#
# 通过 USE_CHINA_MIRROR 环境变量控制（默认: false/国际源）
#   USE_CHINA_MIRROR=false ./install-tools.sh   # 国际源（默认）
#   USE_CHINA_MIRROR=true  ./install-tools.sh   # 国内源
# ============================================================

set -e

# ============================================================
# 全局配置
# ============================================================
USE_CHINA_MIRROR="${USE_CHINA_MIRROR:-false}"
GO_VERSION="${GO_VERSION:-go1.22.4}"
NODE_VERSION="${NODE_VERSION:-20}"
SYSTEM_LANG="${SYSTEM_LANG:-zh_CN}"

# 派生语言模式（与 install.sh 保持一致：cn/en）
case "$SYSTEM_LANG" in
    zh_CN*) LANG_MODE="cn" ;;
    *)      LANG_MODE="en" ;;
esac

# 检测系统架构
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
# 颜色输出
# ============================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============================================================
# 镜像源配置（国内 vs 国际）
# ============================================================
if [ "$USE_CHINA_MIRROR" = "true" ]; then
    info "模式: 国内镜像源"
    # Go: 阿里云镜像（参考 Dockerfile_zh）
    GO_DOWNLOAD_URL="https://mirrors.aliyun.com/golang/${GO_VERSION}.${GO_ARCH}.tar.gz"
    # Node.js: npmmirror（参考 Dockerfile_zh）
    NODE_INDEX_URL="https://npmmirror.com/mirrors/node/index.json"
    NODE_DIST_BASE="https://npmmirror.com/mirrors/node"
    # npm/pnpm 仓库
    NPM_REGISTRY="https://registry.npmmirror.com"
    # Python: 清华源（参考 Dockerfile_zh）
    PYPI_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    # GitHub 代理
    GITHUB_RAW_BASE="https://gh-proxy.org/https://raw.githubusercontent.com"
    # Rust: USTC rustup 镜像
    RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rustup"
    RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rustup/rustup"
    # Homebrew: USTC 安装脚本 + 镜像
    HOMEBREW_INSTALL_URL="https://mirrors.ustc.edu.cn/misc/brew-install.sh"
    HOMEBREW_BREW_GIT_REMOTE_VALUE="https://mirrors.ustc.edu.cn/brew.git"
    HOMEBREW_CORE_GIT_REMOTE_VALUE="https://mirrors.ustc.edu.cn/homebrew-core.git"
else
    info "模式: 国际镜像源"
    # Go: 官方（参考 Dockerfile_en）
    GO_DOWNLOAD_URL="https://go.dev/dl/${GO_VERSION}.${GO_ARCH}.tar.gz"
    # Node.js: 官方（参考 Dockerfile_en）
    NODE_INDEX_URL="https://nodejs.org/dist/index.json"
    NODE_DIST_BASE="https://nodejs.org/dist"
    # npm/pnpm 仓库
    NPM_REGISTRY="https://registry.npmjs.org"
    # Python: 官方 PyPI
    PYPI_INDEX_URL="https://pypi.org/simple"
    # GitHub 直连
    GITHUB_RAW_BASE="https://raw.githubusercontent.com"
    # Rust: 官方
    RUSTUP_DIST_SERVER=""
    RUSTUP_UPDATE_ROOT=""
    # Homebrew: 官方
    HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    HOMEBREW_BREW_GIT_REMOTE_VALUE=""
    HOMEBREW_CORE_GIT_REMOTE_VALUE=""
fi

info "USE_CHINA_MIRROR=${USE_CHINA_MIRROR}, GO_VERSION=${GO_VERSION}, NODE_VERSION=${NODE_VERSION}, ARCH=${ARCH}"

# ============================================================
# 安装 Node.js（tarball 方式，参考 Dockerfile_zh/en）
# ============================================================
install_nodejs() {
    info "安装 Node.js v${NODE_VERSION}.x ..."

    # 从 index.json 查找最新的 v${NODE_VERSION}.x LTS 版本
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

    [ -z "$node_ver" ] && error "无法获取 Node.js v${NODE_VERSION} 版本信息"

    local node_url="${NODE_DIST_BASE}/${node_ver}/node-${node_ver}-${NODE_ARCH}.tar.xz"
    info "下载 Node.js ${node_ver}: ${node_url}"
    curl -fsSL "${node_url}" | tar -xJ -C /usr/local --strip-components=1

    # 配置 npm 仓库（构建时加速）
    npm config set registry "${NPM_REGISTRY}" --global
    npm install -g pnpm pm2 typescript
    pnpm config set registry "${NPM_REGISTRY}"
    npm cache clean --force

    # 构建完成后重置为官方源，运行时由 setup-mirror.sh 按需配置
    npm config set registry "https://registry.npmjs.org" --global
    pnpm config set registry "https://registry.npmjs.org"

    success "Node.js ${node_ver} 安装完成"
}

# ============================================================
# 安装 Go（参考 Dockerfile_zh/en）
# ============================================================
install_go() {
    info "安装 Go ${GO_VERSION} (${GO_ARCH}) ..."
    info "下载地址: ${GO_DOWNLOAD_URL}"

    rm -rf /usr/local/go
    curl -fsSL "${GO_DOWNLOAD_URL}" | tar -xz -C /usr/local

    success "Go $(/usr/local/go/bin/go version 2>/dev/null || echo '(go installed)') 安装完成"
}

# ============================================================
# 安装 uv（Python 包管理器）
# ============================================================
install_uv() {
    info "安装 uv ..."

    if [ "$USE_CHINA_MIRROR" = "true" ]; then
        pip3 install --no-cache-dir uv --break-system-packages \
            --index-url "${PYPI_INDEX_URL}"
    else
        pip3 install --no-cache-dir uv --break-system-packages
    fi

    success "uv 安装完成"
}

# ============================================================
# 安装 Rust（stable 工具链，系统级安装到 /usr/local）
# ============================================================
install_rust() {
    info "安装 Rust (stable) ..."

    export RUSTUP_HOME=/usr/local/rustup
    export CARGO_HOME=/usr/local/cargo

    if [ -n "$RUSTUP_DIST_SERVER" ]; then
        export RUSTUP_DIST_SERVER
        export RUSTUP_UPDATE_ROOT
    fi

    curl -fsSL https://sh.rustup.rs | bash -s -- -y --default-toolchain stable --profile minimal --no-modify-path
    rm -rf /usr/local/rustup/toolchains/*/share/doc

    success "Rust $(/usr/local/cargo/bin/rustc --version 2>/dev/null || echo 'installed') 安装完成"
}

# ============================================================
# 安装 Homebrew（非 root 用户安装到 /home/linuxbrew/.linuxbrew）
# ============================================================
install_homebrew() {
    info "安装 Homebrew ..."

    mkdir -p /home/linuxbrew
    chown abc:abc /home/linuxbrew

    local brew_env="NONINTERACTIVE=1 HOME=/home/linuxbrew"
    if [ -n "$HOMEBREW_BREW_GIT_REMOTE_VALUE" ]; then
        brew_env="${brew_env} HOMEBREW_BREW_GIT_REMOTE=${HOMEBREW_BREW_GIT_REMOTE_VALUE}"
        brew_env="${brew_env} HOMEBREW_CORE_GIT_REMOTE=${HOMEBREW_CORE_GIT_REMOTE_VALUE}"
    fi

    su -s /bin/bash abc -c "${brew_env} /bin/bash -c \"\$(curl -fsSL ${HOMEBREW_INSTALL_URL})\""

    success "Homebrew $(/home/linuxbrew/.linuxbrew/bin/brew --version 2>/dev/null | head -1 || echo 'installed') 安装完成"
}

# ============================================================
# 安装 docker-systemctl-replacement
# ============================================================
install_systemctl_replacement() {
    info "安装 docker-systemctl-replacement ..."

    local base="${GITHUB_RAW_BASE}/gdraheim/docker-systemctl-replacement/master/files/docker"
    wget -q "${base}/systemctl3.py"  -O /usr/bin/systemctl
    wget -q "${base}/journalctl3.py" -O /usr/bin/journalctl
    chmod +x /usr/bin/systemctl /usr/bin/journalctl

    success "docker-systemctl-replacement 安装完成"
}

# ============================================================
# 配置系统语言 / Locale
# ============================================================
configure_locale() {
    if [ "$LANG_MODE" = "cn" ]; then
        info "配置中文语言环境 (${SYSTEM_LANG}) ..."
        sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
        locale-gen zh_CN.UTF-8
        update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8
        success "中文 locale 配置完成"
    else
        info "Configuring English locale (en_US.UTF-8) ..."
        sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        locale-gen en_US.UTF-8
        update-locale LANG=en_US.UTF-8
        success "English locale configured"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo "========================================"
    echo "  install-tools.sh"
    echo "  USE_CHINA_MIRROR=${USE_CHINA_MIRROR}"
    echo "  SYSTEM_LANG=${SYSTEM_LANG} (LANG_MODE=${LANG_MODE})"
    echo "========================================"

    configure_locale
    install_nodejs
    install_go
    install_rust
    install_uv
    install_homebrew
    install_systemctl_replacement

    echo "========================================"
    success "所有工具安装完成"
    echo "========================================"
}

main "$@"
