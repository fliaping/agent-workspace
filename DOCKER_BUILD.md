# Webtop Docker 镜像构建指南

## 概述

自动构建多架构 (x86-64 和 ARM64) Webtop Docker 镜像，推送到 DockerHub 和阿里云镜像仓库。

## 触发构建

### 方法 1：通过 Git Tag（推荐）

```bash
# 创建版本标签（格式：webtop-v{版本号}）
git tag webtop-v1.0.0
git push origin webtop-v1.0.0
```

### 方法 2：手动触发

在 GitHub 仓库页面：
1. 进入 **Actions** 标签
2. 选择 **Build Webtop Multi-Arch Image**
3. 点击 **Run workflow**
4. 输入版本号（如 `1.0.0`）
5. 点击 **Run workflow**

## 配置 Secrets

在 GitHub 仓库设置中添加以下 Secrets：

### DockerHub 配置

| Secret | 说明 | 获取方式 |
|--------|------|---------|
| `DOCKERHUB_USERNAME` | DockerHub 用户名 | DockerHub 账号 |
| `DOCKERHUB_TOKEN` | DockerHub 访问令牌 | [创建令牌](https://hub.docker.com/settings/security) |

### 阿里云镜像仓库配置

| Secret | 说明 | 获取方式 |
|--------|------|---------|
| `ALIYUN_USERNAME` | 阿里云账号（全名） | 阿里云控制台 |
| `ALIYUN_PASSWORD` | 阿里云登录密码 | 阿里云账号 |
| `ALIYUN_NAMESPACE` | 镜像仓库命名空间 | [容器镜像服务](https://cr.console.aliyun.com/) |

## 镜像地址

构建完成后，镜像可在以下地址获取：

### DockerHub
```bash
docker pull yourusername/webtop-full:1.0.0
docker pull yourusername/webtop-full:latest
```

### 阿里云镜像仓库
```bash
docker pull registry.cn-hangzhou.aliyuncs.com/your-namespace/webtop-full:1.0.0
docker pull registry.cn-hangzhou.aliyuncs.com/your-namespace/webtop-full:latest
```

## 版本号规则

- 使用语义化版本：`MAJOR.MINOR.PATCH`
- 示例：`1.0.0`, `1.1.0`, `2.0.0`
- 每次构建会同时打上 `latest` 标签

## 架构支持

| 架构 | 平台标识 | 说明 |
|------|---------|------|
| x86-64 | `linux/amd64` | Intel/AMD 64位处理器 |
| ARM64 | `linux/arm64` | Apple Silicon, ARM 服务器 |

## 使用示例

```bash
# 拉取特定版本
docker pull yourusername/webtop-full:1.0.0

# 运行容器
docker run -d --name webtop \
  --privileged \
  -p 3000:3000 \
  -e ENABLE_DIND=true \
  -e SYSTEM_LANG=zh_CN \
  yourusername/webtop-full:1.0.0
```

## 故障排除

### 构建失败

1. 检查 Secrets 是否正确配置
2. 确认 DockerHub 和阿里云账号有权限推送镜像
3. 查看 GitHub Actions 日志获取详细错误信息

### 镜像拉取失败

1. 确认镜像已推送成功
2. 检查网络连接
3. 阿里云镜像需要登录：`docker login registry.cn-hangzhou.aliyuncs.com`
