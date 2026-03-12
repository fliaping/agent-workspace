#!/bin/bash
#
# Agent Workspace 一键部署脚本
# 支持多语言: 中文 / English
# 使用方法: curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.sh | sudo bash
#

set -e

# ============================================================================
# 多语言配置
# ============================================================================

# 多语言文本字典
declare -A TEXTS

# 中文文本
TEXTS[cn_welcome_title]="Agent Workspace 一键部署"
TEXTS[cn_step1_title]="步骤 1/6: 选择语言"
TEXTS[cn_lang_cn]="1) 中文 (Chinese) - 使用阿里云镜像（国内推荐）"
TEXTS[cn_lang_en]="2) English (英文) - 使用 Docker Hub"
TEXTS[cn_enter_choice]="请输入选项"
TEXTS[cn_invalid_choice]="无效选项，请重新输入"
TEXTS[cn_step2_title]="步骤 2/6: 选择镜像版本"
TEXTS[cn_version_latest]="1) latest (最新版)"
TEXTS[cn_version_custom]="2) 自定义版本"
TEXTS[cn_enter_version]="请输入版本号"
TEXTS[cn_step3_title]="步骤 3/6: 配置数据目录"
TEXTS[cn_data_dir_default]="使用默认目录"
TEXTS[cn_data_dir_custom]="自定义目录"
TEXTS[cn_enter_data_dir]="请输入数据目录路径"
TEXTS[cn_step4_title]="步骤 4/6: 配置基础端口（VNC/Agent API）"
TEXTS[cn_port_config_title]="配置服务端口"
TEXTS[cn_port_vnc]="VNC 桌面端口"
TEXTS[cn_port_agent]="Agent API 端口"
TEXTS[cn_port_auto]="自动检测并分配端口"
TEXTS[cn_port_manual]="手动配置端口"
TEXTS[cn_enter_vnc_port]="请输入 VNC 端口"
TEXTS[cn_enter_agent_port]="请输入 Agent 端口"
TEXTS[cn_port_in_use]="端口已被占用"
TEXTS[cn_port_available]="端口可用"
TEXTS[cn_step5_title]="步骤 5/6: 选择 Agent 软件"
TEXTS[cn_agent_install_title]="选择要安装的 Agent 软件（可多选，空格分隔）"
TEXTS[cn_agent_openclaw]="1) OpenClaw - AI Agent 操作系统"
TEXTS[cn_agent_openfang]="2) Openfang - 智能体框架"
TEXTS[cn_agent_nanobot]="3) Nanobot - 轻量级 Agent"
TEXTS[cn_agent_zeroclaw]="4) Zeroclaw - 零配置 Agent"
TEXTS[cn_agent_skip]="5) 跳过，不安装任何软件"
TEXTS[cn_enter_agents]="请输入选项（如：1 2 3）"
TEXTS[cn_step6_title]="步骤 6/6: 配置 Agent 软件端口"
TEXTS[cn_agent_port_config]="配置 Agent 软件端口"
TEXTS[cn_agent_port_default]="使用默认端口"
TEXTS[cn_agent_port_custom]="自定义端口"
TEXTS[cn_enter_agent_port_num]="请输入端口"
TEXTS[cn_agent_port_openclaw]="OpenClaw 端口（默认 3000）"
TEXTS[cn_agent_port_openfang]="Openfang 端口（默认 8080）"
TEXTS[cn_agent_port_nanobot]="Nanobot 端口（默认 9000）"
TEXTS[cn_agent_port_zeroclaw]="Zeroclaw 端口（默认 7000）"
TEXTS[cn_installing_agents]="正在安装 Agent 软件..."
TEXTS[cn_agent_install_success]="Agent 软件安装成功"
TEXTS[cn_using_registry]="使用镜像仓库"
TEXTS[cn_selected_image]="已选择镜像"
TEXTS[cn_pulling]="正在拉取镜像..."
TEXTS[cn_pull_success]="镜像拉取成功"
TEXTS[cn_pull_failed]="镜像拉取失败"
TEXTS[cn_running]="正在启动容器..."
TEXTS[cn_run_success]="容器启动成功"
TEXTS[cn_run_failed]="容器启动失败"
TEXTS[cn_complete]="部署完成"
TEXTS[cn_access_info]="访问信息"
TEXTS[cn_vnc_desktop]="VNC桌面"
TEXTS[cn_agent_port]="Agent端口"
TEXTS[cn_data_dir]="数据目录"
TEXTS[cn_common_commands]="常用命令"
TEXTS[cn_view_logs]="查看日志"
TEXTS[cn_stop_service]="停止服务"
TEXTS[cn_start_service]="启动服务"
TEXTS[cn_enter_container]="进入容器"
TEXTS[cn_check_docker]="检查 Docker 环境..."
TEXTS[cn_docker_not_installed]="Docker 未安装"
TEXTS[cn_docker_install_guide]="请安装 Docker"
TEXTS[cn_docker_daemon_not_running]="Docker 守护进程未运行"
TEXTS[cn_start_docker_service]="请启动 Docker 服务"
TEXTS[cn_docker_compose_not_installed]="Docker Compose 未安装"
TEXTS[cn_container_exists]="容器已存在"
TEXTS[cn_delete_recreate]="是否删除并重新创建?"
TEXTS[cn_deleting_old]="正在删除旧容器..."
TEXTS[cn_starting_existing]="正在启动已有容器..."
TEXTS[cn_port_occupied]="端口被占用"
TEXTS[cn_auto_change_port]="自动更换端口为"
TEXTS[cn_creating_data_dir]="正在创建数据目录..."
TEXTS[cn_waiting_service]="等待服务启动..."
TEXTS[cn_os_detected]="检测到操作系统"
TEXTS[cn_dind_detected]="检测到 Docker in Docker (DinD) 环境"
TEXTS[cn_network_mode_title]="DinD 环境网络配置"
TEXTS[cn_network_host]="1) host 模式 (推荐，直接使用宿主机网络)"
TEXTS[cn_network_bridge]="2) bridge 模式 + 主机名映射"
TEXTS[cn_select_network]="请选择网络模式"
TEXTS[cn_using_host_network]="使用 host 网络模式"
TEXTS[cn_using_bridge_network]="使用 bridge 网络模式"
TEXTS[cn_need_sudo]="Linux 需要 root 权限，请使用 sudo 运行"
TEXTS[cn_usage]="使用方法"
TEXTS[cn_dind_sudo_warning]="DinD 环境中使用 sudo 可能导致 Docker 连接失败"
TEXTS[cn_try_without_sudo]="请尝试不使用 sudo 运行"

