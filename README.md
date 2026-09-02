<div align="center">
  <h1>Agent Workspace</h1>
  <p>开箱即用的远程 AI Agent 开发与运行环境</p>
  <p>
    <a href="README.md">中文</a> &bull;
    <a href="README_en.md">English</a>
  </p>
</div>

---

基于 [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/)（Selkies WebRTC）的容器化远程工作区。一个 `/config` 数据卷即可持久化桌面、code-server、Agent、MCP、Skills 和自定义服务，适合在服务器、NAS 或 WSL2 上长期运行 Codex、Claude Code、Hermes 等 AI Agent。

![web-desktop-example](./images/web-desktop-example.png)

<!--
后续截图建议直接补到 images/ 并在此排成两列：
- control-center-overview.png
- agent-management.png
- mcp-skills-management.png
- desktop-network.png
-->

## 核心特性

- **Agent 开箱即用** — 首次启动可选 Codex、Claude Code、Hermes 或 DeepSeek Harness；Codex 和 Claude Code 会同时安装官方 code-server 扩展
- **统一双语控制中心** — 一处管理 Agent、全局 MCP 与 Skills、服务、桌面、网络和诊断；中英文切换会同步 code-server
- **Agent 可直接操作环境** — `workspacectl` 提供稳定接口，用于检查服务、日志、端口、路由和可选能力
- **Selkies WebRTC 桌面** — 通过 HTTPS 访问完整 Linux 桌面；可选 XFCE（默认）、LXQt 或 KDE
- **直接操作用户浏览器** — 经用户明确授权后，Agent 可通过 Chrome DevTools MCP 接管当前 Chromium 标签页与登录会话，无需关闭或复制浏览器
- **灵活的 Docker 权限边界** — 可关闭 Docker、使用容器内 DinD，或显式挂载宿主机 Docker Socket
- **可选远程网络** — 支持 SSH 隧道、自定义域名 + Caddy 和无需 `NET_ADMIN` 的 Tailscale 自组网
- **完整开发工具链** — Node.js 22、Go 1.22、Rust、Python 3、Homebrew、uv、tmux，并支持 NVIDIA / Intel / AMD GPU 加速
- **单卷持久化** — 工具、登录状态、配置、缓存和自定义服务全部持久化到 `/config`；支持一键切换国内镜像

## 开箱即用范围

| 部分 | 部署后已就绪 | 用户还需要做什么 |
|------|--------------|----------------------|
| 工作区 | Webtop、code-server、Control Center、`workspacectl` | 在浏览器打开访问地址 |
| 首选 Agent | CLI 和对应 IDE 入口 | 完成官方账号登录或 API/模型配置 |
| 日常管理 | Agent、MCP、Skills、服务、桌面、网络和诊断界面 | 按项目需求添加资源或启用服务 |
| 远程访问 | 本地 HTTPS 端点和 SSH 隧道方案 | 按需启用自定义域名、认证网关或 Tailscale |

最短使用路径是：运行 `remote-up.sh` → 打开 code-server → 完成一个 Agent 的登录 → 让该 Agent 继续配置其他功能。

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
| `AGENT_WORKSPACE_AGENT` | `codex` | 首次启动安装 `codex`、`claude-code`、`hermes`、`deepseek-harness` 或 `none` |
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
| tmux | 系统版 | 持久终端会话，适合远程 Agent 任务 |
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

# 可选：配置自定义域名（自动安装 Caddy 路由后端）
workspacectl network domain dev.example.com

# 可选：无需 NET_ADMIN 的 Tailscale 私有自组网
agent-workspace-manager install tailscale
workspacectl tailscale login
workspacectl tailscale serve

