#!/bin/bash
# 运行时国内镜像源配置脚本
# 由 services/init/run 在 USE_CHINA_MIRROR=true 时调用
# 配置: APT / npm / pip / Go / Rust / Homebrew / uv

if [ "$USE_CHINA_MIRROR" != "true" ]; then
    echo "[setup-mirror] Using default mirrors"
    exit 0
fi

echo "[setup-mirror] Configuring China mirrors..."

# ==========================================
# APT 源（USTC）
# ==========================================
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
cat > /etc/apt/sources.list << EOF
deb https://mirrors.ustc.edu.cn/ubuntu/ ${CODENAME} main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF
echo "[setup-mirror] APT → USTC"

# ==========================================
# npm + pnpm（npmmirror）
# ==========================================
if command -v npm > /dev/null 2>&1; then
    npm config set registry https://registry.npmmirror.com --global
    echo "[setup-mirror] npm → npmmirror"
fi
if command -v pnpm > /dev/null 2>&1; then
    pnpm config set registry https://registry.npmmirror.com
    echo "[setup-mirror] pnpm → npmmirror"
fi

# ==========================================
# pip（清华源）
# ==========================================
mkdir -p /etc/pip
cat > /etc/pip/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
EOF
echo "[setup-mirror] pip → tsinghua"

# ==========================================
# 环境变量镜像（Go / uv / Homebrew / Rust）
# 写入 /etc/profile.d/ 对所有登录 shell 生效
# ==========================================
cat > /etc/profile.d/mirrors.sh << 'EOF'
# 国内镜像源（由 setup-mirror.sh 生成）
# Go
export GOPROXY="https://goproxy.cn,direct"
# uv / pip
export UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
# Homebrew
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
export HOMEBREW_CURL_RETRIES=3
# Rust
export RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rustup"
export RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rustup/rustup"
EOF
chmod +x /etc/profile.d/mirrors.sh
echo "[setup-mirror] Go/uv/Homebrew/Rust → USTC/tsinghua/goproxy"

# ==========================================
# Rust cargo 源（crates.io 镜像）
# ==========================================
CARGO_CONFIG_DIR="${CARGO_HOME:-/config/.cargo}"
mkdir -p "$CARGO_CONFIG_DIR"
cat > "$CARGO_CONFIG_DIR/config.toml" << 'EOF'
[source.crates-io]
replace-with = "ustc"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF
echo "[setup-mirror] cargo registry → USTC"

echo "[setup-mirror] All China mirrors configured"