# 英文文本
TEXTS[en_welcome_title]="Agent Workspace Deployment"
TEXTS[en_step1_title]="Step 1/6: Select Language"
TEXTS[en_lang_cn]="1) 中文 (Chinese) - Use Alibaba Cloud Registry (Recommended for China)"
TEXTS[en_lang_en]="2) English - Use Docker Hub"
TEXTS[en_enter_choice]="Enter your choice"
TEXTS[en_invalid_choice]="Invalid choice, please try again"
TEXTS[en_step2_title]="Step 2/6: Select Image Version"
TEXTS[en_version_latest]="1) latest"
TEXTS[en_version_custom]="2) Custom version"
TEXTS[en_enter_version]="Enter version tag"
TEXTS[en_step3_title]="Step 3/6: Configure Data Directory"
TEXTS[en_data_dir_default]="Use default directory"
TEXTS[en_data_dir_custom]="Custom directory"
TEXTS[en_step4_title]="Step 4/6: Configure Base Ports (VNC/Agent API)"
TEXTS[en_port_config_title]="Configure Service Ports"
TEXTS[en_port_vnc]="VNC Desktop Port"
TEXTS[en_port_agent]="Agent API Port"
TEXTS[en_port_auto]="Auto detect and assign ports"
TEXTS[en_port_manual]="Manually configure ports"
TEXTS[en_enter_vnc_port]="Enter VNC port"
TEXTS[en_enter_agent_port]="Enter Agent port"
TEXTS[en_port_in_use]="Port is in use"
TEXTS[en_port_available]="Port is available"
TEXTS[en_enter_data_dir]="Enter data directory path"
TEXTS[en_step5_title]="Step 5/6: Select Agent Software"
TEXTS[en_agent_install_title]="Select Agent software to install (multiple choices allowed, space separated)"
TEXTS[en_agent_openclaw]="1) OpenClaw - AI Agent Operating System"
TEXTS[en_agent_openfang]="2) Openfang - Agent Framework"
TEXTS[en_agent_nanobot]="3) Nanobot - Lightweight Agent"
TEXTS[en_agent_zeroclaw]="4) Zeroclaw - Zero-config Agent"
TEXTS[en_agent_skip]="5) Skip, don't install any software"
TEXTS[en_enter_agents]="Enter options (e.g., 1 2 3)"
TEXTS[en_step6_title]="Step 6/6: Configure Agent Software Ports"
TEXTS[en_agent_port_config]="Configure Agent Software Ports"
TEXTS[en_agent_port_default]="Use default port"
TEXTS[en_agent_port_custom]="Custom port"
TEXTS[en_enter_agent_port_num]="Enter port"
TEXTS[en_agent_port_openclaw]="OpenClaw port (default 3000)"
TEXTS[en_agent_port_openfang]="Openfang port (default 8080)"
TEXTS[en_agent_port_nanobot]="Nanobot port (default 9000)"
TEXTS[en_agent_port_zeroclaw]="Zeroclaw port (default 7000)"
TEXTS[en_installing_agents]="Installing Agent software..."
TEXTS[en_agent_install_success]="Agent software installed successfully"
TEXTS[en_using_registry]="Using registry"
TEXTS[en_selected_image]="Selected image"
TEXTS[en_pulling]="Pulling image..."
TEXTS[en_pull_success]="Image pulled successfully"
TEXTS[en_pull_failed]="Failed to pull image"
TEXTS[en_running]="Starting container..."
TEXTS[en_run_success]="Container started successfully"
TEXTS[en_run_failed]="Failed to start container"
TEXTS[en_complete]="Deployment Complete"
TEXTS[en_access_info]="Access Information"
TEXTS[en_vnc_desktop]="VNC Desktop"
TEXTS[en_agent_port]="Agent Port"
TEXTS[en_data_dir]="Data Directory"
TEXTS[en_common_commands]="Common Commands"
TEXTS[en_view_logs]="View logs"
TEXTS[en_stop_service]="Stop service"
TEXTS[en_start_service]="Start service"
TEXTS[en_enter_container]="Enter container"
TEXTS[en_check_docker]="Checking Docker environment..."
TEXTS[en_docker_not_installed]="Docker is not installed"
TEXTS[en_docker_install_guide]="Please install Docker"
TEXTS[en_docker_daemon_not_running]="Docker daemon is not running"
TEXTS[en_start_docker_service]="Please start Docker service"
TEXTS[en_docker_compose_not_installed]="Docker Compose is not installed"
TEXTS[en_container_exists]="Container already exists"
TEXTS[en_delete_recreate]="Delete and recreate?"
TEXTS[en_deleting_old]="Deleting old container..."
TEXTS[en_starting_existing]="Starting existing container..."
TEXTS[en_port_occupied]="Port is occupied"
TEXTS[en_auto_change_port]="Auto changing port to"
TEXTS[en_creating_data_dir]="Creating data directory..."
TEXTS[en_waiting_service]="Waiting for service to start..."
TEXTS[en_os_detected]="Detected OS"
TEXTS[en_dind_detected]="Detected Docker in Docker (DinD) environment"
TEXTS[en_network_mode_title]="DinD Network Configuration"
TEXTS[en_network_host]="1) host mode (recommended, use host network directly)"
TEXTS[en_network_bridge]="2) bridge mode + hostname mapping"
TEXTS[en_select_network]="Select network mode"
TEXTS[en_using_host_network]="Using host network mode"
TEXTS[en_using_bridge_network]="Using bridge network mode"
TEXTS[en_need_sudo]="Linux requires root privileges, please run with sudo"
TEXTS[en_usage]="Usage"
TEXTS[en_dind_sudo_warning]="Using sudo in DinD environment may cause Docker connection failure"
TEXTS[en_try_without_sudo]="Please try running without sudo"
TEXTS[cn_windows_wsl2_detected]="检测到 Windows WSL2 环境"
TEXTS[cn_windows_wsl2_recommended]="推荐使用 WSL2 + Docker 方式运行"
TEXTS[cn_windows_wsl2_install_docker]="请在 WSL2 中安装 Docker："
TEXTS[cn_windows_wsl2_guide]="1. 在 WSL2 中执行: sudo apt update && sudo apt install -y docker.io docker-compose"
TEXTS[cn_windows_wsl2_guide2]="2. 启动 Docker: sudo service docker start"
TEXTS[cn_windows_wsl2_guide3]="3. 重新运行此脚本"
TEXTS[cn_windows_native_detected]="检测到 Windows 原生环境"
TEXTS[cn_windows_docker_desktop_guide]="请安装 Docker Desktop："
TEXTS[cn_windows_docker_desktop_url]="下载地址: https://www.docker.com/products/docker-desktop"
TEXTS[cn_windows_docker_desktop_guide2]="安装完成后，请重新运行此脚本"
TEXTS[en_windows_wsl2_detected]="Windows WSL2 environment detected"
TEXTS[en_windows_wsl2_recommended]="Recommended to use WSL2 + Docker"
TEXTS[en_windows_wsl2_install_docker]="Please install Docker in WSL2:"
TEXTS[en_windows_wsl2_guide]="1. Run in WSL2: sudo apt update && sudo apt install -y docker.io docker-compose"
TEXTS[en_windows_wsl2_guide2]="2. Start Docker: sudo service docker start"
TEXTS[en_windows_wsl2_guide3]="3. Re-run this script"
TEXTS[en_windows_native_detected]="Windows native environment detected"
TEXTS[en_windows_docker_desktop_guide]="Please install Docker Desktop:"
TEXTS[en_windows_docker_desktop_url]="Download: https://www.docker.com/products/docker-desktop"
TEXTS[en_windows_docker_desktop_guide2]="After installation, please re-run this script"
TEXTS[cn_macos_detected]="检测到 macOS 系统"
TEXTS[cn_macos_docker_guide]="请安装 Docker，推荐以下方式："
TEXTS[cn_macos_orbstack]="1) Orbstack (推荐，轻量快速)"
TEXTS[cn_macos_orbstack_url]="   https://orbstack.dev/"
TEXTS[cn_macos_docker_desktop]="2) Docker Desktop (官方版)"
TEXTS[cn_macos_docker_desktop_url]="   https://www.docker.com/products/docker-desktop"
TEXTS[cn_macos_podman]="3) Podman (开源替代)"
TEXTS[cn_macos_podman_url]="   https://podman.io/"
TEXTS[cn_macos_install_complete]="安装完成后，请重新运行此脚本"
TEXTS[en_macos_detected]="macOS system detected"
TEXTS[en_macos_docker_guide]="Please install Docker, recommended options:"
TEXTS[en_macos_orbstack]="1) Orbstack (Recommended, lightweight and fast)"
TEXTS[en_macos_orbstack_url]="   https://orbstack.dev/"
TEXTS[en_macos_docker_desktop]="2) Docker Desktop (Official)"
TEXTS[en_macos_docker_desktop_url]="   https://www.docker.com/products/docker-desktop"
TEXTS[en_macos_podman]="3) Podman (Open source alternative)"
TEXTS[en_macos_podman_url]="   https://podman.io/"
TEXTS[en_macos_install_complete]="After installation, please re-run this script"

