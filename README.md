<div align="center">
  <h1>Agent Workspace</h1>
  <p>AI 智能体云桌面开发与运行环境</p>
  <p>
    <a href="README.md">中文</a> &bull;
    <a href="README_en.md">English</a>
  </p>
</div>

---

基于 [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/)（Selkies WebRTC）的容器化云桌面，为 Codex、Claude Code、Hermes 等 AI Agent 提供安全隔离的开发与运行环境。

![web-desktop-example](./images/web-desktop-example.png)

## 核心特性

- **Selkies WebRTC 桌面** — 通过浏览器访问完整 Linux 桌面（HTTPS），显示、编码和 DPI 默认沿用 LinuxServer Webtop 上游配置
- **三种桌面环境** — XFCE（默认，推荐 ~800MB）/ LXQt（轻量 ~300MB）/ KDE（完整 ~1.1GB）
- **完整开发工具链** — Node.js 22、Go 1.22、Rust、Python 3、Homebrew、uv
- **多种 Docker 模式** — 不启用 / DinD（容器内独立 Docker）/ 挂载宿主机 Docker
- **GPU 加速** — 自动检测 NVIDIA / Intel / AMD GPU，支持硬件渲染与编码
- **国内镜像加速** — 运行时通过 `USE_CHINA_MIRROR=true` 一键切换全套国内源（APT、npm、pip、Go、Rust、Homebrew）
- **数据持久化** — 基于 LinuxServer `/config` 标准挂载，所有工具配置、包缓存、用户数据持久化
- **Agent 开箱即用** — 首次启动可选择 Codex、Claude Code 或 Hermes，安装后只需完成各自登录
- **统一控制中心** — code-server 首次打开即显示使用向导，集中管理 Agent、服务、网络、桌面和诊断
- **统一环境控制** — Agent 可通过 `workspacectl` 检查和管理服务、日志、端口、路由及可选能力
- **systemctl 进程管理** — 通过 docker-systemctl-replacement 管理常驻 Agent 服务
- **安全远程工作区** — Webtop 与 code-server 使用随机密码和 HTTPS，首次启动自动安装远程基础能力

## 快速开始

### 安全远程启动（推荐）

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace
./scripts/remote-up.sh
```

脚本只要求选择一个首选 Agent（默认 Codex），然后生成仅当前用户可读的
`.env.remote` 并启动 Webtop。首次启动自动安装所选 Agent、code-server 和工作区插件。
终端会显示随机用户名、密码和访问地址；首次进入 code-server 后，Control Center
会自动打开五步向导，引导用户启动 Agent、打开工作区、选择远程访问方式和按需组件：

```text
https://localhost:3001  # Webtop 桌面
https://localhost:8443  # code-server
```

这里的 `localhost` 指运行 Docker 的服务器。如果从其他电脑访问，可使用服务器
主机名/IP；若防火墙、WSL 或 NAT 没有开放这两个端口，可在客户端建立 SSH 隧道：

```bash
ssh -N -L 3001:127.0.0.1:3001 -L 8443:127.0.0.1:8443 user@server
```

建立后仍在客户端浏览器打开上述 `localhost` 地址。

默认使用自签名证书，第一次访问时浏览器会提示确认。公网部署仍建议放在具备
TLS 和强认证的反向代理、VPN 或零信任网关后面。

直连模式与认证网关模式的完整拓扑见 [Remote Workspace Profiles](docs/remote-workspace.md)。

### 交互式安装

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
  -e CUSTOM_USER=agent \
  -e PASSWORD='replace-with-a-long-random-password' \
  -e SELKIES_ENABLE_RATE_CONTROL=true \
  -e SELKIES_RATE_CONTROL_MODE=crf,cbr \
  -e SELKIES_CONGESTION_CONTROL=false \
  -e SELKIES_ENABLE_RESIZE=true \
  -p 3001:3001 \
  -v ~/agent-workspace-data:/config \
  xuping/agent-workspace:ubuntu-xfce
```

启动后访问 **https://localhost:3001** 打开桌面。

> 国内用户镜像：`registry.cn-hangzhou.aliyuncs.com/fliaping/agent-workspace:ubuntu-xfce`

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
| `ubuntu-xfce` | XFCE 桌面（默认，推荐） |
| `ubuntu-lxqt` | LXQt 桌面（最轻量） |
| `ubuntu-kde` | KDE 桌面 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PUID` / `PGID` | `1000` | 容器内用户/组 ID |
| `TZ` | `Etc/UTC` | 时区 |
| `LC_ALL` | - | 语言环境（如 `zh_CN.UTF-8`） |
| `CUSTOM_USER` / `PASSWORD` | 不设置 | Webtop HTTP Basic 认证；远程访问时必须设置 |
| `START_DOCKER` | `false` | 启用容器内 Docker（需 `--privileged`） |
| `USE_CHINA_MIRROR` | `false` | 运行时切换国内镜像源 |
| `AGENT_WORKSPACE_AGENT` | `codex` | 首次启动安装 `codex`、`claude-code`、`hermes` 或 `none` |
| `SSH_PASSWORD` | 不设置 | 设置后启用 SSH 服务（端口 22），值为 abc 用户密码 |
| `NODE_OPTIONS` | - | Node.js 选项（如 `--max-old-space-size=2048`） |
| `SELKIES_ENABLE_RATE_CONTROL` | `true` | 启用 CRF/CBR 码率控制切换 |
| `SELKIES_RATE_CONTROL_MODE` | `crf,cbr` | 可选码率模式，首项 CRF 为默认值 |
| `SELKIES_CONGESTION_CONTROL` | `false` | 关闭会压低动态画质的 GCC 自适应码率 |
| `SELKIES_ENABLE_RESIZE` | `true` | 浏览器窗口变化时同步调整桌面分辨率 |
| `XFCE_PANEL_SCALING` | `true` | Wayland 缩放变化时同步调整 XFCE 面板与图标；设为 `false` 可关闭 |

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
| Intel/AMD | `--device /dev/dri:/dev/dri -e DRINODE=/dev/dri/renderD128 -e DRI_NODE=/dev/dri/renderD128` |

> 安装脚本会自动检测 GPU 并配置。
>
> 视频默认采用恒定质量 CRF，侧栏仍可切换为 CBR；桌面分辨率会跟随浏览器窗口变化。只有遇到明确的 Wayland 兼容问题时，才建议添加 `-e PIXELFLUX_WAYLAND=false` 回退到 X11；X11 无法使用上游的 Wayland 零拷贝编码优化。

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

# 安装安全远程基础能力：code-server、插件、自定义 s6 服务注册
agent-workspace-manager install foundation

# 可选：为已有泛域名和上游网关安装 Caddy/proxyctl
PROXY_ROOT_DOMAIN=dev.example.com agent-workspace-manager install proxyctl

# 查看应用能力状态
agent-workspace-manager status
```

