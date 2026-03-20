# LinuxServer Webtop + DinD + GPU 加速 + 完整开发环境
#
# 构建参数:
#   DESKTOP=lxqt (默认) | xfce | kde    — 桌面环境 (内存: lxqt 300M / xfce 800M / kde 1.1G)
#   USE_CHINA_MIRROR=false (默认，国际源) | true (国内源)
#
# 示例:
#   docker compose build                                          # lxqt + 国际源
#   docker compose build --build-arg DESKTOP=kde                 # KDE 桌面
#   docker compose build --build-arg USE_CHINA_MIRROR=true       # 国内源

ARG DESKTOP=lxqt
FROM linuxserver/webtop:ubuntu-${DESKTOP}

USER root

# ==========================================
# 构建参数（必须在 ENV 之前声明）
# ==========================================
# USE_CHINA_MIRROR: 控制安装脚本使用国内还是国际镜像源（默认国际）
ARG USE_CHINA_MIRROR=false

# ==========================================
# 环境变量配置
# ==========================================

# 构建时传入的变量（运行时由 docker-compose 设置）
ENV USE_CHINA_MIRROR=${USE_CHINA_MIRROR}

# 强制 X11 模式（Wayland 模式下 Selkies 的 CJK 输入链路有问题）
ENV PIXELFLUX_WAYLAND=false

# 工具版本
ENV GO_VERSION="go1.22.4"
ENV NODE_VERSION="22"

# 工具路径（指向 /config，LinuxServer 持久化目录）
ENV HOME=/config
ENV GOROOT=/usr/local/go
ENV GOPATH=/config/go
ENV CARGO_HOME=/config/.cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV NPM_CONFIG_PREFIX=/config/.npm-global
ENV PIP_CACHE_DIR=/config/.cache/pip
ENV UV_CACHE_DIR=/config/.cache/uv

# PATH（运行时路径，与镜像源无关）
ENV PATH=$GOPATH/bin:$CARGO_HOME/bin:/usr/local/cargo/bin:$GOROOT/bin:$NPM_CONFIG_PREFIX/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH

# Homebrew 基础配置（镜像源地址由 install-tools.sh 写入 /etc/profile.d/mirrors.sh）
ENV HOMEBREW_NO_AUTO_UPDATE=1

# ==========================================
# 安装系统依赖
# ==========================================

# 国内模式切换 APT 源（USTC 镜像，加速 apt-get）
# LinuxServer 镜像使用旧式 /etc/apt/sources.list，ARM64 源为 ports.ubuntu.com
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
        sed -i 's@http://ports.ubuntu.com/ubuntu-ports@https://mirrors.ustc.edu.cn/ubuntu-ports@g' \
            /etc/apt/sources.list 2>/dev/null || true; \
        sed -i 's@http://archive.ubuntu.com/ubuntu@https://mirrors.ustc.edu.cn/ubuntu@g' \
            /etc/apt/sources.list 2>/dev/null || true; \
        sed -i 's@http://security.ubuntu.com/ubuntu@https://mirrors.ustc.edu.cn/ubuntu@g' \
            /etc/apt/sources.list 2>/dev/null || true; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg sudo \
    build-essential git wget jq unzip xz-utils \
    python3 python3-pip python3-venv python3-dev \
    libssl-dev libffi-dev \
    locales fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# 安装开发工具
# 通过 install-tools.sh 统一管理，支持国内/国际两种模式
# ==========================================

# 构建时需要 /config 目录存在（运行时由 volume 挂载覆盖）
RUN mkdir -p /config && chown 1000:1000 /config

COPY scripts/install-tools.sh /usr/local/bin/install-tools.sh
RUN chmod +x /usr/local/bin/install-tools.sh \
    && USE_CHINA_MIRROR=${USE_CHINA_MIRROR} \
       GO_VERSION=${GO_VERSION} \
       NODE_VERSION=${NODE_VERSION} \
       /usr/local/bin/install-tools.sh

# ==========================================
# 复制脚本和服务
# ==========================================

COPY scripts/ /usr/local/bin/
COPY services/ /etc/services.d/

# LinuxServer custom-init: 在 DE 启动前执行的初始化脚本
RUN mkdir -p /custom-cont-init.d \
    && ln -sf /usr/local/bin/set-dpi.sh /custom-cont-init.d/set-dpi.sh \
    && ln -sf /usr/local/bin/fix-locale.sh /custom-cont-init.d/fix-locale.sh

RUN chmod +x /usr/local/bin/*.sh \
    && find /etc/services.d -name "run" -exec chmod +x {} \;

# 配置 s6 服务依赖（init 先执行，其他服务等待）
RUN mkdir -p /etc/services.d/systemctl-services/dependencies \
    && touch /etc/services.d/systemctl-services/dependencies/init

# ==========================================
# 权限配置
# ==========================================

RUN echo "abc ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/abc \
    && chmod 0440 /etc/sudoers.d/abc \
    && usermod -aG docker abc

# ==========================================
# 健康检查
# ==========================================

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# 使用 LinuxServer 原生的 /init 入口