# 获取文本函数
get_text() {
    local key="${LANG}_${1}"
    echo "${TEXTS[$key]}"
}

# ============================================================================
# 配置
# ============================================================================

# 镜像仓库配置
REGISTRY_CN="registry.cn-hangzhou.aliyuncs.com/fliaping/agent-workspace"
REGISTRY_EN="xuping/agent-workspace"

# 默认版本
DEFAULT_VERSION="latest"

# 容器配置
CONTAINER_NAME="agent-workspace"
VNC_PORT="6901"
AGENT_PORT="19789"

# Agent 软件默认端口配置
declare -A AGENT_PORTS
AGENT_PORTS[openclaw]="3000"
AGENT_PORTS[openfang]="8080"
AGENT_PORTS[nanobot]="9000"
AGENT_PORTS[zeroclaw]="7000"

# 用户自定义的 Agent 端口
declare -A CUSTOM_AGENT_PORTS

# 当前语言 (cn/en)
LANG="cn"

# 选择的镜像
SELECTED_IMAGE=""
VERSION=""

# 数据目录
DATA_DIR=""

# 要安装的 Agent 软件
INSTALL_AGENTS=()

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# 步骤 1: 选择语言
# ============================================================================
select_language() {
    echo ""
    echo "========================================"
    echo "  $(get_text welcome_title)"
    echo "========================================"
    echo ""
    
    echo ""
    print_info "$(get_text step1_title)"
    echo "  $(get_text lang_cn)"
    echo "  $(get_text lang_en)"
    echo ""
    
    while true; do
        read -p "$(get_text enter_choice) [1-2, default 1]: " lang_choice
        lang_choice=${lang_choice:-1}
        
        case $lang_choice in
            1)
                LANG="cn"
                print_info "Language: 中文"
                return
                ;;
            2)
                LANG="en"
                print_info "Language: English"
                return
                ;;
            *)
                print_error "$(get_text invalid_choice)"
                ;;
        esac
    done
}

