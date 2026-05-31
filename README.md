<div align="center">
  <h1>Agent Workspace</h1>
  <p>AI 智能体云桌面开发与运行环境</p>
  <p>
    <a href="README.md">中文</a> &bull;
    <a href="README_en.md">English</a>
  </p>
</div>

---

基于 [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/)（Selkies WebRTC）的容器化云桌面，为 AI 智能体（OpenClaw、Openfang 等）提供安全隔离的开发与运行环境。

![web-desktop-example](./images/web-desktop-example.png)

## 核心特性

- **Selkies WebRTC 桌面** — 通过浏览器访问完整 Linux 桌面（HTTPS），支持 Wayland、自适应分辨率、[动态 HiDPI 缩放](docs/hidpi-scaling.md)
- **三种桌面环境** — LXQt（轻量 ~300MB）/ XFCE（中等 ~800MB）/ KDE（完整 ~1.1GB）
- **完整开发工具链** — Node.js 22、Go 1.22、Rust、Python 3、Homebrew、uv
- **多种 Docker 模式** — 不启用 / DinD（容器内独立 Docker）/ 挂载宿主机 Docker
- **GPU 加速** — 自动检测 NVIDIA / Intel / AMD GPU，支持硬件渲染与编码
- **国内镜像加速** — 运行时通过 `USE_CHINA_MIRROR=true` 一键切换全套国内源（APT、npm、pip、Go、Rust、Homebrew）
- **数据持久化** — 基于 LinuxServer `/config` 标准挂载，所有工具配置、包缓存、用户数据持久化
- **systemctl 进程管理** — 通过 docker-systemctl-replacement 管理 Agent 进程

## 快速开始

### 一键安装（推荐）

交互式脚本自动引导完成 9 步配置（语言、桌面、Docker、镜像源、版本、数据目录、端口、Agent 软件、Agent 端口）：

**Linux / macOS**
```bash
# 国内用户（GitCode 镜像）
curl -fsSL https://raw.gitcode.com/fliaping0/agent-workspace/raw/main/install.sh | bash

# 国际用户（GitHub）
curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
# 国内用户（GitCode 镜像）
irm https://raw.gitcode.com/fliaping0/agent-workspace/raw/main/install.ps1 -OutFile install.ps1; .\install.ps1

# 国际用户（GitHub）
irm https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.ps1 -OutFile install.ps1; .\install.ps1
```

### Docker 命令启动

```bash
docker run -d --name agent-workspace \
  --restart unless-stopped --shm-size 2gb \
  -e PUID=1000 -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -e LC_ALL=zh_CN.UTF-8 \
  -e SELKIES_ENABLE_WAYLAND=true \
  -e PIXELFLUX_WAYLAND=false \
  -p 3001:3001 \
  -v ~/agent-workspace-data:/config \
  xuping/agent-workspace:ubuntu-lxqt
```

启动后访问 **https://localhost:3001** 打开桌面。

> 国内用户镜像：`registry.cn-hangzhou.aliyuncs.com/fliaping/agent-workspace:ubuntu-lxqt`

### Docker Compose 启动

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace
# 按需修改 docker-compose.yml
docker compose up -d
```

## 镜像标签

| 标签 | 说明 |
|------|------|
| `ubuntu-lxqt` | LXQt 桌面（默认，最轻量） |
| `ubuntu-xfce` | XFCE 桌面 |
| `ubuntu-kde` | KDE 桌面 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PUID` / `PGID` | `1000` | 容器内用户/组 ID |
| `TZ` | `Etc/UTC` | 时区 |
| `LC_ALL` | - | 语言环境（如 `zh_CN.UTF-8`） |
| `SELKIES_ENABLE_WAYLAND` | `true` | 启用 Wayland 显示协议 |
| `PIXELFLUX_WAYLAND` | `false` | 强制 X11 模式（`true` 时 Selkies 无法输入中文） |
| `SELKIES_SCALING_DPI` | 不设置 | DPI 缩放（不设置时 Selkies 自动适配浏览器缩放比例，固定值如 192 适用于始终 HiDPI 场景） |
| `SELKIES_USE_BROWSER_CURSORS` | `true` | CSS 光标，鼠标零延迟 |
| `SELKIES_CONGESTION_CONTROL` | `true` | 网络拥塞控制，自适应码率 |
| `SELKIES_H264_CRF` | `28` | H264 画质（5-50，越大画质越低延迟越低） |
| `SELKIES_JPEG_QUALITY` | `30` | JPEG 回退画质（1-100，默认 40） |
| `SELKIES_H264_STREAMING_MODE` | `true` | H264 流式模式，降低编码延迟 |
| `START_DOCKER` | `false` | 启用容器内 Docker（需 `--privileged`） |
| `USE_CHINA_MIRROR` | `false` | 运行时切换国内镜像源 |
| `SSH_PASSWORD` | 不设置 | 设置后启用 SSH 服务（端口 22），值为 abc 用户密码 |
| `NODE_OPTIONS` | - | Node.js 选项（如 `--max-old-space-size=2048`） |

## Docker 模式

| 模式 | 配置 | 说明 |
|------|------|------|
| 不启用 | 默认 | 无 Docker 功能 |
| DinD | `--privileged` + `START_DOCKER=true` | 容器内独立 Docker 引擎 |
| 挂载宿主机 | `-v /var/run/docker.sock:/var/run/docker.sock` | 共享宿主机 Docker |

## GPU 加速

| GPU 类型 | 配置 |
|----------|------|
| NVIDIA | `--gpus all -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dri:/dev/dri` |
| Intel/AMD | `--device /dev/dri:/dev/dri -e DRINODE=/dev/dri/renderD128` |

