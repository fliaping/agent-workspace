# LinuxServer Webtop 完整版 (DinD + GPU)

## 📦 镜像信息

- **镜像名称**: `my-webtop-full:latest`
- **导出文件**: `webtop-full-image.tar` (2.9GB)
- **基础镜像**: `lscr.io/linuxserver/webtop:ubuntu-xfce`
- **支持架构**: x86-64, ARM64

## ✨ 功能特性

### 核心功能
- ✅ XFCE Ubuntu 桌面环境
- ✅ 基于 KasmVNC，浏览器访问
- ✅ 音频输出支持
- ✅ 文件上传/下载支持
- ✅ 麦克风透传支持
- ✅ 剪贴板同步
- ✅ Chrome 进程监控（防止泄漏）

### DinD (Docker-in-Docker)
- ✅ 完全隔离的 Docker 环境
- ✅ 容器内可运行 Docker 容器
- ✅ 独立的 Docker daemon

### GPU 加速
- ✅ Wayland 模式支持
- ✅ Intel/AMD GPU 支持
- ✅ NVIDIA GPU 支持（需额外配置）
- ✅ 零拷贝编码

## 🚀 使用方法

### 1. 传输镜像到宿主机

```bash
scp webtop-full-image.tar user@your-host:/path/to/dest/
```

### 2. 在宿主机导入并运行

```bash
# 导入镜像
docker load -i webtop-full-image.tar

# 基础运行
docker run -d \
  --name webtop-full \
  --privileged \
  -p 3000:3000 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -v $(pwd)/webtop-config:/config \
  -v $(pwd)/agent-workspace:/home/kasm-user/agent-workspace \
  --shm-size=2gb \
  --memory=8g \
  --cpus=4 \
  my-webtop-full:latest
```

### 3. 带 GPU 加速运行

#### Intel/AMD GPU
```bash
docker run -d \
  --name webtop-full \
  --privileged \
  -p 3000:3000 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -e PIXELFLUX_WAYLAND=true \
  -e DRINODE=/dev/dri/renderD128 \
  -e DRI_NODE=/dev/dri/renderD128 \
  --device /dev/dri:/dev/dri \
  -v $(pwd)/webtop-config:/config \
  --shm-size=2gb \
  my-webtop-full:latest
```

#### NVIDIA GPU
```bash
docker run -d \
  --name webtop-full \
  --privileged \
  -p 3000:3000 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -e PIXELFLUX_WAYLAND=true \
  --gpus all \
  -v $(pwd)/webtop-config:/config \
  --shm-size=2gb \
  my-webtop-full:latest
```

### 4. 使用 Docker Compose

```bash
docker compose -f docker-compose.webtop-full.yml up -d
```

### 5. 访问桌面

```
http://localhost:3000
```

## 🔧 常用命令

```bash
# 查看日志
docker logs -f webtop-full

# 进入容器
docker exec -it webtop-full bash

# 在容器内使用 Docker
docker exec -it webtop-full bash
docker ps
docker run hello-world

# 停止/启动
docker stop webtop-full
docker start webtop-full

# 删除
docker rm -f webtop-full
```

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `Dockerfile.webtop-full` | 镜像构建文件 |
| `docker-compose.webtop-full.yml` | Docker Compose 配置 |
| `webtop-full-image.tar` | 导出的镜像文件 (2.9GB) |
| `README-webtop-full.md` | 本说明文件 |

## 🔒 安全提示

- ⚠️ 此容器使用 `privileged` 模式
- ⚠️ DinD 提供完全隔离的 Docker 环境
- ⚠️ 建议设置资源限制（--memory, --cpus）
- ✅ 容器内 Docker 与宿主机完全隔离

## 🐛 故障排除

### DinD 无法启动
```bash
# 检查 Docker 服务状态
docker exec webtop-full ps aux | grep docker

# 查看 DinD 日志
docker exec webtop-full cat /var/log/docker.log
```

### GPU 加速不生效
```bash
# 检查 GPU 设备
docker exec webtop-full ls -la /dev/dri/

# 检查 Wayland 模式
docker exec webtop-full echo $PIXELFLUX_WAYLAND
```

## 📝 备注

- 首次启动可能需要 1-2 分钟
- DinD 数据默认不持久化（可选挂载 /var/lib/docker）
- GPU 加速需要宿主机有相应驱动