# ============================================================================
# 步骤 2: 选择镜像版本
# ============================================================================
select_version() {
    echo ""
    print_info "$(get_text step2_title)"
    echo "  $(get_text version_latest)"
    echo "  $(get_text version_custom)"
    echo ""
    
    read -p "$(get_text enter_choice) [1-2, default 1]: " version_choice
    version_choice=${version_choice:-1}
    
    case $version_choice in
        1)
            VERSION="$DEFAULT_VERSION"
            ;;
        2)
            echo ""
            read -p "$(get_text enter_version): " VERSION
            ;;
        *)
            VERSION="$DEFAULT_VERSION"
            ;;
    esac
    
    # 构建完整镜像名
    if [ "$LANG" = "cn" ]; then
        SELECTED_IMAGE="${REGISTRY_CN}:${VERSION}"
    else
        SELECTED_IMAGE="${REGISTRY_EN}:${VERSION}"
    fi
    
    echo ""
    print_info "$(get_text using_registry): $(if [ "$LANG" = "cn" ]; then echo "$REGISTRY_CN"; else echo "$REGISTRY_EN"; fi)"
    print_info "$(get_text selected_image): $SELECTED_IMAGE"
}

# ============================================================================
# 步骤 3: 配置数据目录
# ============================================================================
select_data_dir() {
    echo ""
    print_info "$(get_text step3_title)"
    
    # 获取默认目录（当前用户 home 目录下的 agent-workspace-data）
    local default_dir="$HOME/agent-workspace-data"
    
    echo ""
    echo "  1) $(get_text data_dir_default): $default_dir"
    echo "  2) $(get_text data_dir_custom)"
    echo ""
    
    read -p "$(get_text enter_choice) [1-2, default 1]: " dir_choice
    dir_choice=${dir_choice:-1}
    
    case $dir_choice in
        1)
            DATA_DIR="$default_dir"
            ;;
        2)
            echo ""
            read -p "$(get_text enter_data_dir): " custom_dir
            if [ -z "$custom_dir" ]; then
                DATA_DIR="$default_dir"
                print_warning "输入为空，使用默认目录: $DATA_DIR"
            else
                DATA_DIR="$custom_dir"
            fi
            ;;
        *)
            DATA_DIR="$default_dir"
            ;;
    esac
    
    # 展开路径中的 ~
    DATA_DIR="${DATA_DIR/#\~/$HOME}"
    
    echo ""
    print_info "$(get_text data_dir): $DATA_DIR"
}

# ============================================================================
# 步骤 4: 配置端口
# ============================================================================
select_ports() {
    echo ""
    print_info "$(get_text step4_title)"
    echo ""
    print_info "$(get_text port_config_title)"
    echo "  $(get_text port_vnc): $VNC_PORT"
    echo "  $(get_text port_agent): $AGENT_PORT"
    echo ""
    echo "  1) $(get_text port_auto)"
    echo "  2) $(get_text port_manual)"
    echo ""
    
    read -p "$(get_text enter_choice) [1-2, default 1]: " port_choice
    port_choice=${port_choice:-1}
    
    case $port_choice in
        1)
            # 自动检测端口
            print_info "$(get_text port_auto)..."
            if ! check_port_available $VNC_PORT; then
                print_warning "$(get_text port_vnc) $VNC_PORT $(get_text port_in_use)"
                VNC_PORT=$(find_available_port $VNC_PORT)
                print_info "$(get_text port_vnc) $(get_text auto_change_port): $VNC_PORT"
            else
                print_success "$(get_text port_vnc) $VNC_PORT $(get_text port_available)"
            fi
            
            if ! check_port_available $AGENT_PORT; then
                print_warning "$(get_text port_agent) $AGENT_PORT $(get_text port_in_use)"
                AGENT_PORT=$(find_available_port $AGENT_PORT)
                print_info "$(get_text port_agent) $(get_text auto_change_port): $AGENT_PORT"
            else
                print_success "$(get_text port_agent) $AGENT_PORT $(get_text port_available)"
            fi
            ;;
        2)
            # 手动配置端口
            echo ""
            read -p "$(get_text enter_vnc_port) [default $VNC_PORT]: " custom_vnc_port
            if [ -n "$custom_vnc_port" ]; then
                if check_port_available $custom_vnc_port; then
                    VNC_PORT=$custom_vnc_port
                    print_success "$(get_text port_vnc) $VNC_PORT $(get_text port_available)"
                else
                    print_warning "$(get_text port_vnc) $custom_vnc_port $(get_text port_in_use)"
                    VNC_PORT=$(find_available_port $custom_vnc_port)
                    print_info "$(get_text port_vnc) $(get_text auto_change_port): $VNC_PORT"
                fi
            fi
            
            echo ""
            read -p "$(get_text enter_agent_port) [default $AGENT_PORT]: " custom_agent_port
            if [ -n "$custom_agent_port" ]; then
                if check_port_available $custom_agent_port; then
                    AGENT_PORT=$custom_agent_port
                    print_success "$(get_text port_agent) $AGENT_PORT $(get_text port_available)"
                else
                    print_warning "$(get_text port_agent) $custom_agent_port $(get_text port_in_use)"
                    AGENT_PORT=$(find_available_port $custom_agent_port)
                    print_info "$(get_text port_agent) $(get_text auto_change_port): $AGENT_PORT"
                fi
            fi
            ;;
        *)
            # 默认自动检测
            if ! check_port_available $VNC_PORT; then
                VNC_PORT=$(find_available_port $VNC_PORT)
            fi
            if ! check_port_available $AGENT_PORT; then
                AGENT_PORT=$(find_available_port $AGENT_PORT)
            fi
            ;;
    esac
    
    echo ""
    print_info "$(get_text port_vnc): $VNC_PORT"
    print_info "$(get_text port_agent): $AGENT_PORT"
}

