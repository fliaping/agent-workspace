#!/bin/bash
# 配置软件源脚本
# 根据 USE_CHINA_MIRROR 环境变量配置

if [ "$USE_CHINA_MIRROR" = "true" ]; then
    echo "[setup-mirror] 配置国内软件源..."
    
    # Ubuntu 阿里云源
    cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
EOF
    
    # Docker 阿里云源
    mkdir -p /etc/apt/keyrings
    curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null || true
    chmod a+r /etc/apt/keyrings/docker.asc 2>/dev/null || true
    # 自动检测架构
    ARCH=$(dpkg --print-architecture)
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] http://mirrors.aliyun.com/docker-ce/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    
    echo "[setup-mirror] 国内软件源配置完成"
else
    echo "[setup-mirror] 使用默认软件源"
fi