> 安装脚本会自动检测 GPU 并配置。

## 内置工具链

| 工具 | 版本 | 说明 |
|------|------|------|
| Node.js | 22 LTS | + npm、pnpm、TypeScript |
| Go | 1.22.4 | |
| Rust | stable | + Cargo |
| Python 3 | 系统版 | + pip、venv、uv |
| Homebrew | 最新 | Linux 版，持久化到数据目录 |
| docker-systemctl-replacement | 最新 | systemd 替代，管理 Agent 进程 |

## 应用层能力管理

镜像主要负责稳定的系统依赖、桌面、开发工具链和 s6 基础服务。代理、code-server 插件、Agent 安装器等变化更快的应用逻辑由 `agent-workspace-manager` 管理，并安装到持久化的 `/config`。

进入容器后直接运行会打开 TUI：

```bash
agent-workspace-manager
```

TUI 支持方向键选择、Enter 执行，下载和安装日志会留在界面内的日志区域，不会直接写回原始 Terminal。Agent 安装也是 manager 自己的流程，不会嵌套启动另一个 TUI。

常用命令：

```bash
# 更新应用层源码到 /config/agent-workspace-manager/source
agent-workspace-manager update

# 安装基础应用能力：proxyctl、code-server 插件、自定义 s6 服务注册
agent-workspace-manager install foundation

# 查看应用能力状态
agent-workspace-manager status
```

`AGENT_WORKSPACE_SOURCE_DIR` 可以指向已有源码目录，便于测试本地 checkout；默认源码会持久化在 `/config/agent-workspace-manager/source`。详见 [Agent Workspace Manager](docs/agent-workspace-manager.md)。

## Agent 软件管理

`agent-workspace-manager install agents` 使用 manager 自己的安装流程，支持一键安装以下 Agent 软件：

| Agent | 默认端口 | 安装方式 |
|-------|----------|----------|
| OpenClaw | 18789 | npm |
| Openfang | 4200 | cargo build |
| ZeroClaw | 42617 | brew |

Agent 进程通过 **systemctl** 管理：

```bash
# 查看状态
docker exec agent-workspace systemctl status openclaw

# 查看日志
docker exec agent-workspace journalctl -u openclaw

# 重启服务
docker exec agent-workspace systemctl restart openclaw
```

## 可选能力模块

仓库内置了一组可选模块。推荐通过 `agent-workspace-manager` 安装，模块源码也可以单独调试：

| 模块 | 路径 | 说明 |
|------|------|------|
| proxyctl + Caddy 路由 | `addons/proxyctl` | 轻量 Caddy 反向代理、命名路由管理、code-server 子域端口代理 |
| 服务管理插件 | `extensions/service-manager` | 在 code-server 侧栏查看和管理 s6 / systemd 服务 |
| Caddy 代理插件 | `extensions/caddy-proxy-manager` | 在 code-server 侧栏查看和管理 proxyctl 路由 |
| 自定义 s6 服务 | `scripts/register-config-services.sh` | 自动注册 `/config/custom-services.d/<name>/run` 到 s6 |

安装 code-server 插件：

```bash
agent-workspace-manager install code-server-extensions
```

proxyctl 详细说明见 `addons/proxyctl/README.md`，code-server 插件说明见 [code-server Extensions](docs/code-server-extensions.md)。

## 数据持久化

容器 `/config` 目录映射到宿主机数据目录，以下内容持久化：

- Homebrew 软件（`/config/.linuxbrew`；`/home/linuxbrew/.linuxbrew` 仅作为兼容软链接，不需要单独挂载）
- npm 全局包（`/config/.npm-global`）
- Go 工作区（`/config/go`）
- Cargo 包（`/config/.cargo`）
- pip/uv 缓存（`/config/.cache`）
- 桌面配置和用户文件
- 自定义 s6 服务（`/config/custom-services.d/<name>/run`，容器启动时自动注册到 `/run/service`）

### 自定义 s6 服务

镜像内置的 `custom-services` s6 服务会在基础 `init` 完成后扫描 `/config/custom-services.d`，并注册服务到 s6。

创建服务：

```text
/config/custom-services.d/<service-name>/run
```

`run` 文件必须可执行。容器重建后，只要 `/config` 持久化挂载还在，服务会自动重新注册并启动。详见 [Persistent Custom s6 Services](docs/custom-s6-services.md)。

## 自定义构建

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace

# 默认构建（LXQt + 国际源）
docker compose build

# KDE 桌面
DESKTOP=kde docker compose build

# 国内源加速
USE_CHINA_MIRROR=true docker compose build
```

## 常用命令

```bash
# 查看日志
docker logs -f agent-workspace

# 进入容器
docker exec -it agent-workspace bash

# 停止/启动
docker stop agent-workspace
docker start agent-workspace
```

## 注意事项

- Selkies WebRTC 默认无密码认证，公网暴露请配置反向代理和认证
- Homebrew 持久化到 `/config/.linuxbrew`，不需要额外挂载 `/home/linuxbrew/.linuxbrew`
- 首次启动时 LinuxServer 会自动初始化 `/config` 目录

## 架构支持

| 架构 | Docker 平台 |
|------|------------|
| x86-64 | `linux/amd64` |
| ARM64 | `linux/arm64` |

## 相关链接

- [LinuxServer Webtop 文档](https://docs.linuxserver.io/images/docker-webtop/)
- [Docker Hub](https://hub.docker.com/r/xuping/agent-workspace)
- [GitHub](https://github.com/fliaping/agent-workspace)
