#!/bin/bash
# 持久化配置脚本
# 在容器启动时创建软链接，实现数据持久化

PERSIST_DIR="/config"
HOME_DIR="/home/kasm-user"

echo "[setup-persistence] Configuring persistence..."

# 确保持久化目录存在
mkdir -p ${PERSIST_DIR}

# 定义需要持久化的目录
PERSIST_DIRS=(
    ".npm-global"
    "go"
    ".cargo"
    ".rustup"
    ".cache"
    ".config"
    "docker-data"
    ".linuxbrew"
    "agent-workspace"
)

# 为每个目录创建软链接
for dir in "${PERSIST_DIRS[@]}"; do
    SOURCE="${HOME_DIR}/${dir}"
    TARGET="${PERSIST_DIR}/${dir}"
    
    # 如果持久化目录中不存在，但 home 中存在，先复制
    if [ -d "${SOURCE}" ] && [ ! -d "${TARGET}" ]; then
        echo "[setup-persistence] Copying ${dir} to persist..."
        cp -r "${SOURCE}" "${TARGET}"
    fi
    
    # 如果持久化目录存在，创建软链接
    if [ -d "${TARGET}" ]; then
        # 备份原始目录（如果存在且不是软链接）
        if [ -d "${SOURCE}" ] && [ ! -L "${SOURCE}" ]; then
            mv "${SOURCE}" "${SOURCE}.bak"
        fi
        
        # 创建软链接
        if [ ! -L "${SOURCE}" ]; then
            ln -sf "${TARGET}" "${SOURCE}"
            echo "[setup-persistence] Linked ${dir} -> ${TARGET}"
        fi
    fi
done

# 配置 Docker 数据目录
if [ -f "${HOME_DIR}/.config/docker/daemon.json" ]; then
    echo "[setup-persistence] Docker data-root configured"
fi

echo "[setup-persistence] Persistence configured!"