# ============================================================================
# 步骤 6: 配置 Agent 软件端口
# ============================================================================
configure_agent_ports() {
    if [ ${#INSTALL_AGENTS[@]} -eq 0 ]; then
        return
    fi
    
    echo ""
    print_info "$(get_text step6_title)"
    echo ""
    print_info "$(get_text agent_port_config)"
    echo ""
    
    for agent in "${INSTALL_AGENTS[@]}"; do
        local default_port="${AGENT_PORTS[$agent]}"
        local port_name=""
        
        case $agent in
            openclaw) port_name="$(get_text agent_port_openclaw)" ;;
            openfang) port_name="$(get_text agent_port_openfang)" ;;
            nanobot) port_name="$(get_text agent_port_nanobot)" ;;
            zeroclaw) port_name="$(get_text agent_port_zeroclaw)" ;;
        esac
        
        echo ""
        echo "  $port_name"
        echo "  1) $(get_text agent_port_default): $default_port"
        echo "  2) $(get_text agent_port_custom)"
        echo ""
        
        read -p "$(get_text enter_choice) [1-2, default 1]: " port_choice
        port_choice=${port_choice:-1}
        
        case $port_choice in
            1)
                CUSTOM_AGENT_PORTS[$agent]=$default_port
                # 检查端口是否可用
                if ! check_port_available $default_port; then
                    print_warning "$port_name $default_port $(get_text port_in_use)"
                    local new_port=$(find_available_port $default_port)
                    CUSTOM_AGENT_PORTS[$agent]=$new_port
                    print_info "$port_name $(get_text auto_change_port): $new_port"
                else
                    print_success "$port_name $default_port $(get_text port_available)"
                fi
                ;;
            2)
                echo ""
                read -p "$(get_text enter_agent_port_num): " custom_port
                if [ -n "$custom_port" ]; then
                    if check_port_available $custom_port; then
                        CUSTOM_AGENT_PORTS[$agent]=$custom_port
                        print_success "$port_name $custom_port $(get_text port_available)"
                    else
                        print_warning "$port_name $custom_port $(get_text port_in_use)"
                        local new_port=$(find_available_port $custom_port)
                        CUSTOM_AGENT_PORTS[$agent]=$new_port
                        print_info "$port_name $(get_text auto_change_port): $new_port"
                    fi
                else
                    CUSTOM_AGENT_PORTS[$agent]=$default_port
                fi
                ;;
            *)
                CUSTOM_AGENT_PORTS[$agent]=$default_port
                ;;
        esac
    done
    
    # 显示配置的端口
    echo ""
    print_info "Agent 软件端口配置:"
    for agent in "${INSTALL_AGENTS[@]}"; do
        echo "  $agent: ${CUSTOM_AGENT_PORTS[$agent]}"
    done
}

# ============================================================================
# 步骤 5: 选择要安装的 Agent 软件
# ============================================================================
select_agents() {
    echo ""
    print_info "$(get_text step5_title)"
    echo ""
    print_info "$(get_text agent_install_title)"
    echo "  $(get_text agent_openclaw)"
    echo "  $(get_text agent_openfang)"
    echo "  $(get_text agent_nanobot)"
    echo "  $(get_text agent_zeroclaw)"
    echo "  $(get_text agent_skip)"
    echo ""
    
    read -p "$(get_text enter_agents) [1-5, default 5]: " agent_choices
    agent_choices=${agent_choices:-5}
    
    # 解析用户选择
    for choice in $agent_choices; do
        case $choice in
            1) INSTALL_AGENTS+=("openclaw") ;;
            2) INSTALL_AGENTS+=("openfang") ;;
            3) INSTALL_AGENTS+=("nanobot") ;;
            4) INSTALL_AGENTS+=("zeroclaw") ;;
            5) 
                INSTALL_AGENTS=()
                print_info "跳过 Agent 软件安装"
                return
                ;;
        esac
    done
    
    if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
        echo ""
        print_info "将安装以下软件: ${INSTALL_AGENTS[*]}"
    fi
}