# 查看应用能力状态
agent-workspace-manager status
```

`AGENT_WORKSPACE_SOURCE_DIR` 可以指向已有源码目录，便于测试本地 checkout；默认源码会持久化在 `/config/agent-workspace-manager/source`。详见 [Agent Workspace Manager](docs/agent-workspace-manager.md)。通用软件和用法见 [Common Software](docs/common-software.md)。

## Agent 软件管理

`agent-workspace-manager install agents` 默认安装 Codex；也可以明确指定一个或多个 Agent：

```bash
agent-workspace-manager install agents codex
agent-workspace-manager install agents claude-code hermes deepseek-harness
```

| Agent | 类型 | 安装来源 | 安装后配置 |
|-------|------|----------|------------|
| Codex | 交互式 CLI | [OpenAI 官方安装器](https://learn.chatgpt.com/docs/codex/cli) | `codex` |
| Claude Code | 交互式 CLI | [Anthropic 官方安装器](https://code.claude.com/docs/en/quickstart) | `claude` |
| Hermes Agent | 交互式 CLI | [Nous Research 官方安装器](https://hermes-agent.nousresearch.com/docs/) | `hermes setup --portal` |
| DeepSeek Harness | 常驻 Web Agent，默认端口 3080 | [DeepSeek 官方 npm 包](https://github.com/deepseek-ai/deepseek-harness) | 在同一 code-server 域名打开 `/proxy/3080/` |
| OpenClaw | 常驻服务，默认端口 18789 | npm | `openclaw onboard` |
| Openfang | 常驻服务，默认端口 4200 | 官方 shell 安装器 | `openfang init` |
| ZeroClaw | 常驻服务，默认端口 42617 | brew | `zeroclaw onboard` |

安装 Codex 或 Claude Code 时，如果 code-server 已可用，管理器会同时安装官方
`openai.chatgpt` 或 `Anthropic.claude-code` 扩展。如果先安装 Agent、后安装
code-server，执行 `agent-workspace-manager install code-server-extensions` 会自动补齐。

Codex、Claude Code 和 Hermes 直接在项目终端运行，不应注册成后台服务。DeepSeek
Harness 与其他常驻型 Agent 通过用户级 `systemctl` 管理。四种 Agent 都会读取工作区说明，且可用
统一入口操作当前容器：

```bash
workspacectl info
workspacectl status --json
workspacectl services
workspacectl service restart openclaw
workspacectl s6 status svc-selkies
workspacectl logs openclaw
workspacectl ports
workspacectl browser status

# 配置全局 Chrome DevTools MCP，并在当前 Chromium 打开授权页
workspacectl browser setup

# 已有任一 Agent 后，让它按需安装另一个 Agent
workspacectl install agent claude-code
```

`/config` 是唯一持久化边界。默认的 `/config/Workspace/AGENTS.md` 和
`CLAUDE.md` 会把这一约束告知 Agent，但不会覆盖用户已有文件。挂载宿主机
Docker socket 会让 Agent 获得容器外的高权限；`workspacectl info` 会明确提示这个边界。
Agent 的登录信息和配置写入 `HOME=/config`，因此随唯一的 `/config` 数据卷持久化。

浏览器控制采用 Chromium 144+ 的授权式自动连接。用户需要在当前 Chromium 的
`chrome://inspect/#remote-debugging` 中启用远程调试，并在 Agent 发起连接时点击允许。
该能力不会暴露 9222 端口，但获准连接的 Agent 可以读取和操作当前用户目录中的
全部标签页、Cookie 与登录会话，因此只应授权可信 Agent。

## 可选能力模块

仓库内置了一组可选模块。推荐通过 `agent-workspace-manager` 安装，模块源码也可以单独调试：

| 模块 | 路径 | 说明 |
|------|------|------|
| code-server | `addons/code-server` | 官方 standalone 运行时、密码认证和持久化用户服务 |
| Control Center | `extensions/control-center` | 统一的首次使用向导，以及 Agent、资源、服务、桌面、网络和诊断界面 |
| 自定义域名路由 | `addons/proxyctl` | 由 `workspacectl network domain` 自动安装的 Caddy 后端，适合已有 DNS、TLS 和认证网关的部署 |
| Selkies Desktop | `extensions/selkies-desktop` | 正式桌面能力，在 Control Center 内显示运行状态并一键打开 |
| Tailscale 自组网 | `addons/tailscale` | 无需 NET_ADMIN 的 userspace 私有网络与 Tailnet Serve |
| DeepSeek Harness | `addons/deepseek-harness` | 官方 `dsh`、持久化状态、同源 Web UI 与全局资源桥接 |
| 自定义 s6 服务 | `scripts/register-config-services.sh` | 自动注册 `/config/custom-services.d/<name>/run` 到 s6 |

安装 code-server 插件：

```bash
agent-workspace-manager install code-server-extensions
```

安装器会迁移旧版独立的服务与 Caddy 侧栏，只保留一个 Agent Workspace 入口。
用户和 Agent 统一使用 `workspacectl`；Caddy 路由后端仍保持独立，但无需直接操作。

路由后端实现说明见 `addons/proxyctl/README.md`，code-server 插件说明见 [code-server Extensions](docs/code-server-extensions.md)。

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

- 未设置 `CUSTOM_USER` / `PASSWORD` 时没有 Webtop 应用层认证；公网部署请使用强密码，并配置反向代理、VPN 或零信任网关
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
