#!/bin/bash
#
# 阿里云容器镜像服务配置脚本
# 用于初始化阿里云镜像仓库
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配置
ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
NAMESPACE="fliaping"
REPO_NAME="agent-workspace"
FULL_REPO="${ALIYUN_REGISTRY}/${NAMESPACE}/${REPO_NAME}"

echo "========================================"
echo "  阿里云容器镜像服务配置"
echo "========================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    print_error "Docker 未安装"
    exit 1
fi

# 提示用户输入阿里云凭证
echo "请输入阿里云容器镜像服务的访问凭证："
echo ""
read -p "阿里云用户名 (通常是邮箱): " ALIYUN_USERNAME
read -s -p "阿里云密码: " ALIYUN_PASSWORD
echo ""

# 登录阿里云仓库
print_info "正在登录阿里云仓库..."
if docker login --username="$ALIYUN_USERNAME" --password="$ALIYUN_PASSWORD" "$ALIYUN_REGISTRY"; then
    print_success "登录成功"
else
    print_error "登录失败，请检查用户名和密码"
    exit 1
fi

echo ""
print_info "阿里云镜像仓库信息："
echo "  仓库地址: ${FULL_REPO}"
echo "  命名空间: ${NAMESPACE}"
echo "  仓库名称: ${REPO_NAME}"
echo ""

# 检查本地镜像
print_info "检查本地镜像..."
LOCAL_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "agent-workspace" | head -1)

if [ -z "$LOCAL_IMAGE" ]; then
    print_warning "未找到本地 agent-workspace 镜像"
    echo ""
    echo "请先用以下命令构建镜像："
    echo "  docker build -t ${FULL_REPO}:v1.0.0 -f Dockerfile_zh ."
    echo ""
    echo "或使用现有镜像："
    echo "  docker pull xuping/agent-workspace:v1.0.0-zh"
    echo "  docker tag xuping/agent-workspace:v1.0.0-zh ${FULL_REPO}:v1.0.0"
    exit 0
fi

print_success "找到本地镜像: $LOCAL_IMAGE"

# 询问是否推送
read -p "是否推送镜像到阿里云仓库? [y/N]: " PUSH_CONFIRM

if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    # 提取版本标签
    CURRENT_TAG=$(echo "$LOCAL_IMAGE" | cut -d':' -f2)
    read -p "请输入要推送的版本标签 [默认: ${CURRENT_TAG}]: " VERSION_TAG
    VERSION_TAG=${VERSION_TAG:-$CURRENT_TAG}
    
    # 打标签
    TARGET_IMAGE="${FULL_REPO}:${VERSION_TAG}"
    print_info "正在给镜像打标签..."
    docker tag "$LOCAL_IMAGE" "$TARGET_IMAGE"
    print_success "标签已创建: $TARGET_IMAGE"
    
    # 推送镜像
    print_info "正在推送镜像到阿里云..."
    if docker push "$TARGET_IMAGE"; then
        print_success "镜像推送成功!"
        echo ""
        echo "阿里云镜像地址: ${TARGET_IMAGE}"
    else
        print_error "镜像推送失败"
        exit 1
    fi
fi

echo ""
echo "========================================"
print_success "配置完成!"
echo "========================================"
echo ""
echo "使用方式："
echo "  拉取镜像: docker pull ${FULL_REPO}:<版本号>"
echo "  运行容器: docker run -d --name agent-workspace -p 6901:6901 ${FULL_REPO}:<版本号>"
echo ""