# ============================================================================
# 在容器内安装 Agent 软件
# ============================================================================
install_agents_in_container() {
    # 根据语言选择镜像源
    local npm_registry=""
    local pip_index=""
    
    if [ "$LANG" = "cn" ]; then
        npm_registry="--registry=https://registry.npmmirror.com"
        pip_index="-i https://pypi.tuna.tsinghua.edu.cn/simple"
    fi
    
    for agent in "${INSTALL_AGENTS[@]}"; do
        local agent_port="${CUSTOM_AGENT_PORTS[$agent]}"
        
        case $agent in
            openclaw)
                # OpenClaw 安装方式：https://github.com/openclaw/openclaw
                # npm install -g openclaw@latest
                print_info "Installing OpenClaw (Port: $agent_port)..."
                docker exec "$CONTAINER_NAME" bash -c "
                    export OPENCLAW_PORT=$agent_port
                    echo 'Installing OpenClaw...'
                    npm install -g openclaw@latest $npm_registry
                    echo 'Running OpenClaw onboarding...'
                    openclaw onboard --install-daemon || true
                " || print_warning "OpenClaw 安装失败，请手动安装"
                ;;
            openfang)
                # Openfang 安装方式：https://github.com/RightNow-AI/openfang
                # curl -fsSL https://openfang.sh/install | sh
                print_info "Installing Openfang (Port: $agent_port)..."
                docker exec "$CONTAINER_NAME" bash -c "
                    export OPENFANG_PORT=$agent_port
                    echo 'Installing Openfang...'
                    curl -fsSL https://openfang.sh/install | sh
                    echo 'Initializing Openfang...'
                    openfang init || true
                " || print_warning "Openfang 安装失败，请手动安装"
                ;;
            nanobot)
                # Nanobot 安装方式：https://github.com/HKUDS/nanobot
                # git clone + pip install -e .
                print_info "Installing Nanobot (Port: $agent_port)..."
                if [ "$LANG" = "cn" ]; then
                    # 中文环境使用 Gitee 镜像
                    docker exec "$CONTAINER_NAME" bash -c "
                        export NANOBOT_PORT=$agent_port
                        echo 'Installing Nanobot from Gitee mirror...'
                        cd /tmp
                        git clone https://gitee.com/mirrors/nanobot.git || git clone https://github.com/HKUDS/nanobot.git
                        cd nanobot
                        pip install -e . $pip_index
                        echo 'Nanobot installed successfully'
                    " || print_warning "Nanobot 安装失败，请手动安装"
                else
                    # 英文环境使用 GitHub 官方源
                    docker exec "$CONTAINER_NAME" bash -c "
                        export NANOBOT_PORT=$agent_port
                        echo 'Installing Nanobot from GitHub...'
                        cd /tmp
                        git clone https://github.com/HKUDS/nanobot.git
                        cd nanobot
                        pip install -e .
                        echo 'Nanobot installed successfully'
                    " || print_warning "Nanobot installation failed, please install manually"
                fi
                ;;
            zeroclaw)
                # Zeroclaw 安装方式：https://github.com/zeroclaw-labs/zeroclaw
                # curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | sh
                print_info "Installing Zeroclaw (Port: $agent_port)..."
                docker exec "$CONTAINER_NAME" bash -c "
                    export ZEROCLAW_PORT=$agent_port
                    echo 'Installing Zeroclaw...'
                    curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | sh
                    echo 'Zeroclaw installed successfully'
                " || print_warning "Zeroclaw 安装失败，请手动安装"
                ;;
        esac
    done
    
    print_success "$(get_text agent_install_success)"
}

# ============================================================================
# 环境检测
# ============================================================================

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            OS_TYPE="linux"
        else
            OS="Linux"
            OS_TYPE="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        OS_TYPE="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="Windows"
        OS_TYPE="windows"
    else
        OS="Unknown"
        OS_TYPE="unknown"
    fi
}

# 检测是否在 WSL2 环境
check_wsl2() {
    if [ -f /proc/version ]; then
        if grep -q "Microsoft" /proc/version || grep -q "WSL" /proc/version; then
            return 0
        fi
    fi
    return 1
}

# 检测 Windows/macOS 环境并给出指引
check_windows_environment() {
    if [[ "$OS_TYPE" == "windows" ]]; then
        # 检查是否在 WSL2 中
        if check_wsl2; then
            print_success "$(get_text windows_wsl2_detected)"
            print_info "$(get_text windows_wsl2_recommended)"
            
            # 检查 Docker 是否已安装
            if ! command -v docker &> /dev/null; then
                echo ""
                print_error "$(get_text docker_not_installed)"
                print_info "$(get_text windows_wsl2_install_docker)"
                echo ""
                echo "  $(get_text windows_wsl2_guide)"
                echo "  $(get_text windows_wsl2_guide2)"
                echo "  $(get_text windows_wsl2_guide3)"
                echo ""
                exit 1
            fi
        else
            # Windows 原生环境
            print_warning "$(get_text windows_native_detected)"
            
            # 检查 Docker Desktop 是否已安装
            if ! command -v docker &> /dev/null; then
                echo ""
                print_error "$(get_text docker_not_installed)"
                print_info "$(get_text windows_docker_desktop_guide)"
                echo ""
                echo "  $(get_text windows_docker_desktop_url)"
                echo ""
                echo "  $(get_text windows_docker_desktop_guide2)"
                echo ""
                exit 1
            fi
        fi
    elif [[ "$OS_TYPE" == "macos" ]]; then
        # macOS 环境
        print_info "$(get_text macos_detected)"
        
        # 检查 Docker 是否已安装
        if ! command -v docker &> /dev/null; then
            echo ""
            print_error "$(get_text docker_not_installed)"
            print_info "$(get_text macos_docker_guide)"
            echo ""
            echo "  $(get_text macos_orbstack)"
            echo "     $(get_text macos_orbstack_url)"
            echo ""
            echo "  $(get_text macos_docker_desktop)"
            echo "     $(get_text macos_docker_desktop_url)"
            echo ""
            echo "  $(get_text macos_podman)"
            echo "     $(get_text macos_podman_url)"
            echo ""
            echo "  $(get_text macos_install_complete)"
            echo ""
            exit 1
        fi
    fi
}

