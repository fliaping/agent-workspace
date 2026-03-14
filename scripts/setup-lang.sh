#!/bin/bash
# 配置系统语言脚本
# 根据 SYSTEM_LANG 环境变量配置

if [ "$SYSTEM_LANG" = "zh_CN" ]; then
    echo "[setup-lang] Setting up Chinese environment..."
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8
    echo "LANG=zh_CN.UTF-8" >> /etc/environment
    echo "LANGUAGE=zh_CN:zh" >> /etc/environment
    echo "LC_ALL=zh_CN.UTF-8" >> /etc/environment
    echo "[setup-lang] Chinese environment configured"
else
    echo "[setup-lang] Setting up English environment..."
    export LANG=en_US.UTF-8
    export LANGUAGE=en_US:en
    export LC_ALL=en_US.UTF-8
    echo "LANG=en_US.UTF-8" >> /etc/environment
    echo "LANGUAGE=en_US:en" >> /etc/environment
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "[setup-lang] English environment configured"
fi
