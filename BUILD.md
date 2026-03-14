# 多架构构建说明

## 支持的架构

本镜像支持以下架构：

| 架构 | Docker 平台 | 说明 |
|------|------------|------|
| x86-64 | `linux/amd64` | Intel/AMD 64位 |
| ARM64 | `linux/arm64` | Apple Silicon, ARM 服务器 |

## 基础镜像的多架构支持

基础镜像 `lscr.io/linuxserver/webtop:ubuntu-xfce` 已经支持多架构：

```bash
# Docker 会自动根据宿主机架构拉取对应版本
docker pull lscr.io/linuxserver/webtop:ubuntu-xfce
```

## 构建多架构镜像

### 方法 1：使用 Docker Buildx（推荐）

```bash
# 创建 buildx 构建器
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# 构建并推送多架构镜像
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.webtop-full \
  -t yourusername/webtop-full:latest \
  --push .
```

### 方法 2：分别构建不同架构

#### x86-64
```bash
docker build -f Dockerfile.webtop-full \
  -t yourusername/webtop-full:amd64 \
  --platform linux/amd64 .
```

#### ARM64
```bash
docker build -f Dockerfile.webtop-full \
  -t yourusername/webtop-full:arm64 \
  --platform linux/arm64 .
```

#### 创建 manifest
```bash
docker manifest create yourusername/webtop-full:latest \
  yourusername/webtop-full:amd64 \
  yourusername/webtop-full:arm64

docker manifest push yourusername/webtop-full:latest
```

## 架构检测

容器内可以通过以下方式检测架构：

```bash
# 方法 1：使用 dpkg
dpkg --print-architecture

# 方法 2：使用 uname
uname -m

# 方法 3：使用 arch
arch
```

## 输出示例

| 架构 | `dpkg --print-architecture` | `uname -m` |
|------|---------------------------|-----------|
| x86-64 | amd64 | x86_64 |
| ARM64 | arm64 | aarch64 |

## 注意事项

1. **软件包兼容性**：所有通过 `apt-get` 安装的软件包都支持多架构
2. **Docker 安装**：`get.docker.com` 脚本自动检测架构
3. **国内镜像源**：已修复为自动检测架构（`dpkg --print-architecture`）
4. **s6-overlay**：基础镜像已包含，支持多架构

## 验证多架构支持

```bash
# 查看镜像支持的架构
docker manifest inspect lscr.io/linuxserver/webtop:ubuntu-xfce

# 在容器内验证架构
docker run --rm yourusername/webtop-full:latest dpkg --print-architecture
```
