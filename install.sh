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
TEXTS[cn_step1_title]="步骤 1/3: 选择语言"
TEXTS[cn_lang_cn]="1) 中文 (Chinese) - 使用阿里云镜像（国内推荐）"
TEXTS[cn_lang_en]="2) English (英文) - 使用 Docker Hub"
TEXTS[cn_enter_choice]="请输入选项"
TEXTS[cn_invalid_choice]="无效选项，请重新输入"
TEXTS[cn_step2_title]="步骤 2/3: 选择镜像版本"
TEXTS[cn_version_latest]="1) latest (最新版)"
TEXTS[cn_version_custom]="2) 自定义版本"
TEXTS[cn_enter_version]="请输入版本号"
TEXTS[cn_step3_title]="步骤 3/3: 配置选项"
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
TEXTS[en_step1_title]="Step 1/3: Select Language"
TEXTS[en_lang_cn]="1) 中文 (Chinese) - Use Alibaba Cloud Registry (Recommended for China)"
TEXTS[en_lang_en]="2) English - Use Docker Hub"
TEXTS[en_enter_choice]="Enter your choice"
TEXTS[en_invalid_choice]="Invalid choice, please try again"
TEXTS[en_step2_title]="Step 2/3: Select Image Version"
TEXTS[en_version_latest]="1) latest"
TEXTS[en_version_custom]="2) Custom version"
TEXTS[en_enter_version]="Enter version tag"
TEXTS[en_step3_title]="Step 3/3: Configuration"
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
DEFAULT_VERSION="v1.0.0"

# 容器配置
CONTAINER_NAME="agent-workspace"
VNC_PORT="6901"
AGENT_PORT="19789"

# 当前语言 (cn/en)
LANG="cn"

# 选择的镜像
SELECTED_IMAGE=""
VERSION=""

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
    
    # 检测环境
    detect_os
    print_info "$(get_text os_detected): $OS"
    
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
    DATA_DIR="$(pwd)/agent-workspace-data"
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