# 检测是否在容器内
is_container() {
    [ -f /.dockerenv ] || grep -qE "docker|kubepods" /proc/1/cgroup 2>/dev/null
}

# 检测是否在 DinD 环境
check_dind() {
    local score=0
    [ -f /.dockerenv ] && score=$((score + 1))
    if grep -qE "docker|kubepods" /proc/1/cgroup 2>/dev/null || [ "$(cat /proc/1/cgroup 2>/dev/null | head -1)" = "0::/" ]; then
        score=$((score + 1))
    fi
    [ -S /var/run/docker.sock ] && score=$((score + 1))
    local init_proc=$(ps -p 1 -o comm= 2>/dev/null)
    [ "$init_proc" != "systemd" ] && [ "$init_proc" != "init" ] && score=$((score + 1))
    local hostname_val=$(hostname 2>/dev/null)
    echo "$hostname_val" | grep -qE "^[a-f0-9]{12}$" && score=$((score + 1))
    [ $score -ge 4 ]
}

# ============================================================================
# Docker 相关
# ============================================================================

check_docker() {
    print_info "$(get_text check_docker)"
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker: $DOCKER_VERSION"
        return 0
    else
        return 1
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        return 0
    elif docker-compose --version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_docker_daemon() {
    if docker info &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# 端口管理
# ============================================================================

check_port_available() {
    local port=$1
    if command -v ss &> /dev/null; then
        ! ss -tuln 2>/dev/null | grep -q ":$port "
    elif command -v netstat &> /dev/null; then
        ! netstat -tuln 2>/dev/null | grep -q ":$port "
    else
        return 0
    fi
}

find_available_port() {
    local base_port=$1
    local port=$base_port
    while ! check_port_available $port; do
        port=$((port + 1))
        if [ $port -gt $((base_port + 100)) ]; then
            print_error "$(get_text port_occupied)"
            exit 1
        fi
    done
    echo $port
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    # 步骤 1: 选择语言
    select_language
    
    # 步骤 2: 选择版本
    select_version
    
    # 步骤 3: 配置数据目录
    select_data_dir
    
    # 步骤 4: 配置基础端口（VNC 和 Agent API）
    select_ports
    
    # 步骤 5: 选择 Agent 软件
    select_agents
    
    # 步骤 6: 配置 Agent 软件端口（如果选择了 Agent 软件）
    configure_agent_ports
    
    # 检测环境
    detect_os
    print_info "$(get_text os_detected): $OS"
    
    # Windows 环境特殊处理
    check_windows_environment
    
    # 检查是否在 DinD 环境
    local IS_DIND=false
    if check_dind; then
        IS_DIND=true
        print_warning "$(get_text dind_detected)"
    fi
    
    # 检查 Docker
    if ! check_docker; then
        print_error "$(get_text docker_not_installed)"
        if [[ "$OS_TYPE" == "linux" ]]; then
            print_info "$(get_text docker_install_guide): https://docs.docker.com/engine/install/"
        elif [[ "$OS_TYPE" == "windows" ]]; then
            # Windows 环境已经在 check_windows_environment 中处理
            exit 1
        else
            print_info "$(get_text docker_install_guide): https://www.docker.com/products/docker-desktop"
        fi
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! check_docker_compose; then
        print_warning "$(get_text docker_compose_not_installed)"
    fi
    
    # 检查 Docker 守护进程
    if ! check_docker_daemon; then
        print_error "$(get_text docker_daemon_not_running)"
        if is_container; then
            print_info "$(get_text start_docker_service): sudo systemctl start docker"
        else
            print_info "$(get_text start_docker_service): sudo systemctl start docker"
        fi
        exit 1
    fi
    
    # DinD 环境网络模式选择
    local USE_HOST_NETWORK=false
    if [ "$IS_DIND" = true ]; then
        echo ""
        print_info "$(get_text network_mode_title)"
        echo "  $(get_text network_host)"
        echo "  $(get_text network_bridge)"
        echo ""
        read -p "$(get_text select_network) [1/2, default 1]: " network_mode
        network_mode=${network_mode:-1}
        if [[ "$network_mode" != "2" ]]; then
            USE_HOST_NETWORK=true
            print_info "$(get_text using_host_network)"
        else
            print_info "$(get_text using_bridge_network)"
        fi
    fi
    
    # 检查/删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "$(get_text container_exists): $CONTAINER_NAME"
        read -p "$(get_text delete_recreate) [y/N]: " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            print_info "$(get_text deleting_old)"
            docker stop "$CONTAINER_NAME" &> /dev/null || true
            docker rm "$CONTAINER_NAME" &> /dev/null || true
        else
            print_info "$(get_text starting_existing)"
            docker start "$CONTAINER_NAME"
            print_success "$(get_text run_success)"
            print_access_info
            return
        fi
    fi
    
    # 端口检查（非 host 模式）
    if [ "$USE_HOST_NETWORK" = false ]; then
        if ! check_port_available $VNC_PORT; then
            print_warning "$(get_text port_occupied): $VNC_PORT"
            VNC_PORT=$(find_available_port $VNC_PORT)
            print_info "$(get_text auto_change_port): $VNC_PORT"
        fi
        if ! check_port_available $AGENT_PORT; then
            print_warning "$(get_text port_occupied): $AGENT_PORT"
            AGENT_PORT=$(find_available_port $AGENT_PORT)
            print_info "$(get_text auto_change_port): $AGENT_PORT"
        fi
    fi
    
    # 创建数据目录
    print_info "$(get_text creating_data_dir)"
    mkdir -p "$DATA_DIR"
    
    # 拉取镜像
    print_info "$(get_text pulling)"
    if ! docker pull "$SELECTED_IMAGE"; then
        print_error "$(get_text pull_failed)"
        exit 1
    fi
    print_success "$(get_text pull_success)"
    
    # 构建 docker run 命令
    DOCKER_ARGS=(
        "-d"
        "--name" "$CONTAINER_NAME"
        "--privileged"
        "--restart" "unless-stopped"
        "--shm-size" "2gb"
        "-e" "VNCOPTIONS=-disableBasicAuth"
        "-e" "NODE_OPTIONS=--max-old-space-size=2048"
        "-v" "${DATA_DIR}:/home/kasm-user"
    )
    
    # 网络配置
    if [ "$USE_HOST_NETWORK" = true ]; then
        DOCKER_ARGS+=("--network" "host")
    else
        DOCKER_ARGS+=(
            "-p" "${VNC_PORT}:6901"
            "-p" "${AGENT_PORT}:18789"
        )
        if [ "$IS_DIND" = true ]; then
            DOCKER_ARGS+=(
                "--add-host" "agent-workspace:127.0.0.1"
                "--hostname" "agent-workspace"
            )
        fi
    fi
    
    # 添加 Agent 软件端口环境变量（如果有）
    if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
        for agent in "${INSTALL_AGENTS[@]}"; do
            local agent_port="${CUSTOM_AGENT_PORTS[$agent]}"
            case $agent in
                openclaw) DOCKER_ARGS+=("-e" "OPENCLAW_PORT=$agent_port") ;;
                openfang) DOCKER_ARGS+=("-e" "OPENFANG_PORT=$agent_port") ;;
                nanobot) DOCKER_ARGS+=("-e" "NANOBOT_PORT=$agent_port") ;;
                zeroclaw) DOCKER_ARGS+=("-e" "ZEROCLAW_PORT=$agent_port") ;;
            esac
        done
    fi
    
    DOCKER_ARGS+=("$SELECTED_IMAGE")
    
    # 启动容器
    print_info "$(get_text running)"
    if ! docker run "${DOCKER_ARGS[@]}"; then
        print_error "$(get_text run_failed)"
        exit 1
    fi
    
    # 等待服务就绪
    print_info "$(get_text waiting_service)"
    local max_wait=60
    local waited=0
    while [ $waited -lt $max_wait ]; do
        if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "KasmVNC"; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done
    echo ""
    
    # 如果有 Agent 软件需要安装，在容器内直接执行安装命令
    if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
        echo ""
        print_info "$(get_text installing_agents)"
        install_agents_in_container
    fi
    
    print_success "$(get_text complete)!"
    print_access_info
}