`AGENT_WORKSPACE_SOURCE_DIR` 可以指向已有源码目录，便于测试本地 checkout；默认源码会持久化在 `/config/agent-workspace-manager/source`。详见 [Agent Workspace Manager](docs/agent-workspace-manager.md)。通用软件和用法见 [Common Software](docs/common-software.md)。

## Agent 软件管理

`agent-workspace-manager install agents` 默认安装 Codex；也可以明确指定一个或多个 Agent：

```bash
agent-workspace-manager install agents codex
agent-workspace-manager install agents claude-code hermes
```

| Agent | 类型 | 安装来源 | 安装后配置 |
|-------|------|----------|------------|
| Codex | 交互式 CLI | [OpenAI 官方安装器](https://learn.chatgpt.com/docs/codex/cli) | `codex` |
| Claude Code | 交互式 CLI | [Anthropic 官方安装器](https://code.claude.com/docs/en/quickstart) | `claude` |
| Hermes Agent | 交互式 CLI | [Nous Research 官方安装器](https://hermes-agent.nousresearch.com/docs/) | `hermes setup --portal` |
| OpenClaw | 常驻服务，默认端口 18789 | npm | `openclaw onboard` |
| Openfang | 常驻服务，默认端口 4200 | 官方 shell 安装器 | `openfang init` |
| ZeroClaw | 常驻服务，默认端口 42617 | brew | `zeroclaw onboard` |

Codex、Claude Code 和 Hermes 直接在项目终端运行，不应注册成后台服务。常驻型
Agent 才通过用户级 `systemctl` 管理。三种交互式 Agent 都会读取工作区说明，且可用
统一入口操作当前容器：

```bash
workspacectl info
workspacectl status --json
workspacectl services
workspacectl service restart openclaw
workspacectl s6 status svc-selkies
workspacectl logs openclaw
workspacectl ports

# 已有任一 Agent 后，让它按需安装另一个 Agent
workspacectl install agent claude-code
```

`/config` 是唯一持久化边界。默认的 `/config/Workspace/AGENTS.md` 和
`CLAUDE.md` 会把这一约束告知 Agent，但不会覆盖用户已有文件。挂载宿主机
Docker socket 会让 Agent 获得容器外的高权限；`workspacectl info` 会明确提示这个边界。
Agent 的登录信息和配置写入 `HOME=/config`，因此随唯一的 `/config` 数据卷持久化。

## 可选能力模块

仓库内置了一组可选模块。推荐通过 `agent-workspace-manager` 安装，模块源码也可以单独调试：

| 模块 | 路径 | 说明 |
|------|------|------|
| code-server | `addons/code-server` | 官方 standalone 运行时、密码认证和持久化用户服务 |
| Control Center | `extensions/control-center` | 统一的首次使用向导、Agent、服务、网络和诊断界面 |
| proxyctl + Caddy 路由 | `addons/proxyctl` | 可选的泛域名路由，适合已有 DNS、TLS 和认证网关的部署 |
| Selkies 桌面插件 | `extensions/selkies-desktop` | 在 code-server 内一键打开并初始化 Selkies 桌面 |
| 自定义 s6 服务 | `scripts/register-config-services.sh` | 自动注册 `/config/custom-services.d/<name>/run` 到 s6 |

安装 code-server 插件：

```bash
agent-workspace-manager install code-server-extensions
```

安装器会迁移旧版独立的服务与 Caddy 侧栏，只保留一个 Agent Workspace 入口；
底层功能仍由独立的 `workspacectl`、`proxyctl` 和服务管理命令实现。

proxyctl 详细说明见 `addons/proxyctl/README.md`，code-server 插件说明见 [code-server Extensions](docs/code-server-extensions.md)。

## 数据持久化

容器 `/config` 目录映射到宿主机数据目录，以下内容持久化：

- Homebrew 软件（`/config/.linuxbrew`；`/home/linuxbrew/.linuxbrew` 仅作为兼容软链接，不需要单独挂载）
- npm 全局包（`/config/.npm-global`）
- Go 工作区（`/config/go`）
- Cargo 包（`/config/.cargo`）
- pip/uv 缓存（`/config/.cache`）
- 桌面配置和用户文件
- code-server 运行时与配置（`/config/opt/code-server`、`/config/.config/code-server`）
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

# 默认构建（XFCE + 国际源）
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
