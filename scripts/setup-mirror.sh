#!/bin/bash
# 配置软件源脚本
# 根据 USE_CHINA_MIRROR 环境变量配置

if [ "$USE_CHINA_MIRROR" = "true" ]; then
    echo "[setup-mirror] Configuring China mirrors..."
    
    # Ubuntu 阿里云源
    cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
EOF
    
    # Docker 阿里云源
    mkdir -p /etc/apt/keyrings
    ARCH=$(dpkg --print-architecture)
    curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null || true
    chmod a+r /etc/apt/keyrings/docker.asc 2>/dev/null || true
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] http://mirrors.aliyun.com/docker-ce/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    
    echo "[setup-mirror] China mirrors configured"
else
    echo "[setup-mirror] Using default mirrors"
fi
