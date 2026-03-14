#!/bin/bash
# 配置系统语言脚本
# 根据 SYSTEM_LANG 环境变量配置

if [ "$SYSTEM_LANG" = "zh_CN" ]; then
    echo "[setup-lang] 配置中文环境..."
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8
    echo "LANG=zh_CN.UTF-8" >> /etc/environment
    echo "LANGUAGE=zh_CN:zh" >> /etc/environment
    echo "LC_ALL=zh_CN.UTF-8" >> /etc/environment
    echo "[setup-lang] 中文环境配置完成"
else
    echo "[setup-lang] 配置英文环境..."
    export LANG=en_US.UTF-8
    export LANGUAGE=en_US:en
    export LC_ALL=en_US.UTF-8
    echo "LANG=en_US.UTF-8" >> /etc/environment
    echo "LANGUAGE=en_US:en" >> /etc/environment
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "[setup-lang] 英文环境配置完成"
fi