# ============================================================================
# 输出访问信息
# ============================================================================

print_access_info() {
    echo ""
    echo "========================================"
    echo "  $(get_text access_info)"
    echo "========================================"
    echo ""
    
    local IP
    if command -v hostname &> /dev/null; then
        IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    else
        IP="localhost"
    fi
    
    if [ "$USE_HOST_NETWORK" = true ]; then
        print_info "🖥️  $(get_text vnc_desktop): https://${IP}:6901/"
        print_info "📡 $(get_text agent_port): 18789"
    else
        print_info "🖥️  $(get_text vnc_desktop): https://${IP}:${VNC_PORT}/"
        print_info "📡 $(get_text agent_port): ${AGENT_PORT}"
    fi
    
    print_info "💾 $(get_text data_dir): ${DATA_DIR}"
    
    if [ ${#INSTALL_AGENTS[@]} -gt 0 ]; then
        echo ""
        print_info "📦 已安装 Agent 软件:"
        for agent in "${INSTALL_AGENTS[@]}"; do
            local agent_port="${CUSTOM_AGENT_PORTS[$agent]}"
            echo "    ✓ $agent (端口: $agent_port)"
        done
    fi
    
    echo ""
    print_info "📋 $(get_text common_commands):"
    echo "    $(get_text view_logs): docker logs -f $CONTAINER_NAME"
    echo "    $(get_text stop_service): docker stop $CONTAINER_NAME"
    echo "    $(get_text start_service): docker start $CONTAINER_NAME"
    echo "    $(get_text enter_container): docker exec -it $CONTAINER_NAME bash"
    echo "========================================"
}

# ============================================================================
# 入口
# ============================================================================

# 检查是否以 sudo 运行（Linux，且非 DinD 环境）
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ "$EUID" -ne 0 ] && ! check_dind; then
    print_error "$(get_text need_sudo)"
    echo ""
    echo "$(get_text usage):"
    echo "  sudo ./install.sh"
    echo "  $(get_text or)"
    echo '  curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.sh | sudo bash'
    exit 1
fi

# DinD 环境特殊处理
if check_dind && [ "$EUID" -eq 0 ]; then
    print_warning "$(get_text dind_sudo_warning)"
    print_info "$(get_text try_without_sudo): ./install.sh"
    exit 1
fi

main "$@"
