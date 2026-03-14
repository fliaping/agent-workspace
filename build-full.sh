#!/bin/bash
# LinuxServer Webtop + DinD + GPU 加速 构建脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="my-webtop-full"
IMAGE_TAG="latest"
EXPORT_FILE="webtop-full-image.tar"

echo "======================================"
echo "  LinuxServer Webtop 完整版构建脚本"
echo "  (DinD + GPU 加速 + Agent 工具)"
echo "======================================"
echo ""

# 检查 Dockerfile
if [ ! -f "Dockerfile.webtop-full" ]; then
    echo "❌ 错误: Dockerfile.webtop-full 不存在"
    exit 1
fi

echo "步骤 1: 构建镜像"
echo "=================="
echo ""
echo "包含组件："
echo "  ✅ XFCE Ubuntu 桌面"
echo "  ✅ Docker-in-Docker (DinD)"
echo "  ✅ GPU 加速支持 (Wayland)"
echo "  ✅ Chrome 进程监控"
echo "  ✅ Python 3 + pip"
echo "  ✅ Node.js + npm"
echo "  ✅ Playwright + Selenium"
echo "  ✅ FFmpeg 多媒体工具"
echo "  ✅ Git, Vim, 网络工具"
echo "  ✅ 中文语言支持"
echo ""

docker build -f Dockerfile.webtop-full -t ${IMAGE_NAME}:${IMAGE_TAG} . 2>&1 | tee build.log

echo ""
echo "✅ 镜像构建成功"
docker images ${IMAGE_NAME}:${IMAGE_TAG}

echo ""
echo "步骤 2: 导出镜像"
echo "=================="
echo "导出中，这可能需要几分钟..."
docker save -o ${EXPORT_FILE} ${IMAGE_NAME}:${IMAGE_TAG}

echo ""
echo "✅ 镜像已导出: ${EXPORT_FILE}"
ls -lh ${EXPORT_FILE}

echo ""
echo "======================================"
echo "  构建完成!"
echo "======================================"
echo ""
echo "镜像信息："
echo "  名称: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  文件: ${EXPORT_FILE}"
echo "  大小: $(du -h ${EXPORT_FILE} | cut -f1)"
echo ""
echo "在宿主机上运行："
echo ""
echo "1. 传输并导入镜像："
echo "   scp ${EXPORT_FILE} user@host:/path/"
echo "   docker load -i ${EXPORT_FILE}"
echo ""
echo "2. 运行容器（基础）："
echo "   docker run -d --name webtop-full --privileged \\"
echo "     -p 3000:3000 \\"
echo "     -e PUID=1000 \\"
echo "     -e PGID=1000 \\"
echo "     -e TZ=Asia/Shanghai \\"
echo "     -v ./webtop-config:/config \\"
echo "     -v ./agent-workspace:/home/kasm-user/agent-workspace \\"
echo "     --shm-size=2gb \\"
echo "     --memory=8g \\"
echo "     --cpus=4 \\"
echo "     ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "3. 运行容器（带 GPU 加速）："
echo "   docker run -d --name webtop-full --privileged \\"
echo "     -p 3000:3000 \\"
echo "     -e PIXELFLUX_WAYLAND=true \\"
echo "     -e DRINODE=/dev/dri/renderD128 \\"
echo "     --device /dev/dri:/dev/dri \\"
echo "     -v ./webtop-config:/config \\"
echo "     --shm-size=2gb \\"
echo "     ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "4. 或使用 docker-compose："
echo "   docker compose -f docker-compose.webtop-full.yml up -d"
echo ""
echo "5. 访问桌面："
echo "   http://localhost:3000"
echo ""
echo "6. 在容器内使用 Docker："
echo "   docker exec -it webtop-full bash"
echo "   docker ps"
echo "   docker run hello-world"
echo ""
echo "⚠️  注意事项："
echo "   - 必须使用 --privileged 模式"
echo "   - GPU 加速需要宿主机有 GPU 驱动"
echo "   - 建议设置资源限制（--memory, --cpus）"
echo "   - 首次启动可能需要 1-2 分钟"
echo ""
